packageName   = "nimPDF"
version       = "0.4.3"
author        = "Andri Lim"
description   = "PDF document generation library written in nim"
license       = "MIT"
skipDirs      = @["new feature", "demo", "docs"]

requires: "nim >= 0.18.1"
requires: "nimBMP >= 0.1.0"
requires: "nimPNG >= 0.1.0"
requires: "nimSHA2 >= 0.1.0"
requires: "nimAES >= 0.1.0"
requires: "stb_image >= 2.1"

task test, "Run all tests":
  withDir("demo"):
    exec "nim c --warning[LockLevel]:off --path:../nimPDF test_all"
    exec "nim c --warning[LockLevel]:off --path:../nimPDF -d:release test_all"
