mode = ScriptMode.Verbose

import strutils, ospaths

var switches = ""

const testDir {.strdefine.} = ""

proc addSwitch(sw: string) =
  switches.add " --"
  switches.add sw

addSwitch("path:.." & DirSep & "nimPDF")
addSwitch("define:release")

let files = [
  "basic_outline",
  "curve",
  "destination_outline",
  "encoding_list",
  "encrypted",
  "hello",
  "hierarchy_outline",
  "link_annot",
  "pagelabels",
  "test",
  "text_annot"
  ]

let testDirSep = if testDir != "": testDir & DirSep else: ""

for file in files:
  exec "nim c $1 $2$3" % [switches, testDirSep, file]

for file in files:
  exec file