# nim c -r --threads:on --gc:orc

import cpuinfo, os, random, locks, deques

type
  WorkReq = ref object
    id: int

  WorkRes = ref object
    id: int
    data: seq[int]

var
  workThreads: array[32, Thread[int]]
  inputQ: Deque[WorkReq]
  inputLock: Lock
  outputQ: Deque[WorkRes]
  outputLock: Lock

template hold(lock: Lock, body: untyped) =
  ## Wraps withLock in a gcsafe block.
  {.gcsafe.}:
    withLock lock:
      body

proc workThread(threadNum: int) {.thread.} =
  ## Work thread waits for work to arrive then does it.
  ## N of them can be running at one time.
  while true:
    var
      ready = false
      workReq: WorkReq
    hold inputLock:
      ready = inputQ.len > 0
      if ready:
        workReq = inputQ.popFirst()
    if ready:
      var workRes = WorkRes()
      workRes.id = workReq.id
      workRes.data = newSeq[int](500)
      var z = workRes.id

      # Do the actual work.
      for n in 0 .. 10_000:
        for i in 0 ..< workRes.data.len:
          z = z mod 10 + z div 10
          workRes.data[i] = z

      hold outputLock:
        outputQ.addLast(workRes)

proc askForWork() =
  ## Asks for work to be done.
  while true:
    sleep(0)

    var inputLen, outputLen: int
    # Its best to never hold 2 locks at the same time.
    hold inputLock:
      inputLen = inputQ.len
    hold outputLock:
      outputLen = outputQ.len
    # echo "inputLen: ", inputLen, " outputLen: ", outputLen

    # Keep the work q at 10 works always.
    for i in 0 ..< 10 - inputLen:
      var workReq = WorkReq()
      workReq.id = rand(0 .. 10_000)
      # echo "need      ", workReq.id
      hold inputLock:
        inputQ.addLast(workReq)

    # Get works back if any.
    while true:
      var
        ready = false
        workRes: WorkRes
      hold outputLock:
        ready = outputQ.len > 0
        if ready:
          workRes = outputQ.popFirst()
      if ready:
        echo "got       ", workRes.id
      else:
        break

# Init the two locks.
inputLock.initLock()
outputLock.initLock()

# Start number of works threads as we have CPUs.
# Leave 1 cpu for the main thread.
# Leave 1 cpu for all other programs.
for i in 0 ..< clamp(countProcessors() - 2, 1, 32):
  createThread(workThreads[i], workThread, i)
  # Don't pin to 0th core as thats where most of the IO happens.
  pinToCpu(workThreads[i], i + 1)

askForWork()