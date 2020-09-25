import strutils
import json

import prologue
import nwt

let settings = newSettings(
  address="0.0.0.0",
  debug=false,
  port=Port(8000),
  staticDirs=["/static"],
)

var app = newApp(settings=settings)

## To initialize and then copy per thread.
# var
#   globalTemplates = newNwt("templates/*.html")
#   templates {.threadvar.} : Nwt
# 
# proc initTemplates() =
#   {.gcsafe.}:
#     if templates.isNil:
#       deepCopy(templates, globalTemplates)


## To just set up threadvar and initialize per thread.
var
  templates {.threadvar.} : Nwt

proc initTemplates() =
  if templates.isNil:
    templates = newNwt("templates/*.html")


proc index(ctx: Context) {.async.} =
  initTemplates()
  resp templates.renderTemplate("index.html")

proc htmlResp(ctx: Context) {.async.} =
  resp htmlResponse("<h2>Welcome to Prologue</h2>")

proc jsonText(ctx: Context) {.async.} =
  resp jsonResponse(%*{"message": "test"})

proc jsonApp(ctx: Context) {.async.} =
  let response = initResponse(
    httpVersion = HttpVer11,
    code = Http200,
    headers = {
      "Content-Type": "application/json"
    }.newHttpHeaders,
    body = $(%*{"message": "test"}))
  resp response

app.addRoute("/", index)
app.addRoute("/htmlResp", htmlResp)
app.addRoute("/jsonText", jsonText)
app.addRoute("/jsonApp", jsonApp)


app.run()