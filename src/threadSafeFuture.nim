# threadSafeFuture.nim
# Jens Alfke, 30 June 2020

import asyncdispatch, deques, locks, sugar, threadpool

## Utilities for mixing async/await with threads.
##
## ``threadSafe()`` takes a Future and returns a new Future that can be completed on any thread.
## The original Future's callback will still be invoked on its original thread, and ``await``
## works normally.
##
## ``asyncSpawn`` takes a proc and runs it on thread-pool using ``spawn`` ... but instead of
## a ``FlowVar`` it returns a ``Future``. This Future is thread-safe as above.

type PerformerProc* = proc() {.gcsafe.}

type ThreadPerformer* = ref object
  ## An object that can run procs on a specific thread's AsyncDispatcher.
  ## Call ``currentThreadPerformer()`` to get the instance corresponding to the current thread.
  ## Used by the other utilities in this class.
  event: AsyncEvent
  lock: Lock
  pending: Deque[PerformerProc]

proc callNextProc(p: ThreadPerformer): bool {.gcsafe.} =
  # Calls the next queued proc.
  var pr0c: PerformerProc
  p.lock.withLock:
    pr0c = p.pending.popFirst()
  pr0c()
  return false # This tells dispatcher I want to stay registered

proc perform*(p: ThreadPerformer; n: PerformerProc) =
  ## Queues a request to call the given proc on the ThreadPerformer's home thread.
  ## (This function is thread-safe.)
  p.lock.withLock:
    p.pending.addLast(n)
  p.event.trigger()


var gCurrentPerformer {.threadvar.} : ThreadPerformer

proc currentThreadPerformer*(): ThreadPerformer =
  ## Returns the ThreadPerformer instance for the current thread's AsyncDispatcher.
  if gCurrentPerformer == nil:
    let p = ThreadPerformer(event: newAsyncEvent())
    p.lock.initLock()
    p.event.addEvent( proc(fd: AsyncFD): bool = p.callNextProc() )
    gCurrentPerformer = p
  return gCurrentPerformer


# Wrapping Futures:

proc propagateResult[T](dst, src: Future[T]) =
  # Sets the result or error of ``dst`` to match that of ``src``.
  if src.failed:
    dst.fail(src.readError())
  else:
    when T is void:
      dst.complete()
    else:
      dst.complete(src.read())

proc threadSafe*[T](f: Future[T]): Future[T] =
  ## Given a regular Future, returns a new Future that can be completed on any thread,
  ## and will call the original Future's completion procs on the original thread.
  let p = currentThreadPerformer()
  let wrapped = newFuture[T]("wrapped")
  wrapped.addCallback( proc(wrapped: Future[T]) =
    p.perform( proc() = propagateResult(f, wrapped) )
  )
  return wrapped


# Async Spawn:

proc threadMain[T](p: ThreadPerformer; f: Future[T]; threadProc: proc():T) {.thread.} =
  # The proc spawned by asyncSpawn[T]
  try:
    let res = threadProc()
    p.perform( () => f.complete(res) )
  except:
    p.perform( () => f.fail(getCurrentException()) )

proc threadMain(p: ThreadPerformer; f: Future[void]; threadProc: proc()) {.thread.} =
  # The proc spawned by asyncSpawn[void]
  try:
    threadProc()
    p.perform( () => f.complete() )
  except:
    p.perform( () => f.fail(getCurrentException()) )

proc asyncSpawn*[T](threadProc: proc():T): Future[T] =
  ## Runs ``threadProc`` on another thread via ``spawn()``, and returns a ``Future`` that
  ## can be awaited to get its result/exception.
  let p = currentThreadPerformer()
  let f = newFuture[T]("asyncSpawn")
  spawn threadMain(p, f, threadProc)
  return f

proc asyncSpawn*(threadProc: proc()): Future[void] =
  ## Runs ``threadProc`` on another thread via ``spawn()``, and returns a ``Future`` that
  ## can be awaited to find when it completes.
  let p = currentThreadPerformer()
  let f = newFuture[void]("asyncSpawn")
  spawn threadMain(p, f, threadProc)
  return f



# Just to flush out trivial syntax errors in the generic procs:
proc dummy1(f: Future[void]): Future[void] = threadSafe(f)
proc dummy2(f: Future[bool]): Future[bool] = threadSafe(f)
proc dummy3(threadProc: proc():bool {.gcsafe.}): Future[bool] = asyncSpawn(threadProc)
proc dummy4(threadProc: proc() {.gcsafe.}): Future[void] = asyncSpawn(threadProc)


# Simple test:
when isMainModule:
  import os

  let mainThreadID = getThreadId()

  # Test threadSafe():

  proc testThreadSafe() {.async.} =
    echo "---- Testing threadSafe ----"
    let f1 = newFuture[int]()

    proc completeElsewhere(f: Future[int]) {.thread.} =
      os.sleep 1000
      echo "testThreadSafe: On thread ", getThreadID(), "!"
      assert getThreadID() != mainThreadID
      f.complete(49)

    spawn completeElsewhere(threadSafe(f1))

    var callbackResult = -1
    f1.addCallback proc(f: Future[int]) =
      echo "testThreadSafe: Callback! got ", f.read()
      assert getThreadID() == mainThreadID
      callbackResult = f.read()

    echo "testThreadSafe: waiting on thread ", mainThreadID, "..."
    var waitResult = await f1
    echo "testThreadSafe: checking callbackResult ", callbackResult, ", waitResult ", waitResult, "..."
    assert callbackResult == 49
    assert waitResult == 49

  # Test asyncSpawn:
  proc testAsyncSpawn() {.async.} =
    echo "---- Testing asyncSpawn ----"
    let f2: Future[int] = asyncSpawn proc():int =
      os.sleep 1000
      echo "testAsyncSpawn: On thread ", getThreadID(), "!"
      assert getThreadID() != mainThreadID
      return 94
    assert f2.finished == false

    var callbackResult = -1
    f2.addCallback proc(f: Future[int]) =
      echo "testAsyncSpawn: Callback! got ", f.read()
      assert getThreadID() == mainThreadID
      callbackResult = f.read()

    echo "testAsyncSpawn: waiting on thread ", mainThreadID, "..."
    var waitResult = await f2
    echo "testAsyncSpawn: checking callbackResult ", callbackResult, ", waitResult ", waitResult, "..."
    assert callbackResult == 94
    assert waitResult == 94

  waitfor testThreadSafe() and testAsyncSpawn()
