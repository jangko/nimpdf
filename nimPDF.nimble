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

### Helper functions
proc test(env, path: string) =
  # Compilation language is controlled by TEST_LANG
  var lang = "c"
  if existsEnv"TEST_LANG":
    lang = getEnv"TEST_LANG"

  exec "nim " & lang & " " & env &
    " -r --hints:off --warnings:off " & path

task test, "Run all tests":
  withDir("demo"):
    test "--warning[LockLevel]:off --path:../nimPDF -d:release", "test_all"

task testvcc, "Run all tests":
  withDir("demo"):
    test "--cc:vcc --warning[LockLevel]:off --path:../nimPDF -d:release", "test_all"
