import strformat
import threadpool

import prologue
import prologue/middlewares/staticfile
import nwt

proc tDebug(m:string) {.inline.} = 
  when not defined(prod):
    echo fmt"Thread {getThreadID()} => {m}"

## To just set up threadvar and initialize per thread.
# var templates {.threadvar.} : Nwt
# templates = newNwt("templates/*.html")

var
  templates = newNwt("templates/*.html")
  ptemplates: ptr Nwt

ptemplates = addr(templates)

let settings = newSettings(
  address="0.0.0.0",
  debug=false,
  port=Port(8000),
)

var app = newApp(
  settings=settings,
  middlewares = @[staticFileMiddleware(["/static"])]
)

proc initTemplates() =
  if templates.isNil:
    tDebug "`templates` is nil. Setting."
    templates = newNwt("templates/*.html")
  
proc index(ctx: Context) {.async.} =
  # initTemplates()
  tDebug "index()"
  # resp templates.renderTemplate("index.html")
  resp ptemplates[].renderTemplate("index.html")

proc explicitHTML(ctx: Context) {.async.} =
  resp htmlResponse("<h2>Welcome to Prologue</h2>")

proc renderImplicitHTML(ctx: Context, html:string) =
  tDebug "renderImplicitHTML(...)"
  resp html 

proc implicitHTML(ctx: Context) {.async.} =
  resp "<html><body><h2>This is an implicit HTML response</h2></body></html>"

proc jsonResp(ctx: Context) {.async.} =
  resp jsonResponse(%*{"message": "test"})

app.addRoute("/", index)
app.addRoute("/explicitHTML", explicitHTML)
app.addRoute("/implicitHTML", implicitHTML)
app.addRoute("/json", jsonResp)

tDebug "started server"

app.run()