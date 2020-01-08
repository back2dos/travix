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

  function enter(what:String, ?def:String)
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

  function ask(question:String, yes:Bool) {
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

  function tryToRun(cmd:String, ?args:Array<String>)
    return
      switch cmdResult(cmd, args) {
        case Success({ code: 0, stdout: '', stderr: v } | { code: 0, stdout: v }):
          Success(v);
        case Success({ code: code, stderr: msg }):
          Failure(code, msg);
        case Failure(e):
          Failure(e.code, e.message);
    }

  function run(cmd:String, ?args:Array<String>) {
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

  function libInstalled(lib:String)
    return tryToRun(force(which('haxelib')), ['path', lib]).match(Success(_));

  function installLib(lib:String, ?version = '') {

    foldOutput('installLib-$lib', function() {
      if (!libInstalled(lib))
      switch version {
        case null | '':
          exec('haxelib', ['install', lib, '--always']);
        default:
          exec('haxelib', ['install', lib, version, '--always']);
        }
    });
  }

  function foldOutput<T>(tag:String, func:Void->T) {
    tag = tag.replace('+', 'plus');
    if(Travix.isTravis) Sys.println('travis_fold:start:$tag.${Travix.counter}');
    var result = func();
    if(Travix.isTravis) Sys.println('travis_fold:end:$tag.${Travix.counter}');
    return result;
  }

  function ensureDir(dir:String) {
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

  function build(tag, args:Array<String>, run) {
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

  function exec(cmd, ?args:Array<String>) {
    var a = [cmd];
    if (args != null) {
      a = a.concat(args);
      if (isWindows) {//this is pure madness
        cmd = [cmd].concat(args.map(a -> '"${a.replace('"', '""')}"')).join(' ');
        args = null;
      }
    }
    println('> ' + a.join(' '));
    switch command(cmd, args) {
      case 0:
      case v: exit(v);
    }
  }

  function withCwd<T>(dir:String, f:Void->T) {
    var old = getCwd();
    setCwd(dir);
    var ret = f();
    setCwd(old);
    return ret;
  }

  /**
   * Installs software packages using a os-specific pacakge manager. "apt-get" on Linux and "brew" on MacOs.
   *
   * @param additionalArgs additional flags/options to be passed to the package manager
   */
  inline function installPackages(packageNames:Array<String>, ?additionalArgs:Array<String>) {
    for (p in packageNames)
      installPackage(p, additionalArgs);
  }

  /**
   * Installs a software package using a os-specific pacakge manager. "apt-get" on Linux and "brew" on MacOs.
   *
   * @param additionalArgs additional flags/options to be passed to the package manager
   */
  function installPackage(packageName:String, ?additionalArgs:Array<String>) {
    foldOutput('installPackage-$packageName', function() {
      switch Sys.systemName() {
        case 'Linux':
          if (isFirstPackageInstallation) {
            exec('sudo', ['apt-get', 'update', '-qq']);
            isFirstPackageInstallation = false;
          }
          exec('sudo', ['apt-get', 'install', '--no-install-recommends', '-qq', packageName].concat(if (additionalArgs == null) [] else additionalArgs));
        case 'Mac':
          if (isFirstPackageInstallation) {
            exec('brew', ['update']); // to prevent "Homebrew must be run under Ruby 2.3!" https://github.com/travis-ci/travis-ci/issues/8552#issuecomment-335321197
            isFirstPackageInstallation = false;
          }
          exec('brew', ['install', packageName].concat(if (additionalArgs == null) [] else additionalArgs));
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
