package travix;

import Sys.*;
import sys.io.Process;
import travix.Os.*;

using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using sys.io.File;

class Command {

  var isFirstPackageInstallation = true;

  public function new() {}

  function getHaxeVersion():String {
    var proc = Os.isWindows ?
      new sys.io.Process('cmd', ["/c", "haxe", "-version"]) :  // workaround for lix where haxe is a batch file
      new sys.io.Process('haxe', ['-version']);

    var stdout = proc.stdout.readAll().toString().replace('\n', '');
    var stderr = proc.stderr.readAll().toString().replace('\n', '');

    return switch stdout.split('+')[0].trim() + stderr.split('+')[0].trim() {
      case '4.0.0 (git build master @ 2344f233a)':      '4.0.0-preview.1';
      case '4.0.0 (git build development @ a018cbd)':   '4.0.0-preview.2';
      case '4.0.0 (git build development @ 3018ab109)': '4.0.0-preview.3';
      case '4.0.0 (git build development @ 1e3e5e016)': '4.0.0-preview.4';
      case '4.0.0 (git build development @ 7eb789f54)': '4.0.0-preview.5';
      case '4.0.0 (git build development @ 1fdd3d59b)': '4.0.0-rc.1';
      case '4.0.0 (git build development @ 77068e10c)': '4.0.0-rc.2';
      case '4.0.0 (git build development @ e3df7a448)': '4.0.0-rc.3';
      case '4.0.0 (git build development @ 97f1e1a9d)': '4.0.0-rc.4';
      case '4.0.0 (git build development @ 4a745347f)': '4.0.0-rc.5';
      case v: v;
    }
  }

  function getHaxeMajorVersion():Int {
    return Std.parseInt(getHaxeVersion().split(".")[0]);
  }

  function enter(what:String, ?def:String):String
    switch def {
      case null:
        println('Please specify $what');
        while (true) {
          switch Sys.stdin().readLine().trim() {
            case '':
            case v: return v;
          }
        }
      default:
        println('Please specify $what (default: $def):');
        return switch Sys.stdin().readLine().trim() {
          case '': def;
          case v: v;
        }
    }

  function ask(question:String, yes:Bool):Bool {
    var defaultAnswer = if (yes) "yes" else "no";
    while (true) {
      print('$question? ($defaultAnswer)');
      switch Sys.stdin().readLine().trim().toUpperCase() {
        case '': return yes;
        case 'YES', 'Y': return true;
        case 'NO', 'N': return false;
        default:
      }
    }

    return throw 'unreachable';
  }

  function tryToRun(cmd:String, ?args:Array<String>):RunResult
    return
      switch cmdResult(cmd, args) {
        case Success({ code: 0, stdout: '', stderr: v } | { code: 0, stdout: v }):
          RunResult.Success(v);
        case Success({ code: code, stderr: msg }):
          RunResult.Failure(code, msg);
        case Failure(e):
          RunResult.Failure(e.code, e.message);
    }

  /**
   * Exits this process if command execution failed.
   *
   * @return the stdout of the command in case of success.
   */
  function run(cmd:String, ?args:Array<String>):String {
    var a = [cmd];
    if (args != null)
      a = a.concat(args);

    print('> ${a.join(" ")} ...');
    return
      switch tryToRun(cmd, args) {
        case Success(v):
          println(' done');
          v;
        case Failure(code, out):
          println(' failure');
          print(out);
          exit(code);
          throw 'unreachable';
      }
  }

  function libInstalled(lib:String):Bool
    return tryToRun(force(which('haxelib')), ['path', lib]).match(Success(_));

  function installLib(lib:String, ?version = ''):Void {
    foldOutput('installLib-$lib', function() {
      if (!libInstalled(lib))
        switch which('lix') {
          case Success(cmd):
            var arg = switch version {
              case null | '': lib;
              case v: '$lib#$v';
            }
            exec('lix', ['install', 'haxelib:$lib']);
          default:
            switch version {
              case null | '':
                exec('haxelib', ['install', lib, '--always']);
              default:
                exec('haxelib', ['install', lib, version, '--always']);
              }
          }
    });
  }

  function foldOutput<T>(tag:String, func:Void->T):T {
    tag = tag.replace('+', 'plus');
    if(Travix.isTravis) Sys.println('travis_fold:start:$tag.${Travix.counter}');
    else if(Travix.isGithubActions) Sys.println('::group::$tag');
    var result = func();
    if(Travix.isTravis) Sys.println('travis_fold:end:$tag.${Travix.counter}');
    else if(Travix.isGithubActions) Sys.println('::endgroup::');
    return result;
  }

