# Travix - Travis CI helper for Haxe

Are you tired of setting up Travis CI for all your projects? Then `travix` is for you! \o/

## Quickstart

To use travis within one of your libs do this:

```bash
haxelib install travix    # if it's not installed already
haxelib run travix init   # this will ask you to input the necessary information
```

From there, the setup should be straight forward.

## Building

Travix has individual commands for building:

- interp - run tests on interpreter
- neko - run tests on neko
- node - run tests on nodejs (with hxnodejs)
- php - run tests on php
- java - run tests on java
- js - run tests on phantomjs
- flash - run tests on flash (see instructions below)
- python - run tests on python
- cs - run tests on cs
- cpp - run tests on cpp
- lua - run tests on lua

So instead of having to have to define all kinds of builds and figuring out the right way to run them, this will do.

### Using Travix in your code

There are differences among platforms about logging and exiting the process.
For example, we run JS tests on PhantomJS where your test code need to communicate
with the Phantom host in some special ways in order to log or exit the process.
And on Flash you need to use `flash.Lib.trace` and `flash.system.System.exit(status)`.

In order to ease the pain, travix provide a unified interface for these functionalities.
Use them to instead of `trace()`, `Sys.exit()`, etc, for maximum compatibility across platforms

- `travix.Logger.print(string)`: Print a string without newline
- `travix.Logger.println(string)`: Print a string with newline
- `travix.Logger.exit(exitCode)`: Exit the process

If you want to be able to run your tests e.g. locally without Travix dependency use conditional compilation like this:
```haxe
#if travix
    travix.Logger.trace(...);
#else
    trace(...); // ... or your own other trace method
#end
```

The BDD library [Buddy](https://github.com/ciscoheat/buddy) has built-in support for flash and JS testing, so if you're using Buddy you don't even have to worry about the above.

## Reasons to use travix

Apart from helping the pathologically lazy to set up a CI, the strength of `travix` lies in that it deals with dependencies rather gracefully:
  
1. it relies on the [`haxelib.json`](http://lib.haxe.org/documentation/creating-a-haxelib-package/) to install haxelib dependencies. It also uses the `haxelib dev` command to "mount" your library as a haxelib, giving you all the extra features, e.g. the presense of your `-D libname` flag and the inclusion of `extraParams.hxml` in the build. This happens with the `install` command.
2. it follows a fail-fast philosophy. What's that supposed to mean? Normally, in your CI, you will install all dependencies before running any of the tests. If you wait for the installation of hxjava, hxcpp, hxcs, mono and php, only to make your first test abort because of a missing semi-colon or a similarly silly mistake, it can be rather frustrating. To avoid that problem, `travix` diverges from the usual modus operandi of having distinct installation and execution phases, and instead installs such dependencies right before execution, e.g. in the `cs` command.

## Reasons to not use travix

The motivation behind `travix` is to be able to spin up CI setups quickly, for many small libraries (in my case the `tink` libs). It is very likely, that it will not scale up to bigger projects, particularly when multiple builds need to be run in unison to have a test. If you have suggestions - or better yet: pull requests - to make `travix` more useful for such cases, you are highly welcome.

## How to use git version

In your `.travis.yml` simply replace `haxelib install travix` with the following:

```
haxelib git travix https://github.com/back2dos/travix
```
