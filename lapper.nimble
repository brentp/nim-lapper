# Package

version       = "0.1.7"
author        = "Brent Pedersen"
description   = "fast, simple interval overlaps with binary search"
license       = "MIT"

# Dependencies
requires "nim >= 0.19.2" #, "nim-lang/c2nim>=0.9.13"
srcDir = "src"

skipFiles = @["bench.nim", "example.nim"]

skipDirs = @["tests"]

task test, "run the tests":
  exec "nim c -d:release --lineDir:on -r src/lapper"

task docs, "make docs":
  exec "nim doc2 src/lapper; mkdir -p docs; mv lapper.html docs/index.html"