  function ensureDir(dir:String):Void {
    var isDir = dir.extension() == '';

    if (isDir)
      dir = dir.removeTrailingSlashes();

    var parent = dir.directory();
    if (parent.removeTrailingSlashes() == dir) return;
    if (!parent.exists())
      ensureDir(parent);

    if (isDir && !dir.exists())
      dir.createDirectory();
  }

  function build(tag, args:Array<String>, run):Void {
    args = args.concat(['-lib', 'travix']);
    switch Travix.getInfos() {
      case None: // do nothing
      case Some(info): args = args.concat(['-lib', info.name]);
    }
    if(Travix.TESTS.exists()) args.push(Travix.TESTS);

    foldOutput('build-$tag', exec.bind('haxe', args));
    run();
  }

  function isDebugBuild(args:Array<String>):Bool {
    function declaresDebugFlag(file:String):Bool {
      for (line in file.getContent().split('\n').map(function (s:String) return s.split('#')[0].trim())) {
        if (line == '-debug')
          return true;
        if (line.endsWith('.hxml') && declaresDebugFlag(line))
          return true;
      }
      return false;
    }

    for (arg in args) {
      if (arg == '-debug')
        return true;
      if (arg.endsWith('.hxml') && declaresDebugFlag(arg))
        return true;
    }

    if (Travix.TESTS.exists() && declaresDebugFlag(Travix.TESTS))
      return true;

    return false;
  }

  #if (hxnodejs && !macro)
    static inline function command(cmd:String, ?args:Array<String>):Int {
      if (args == null)
        return js.node.ChildProcess.spawnSync(cmd, cast {stdio: "inherit", shell: true }).status;
      else
        return js.node.ChildProcess.spawnSync(cmd, args, cast {stdio: "inherit", shell: true }).status;
    }
  #end

  /**
   * Exits this process if command execution failed.
   */
  function exec(cmd, ?args:Array<String>):Void {
    var a = [cmd];
    if (args != null) {
      a = a.concat(args);
      if (isWindows) {//this is pure madness
        cmd = [cmd].concat(args.map(function (a) return '"${a.replace('"', '""')}"')).join(' ');
        args = null;
      }
    }
    println('> ' + a.join(' '));
    switch command(cmd, args) {
      case 0:
      case v: exit(v);
    }
  }

  function withCwd<T>(dir:String, f:Void->T):T {
    var old = getCwd();
    setCwd(dir);
    var ret = f();
    setCwd(old);
    return ret;
  }

  /**
   * Installs software packages using a os-specific package manager. "apt-get" on Linux and "brew" on MacOs.
   *
   * @param additionalArgs additional flags/options to be passed to the package manager
   */
  inline function installPackages(packageNames:Array<String>, ?additionalArgs:Array<String>):Void {
    for (p in packageNames)
      installPackage(p, additionalArgs);
  }

  /**
   * Installs a software package using a OS-specific package manager.
   * "apt-get/yum" on Linux, "brew" on MacOs and "choco" on Windows.
   *
   * @param additionalArgs additional flags/options to be passed to the package manager
   */
  function installPackage(packageName:String, ?additionalArgs:Array<String>):Void {
    foldOutput('installPackage-$packageName', function() {
      switch Sys.systemName() {
        case 'Linux':
          switch which('apt-get') {
            case Success(_):
              if (isFirstPackageInstallation) {
                exec('sudo', ['apt-get', '-qq', 'update']);
                isFirstPackageInstallation = false;
              }
              exec('sudo', ['apt-get', '-yqq', 'install', '--no-install-recommends', packageName].concat(if (additionalArgs == null) [] else additionalArgs));
            default:
              if (isFirstPackageInstallation) {
                exec('sudo', ['yum', 'checkupdate', '-q']);
                isFirstPackageInstallation = false;
              }
              exec('sudo', ['yum', '-yq', 'install', packageName].concat(if (additionalArgs == null) [] else additionalArgs));
          }
        case 'Mac':
          // https://brew.sh/
          if (isFirstPackageInstallation) {
            exec('brew', ['update']); // to prevent "Homebrew must be run under Ruby 2.3!" https://github.com/travis-ci/travis-ci/issues/8552#issuecomment-335321197
            isFirstPackageInstallation = false;
          }
          exec('brew', ['install', packageName].concat(if (additionalArgs == null) [] else additionalArgs));
        case 'Windows':
          // https://chocolatey.org/
          exec('choco', ['install', '--no-progress', packageName].concat(if (additionalArgs == null) [] else additionalArgs));
        case v:
          println('WARN: Don\'t know how to install packages on $v');
      }
    });
  }
}


enum RunResult {
  Success(output:String);
  Failure(code:Int, output:String);
}
