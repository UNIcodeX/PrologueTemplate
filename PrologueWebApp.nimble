# Package

version       = "0.1.0"
author        = "Jared Fields"
description   = "A Prologue web application template"
license       = "BSD-3-Clause"
srcDir        = "src"
bin           = @["main"]


# Dependencies

requires "nim >= 1.4.0",
  "cligen  == 1.2.2",
  "cookiejar  == 0.3.0",
  "httpx  == 0.2.4",
  "ioselectors  == 0.1.8",
  "logue  == 0.2.4",
  "nimCommandParser  == 0.1.1",
  "nimcrypto  == 0.5.4",
  "nwt  == 0.1.7",
  "prologue  == 0.4.2",
  "regex  == 0.17.1",
  "segmentation  == 0.1.0",
  "unicodedb  == 0.9.0",
  "unicodeplus  == 0.8.0",
  "wepoll  == 0.1.0"

task installDeps, "=> Install dependencies\n\nSingle-Threaded:":
  exec "nimble install -d -l -y"

task runr, "       => Build and run release version":
  exec "nim c -r -d:danger -d:release --nimblePath:nimbledeps/pkgs src/main"

task runrOrc, "    => Build and run release version (--gc:orc)":
  exec "nim c -r -d:danger -d:release --nimblePath:nimbledeps/pkgs --gc:orc src/main"

task buildDist, "  => Build and place in ./dist\n\nMulti-Threaded:":
  exec "nim c -d:danger -d:release -d:lto --nimblePath:nimbledeps/pkgs --gc:orc -o:dist/main src/main"
  exec "cp -r static dist/"
  exec "cp -r templates dist/"

# Threaded build tasks

task tRunr, "      => Build and run release version":
  exec "nim c -r -d:danger -d:release --nimblePath:nimbledeps/pkgs --threads:on --tlsEmulation:off src/main"

task tRunrOrc, "   => Build and run release version (--gc:orc)":
  exec "nim c -r -d:danger -d:release --nimblePath:nimbledeps/pkgs --gc:orc --threads:on src/main"

task tBuildDist, " => Build and place in ./dist":
  exec "nim c -d:danger -d:release -d:lto --nimblePath:nimbledeps/pkgs --gc:orc -o:dist/main --threads:on src/main"
  exec "cp -r static dist/"
  exec "cp -r templates dist/"