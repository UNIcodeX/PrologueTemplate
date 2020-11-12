## Template for starting a web application with Prologue.

### Build Options
```
nimble installDeps => Locally install dependencies
```

#### Single-Threaded
```
nimble runr        => Build and run release version.
nimble runrOrc     => Build and run release version (--gc:orc).
nimble buildDist   => Build and place in ./dist
```

#### Multi-Threaded
```
nimble tRunr       => Multi-Threaded - build and run release version.
nimble tRunrOrc    => Multi-Threaded - build and run release version (--gc:orc).
nimble tBuildDist  => Multi-Threaded - build and place in ./dist"
```