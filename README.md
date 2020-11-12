## Template for starting a web application with Prologue.

### Build Options
```
nimble installDeps        => Install dependencies

Single-Threaded:
nimble runr               => Build and run release version
nimble runrOrc            => Build and run release version (--gc:orc)
nimble buildDist          => Build and place in ./dist

Multi-Threaded:
nimble tRunr              => Build and run release version
nimble tRunrOrc           => Build and run release version (--gc:orc)
nimble tBuildDist         => Build and place in ./dist
```