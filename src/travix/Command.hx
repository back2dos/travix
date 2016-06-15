package travix;

import haxe.*;
import haxe.ds.Option;
import Sys.*;
import sys.io.Process;

using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using sys.io.File;

class Command {
  
  var cmd:String;
  var args:Array<String>;
  
  public function new(cmd, args) {
    this.cmd = cmd;
    this.args = args;
  }
  
  public function execute(){}
  
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
  
  function ask(question:String) {
    while (true) {
      print('$question (y/n)? ');
      var c = Sys.getChar(true);
      println('');
      switch String.fromCharCode(c).toUpperCase() {
        case 'Y': return true;
        case 'N': return false;
        default:
      }
    }
    
    return throw 'unreachable';
  }
  
  function tryToRun(cmd:String, ?params:Array<String>) 
    return try {
      var p = new Process(cmd, params);
      switch p.exitCode() {
        case 0:
          Success(switch p.stdout.readAll().toString() {
            case '': p.stderr.readAll().toString(); //some execs print to stderr
            case v: v;
          });
        case v:
          Failure(v, p.stderr.readAll().toString());
      }
    } catch (e:Dynamic) {
      Failure(404, 'Unknown command $cmd'); 
    }
  
  function run(cmd:String, ?params:Array<String>) {
    var a = [cmd];
    if (params != null)
      a = a.concat(params);
      
    print('> ${a.join(" ")} ...');
    return
      switch tryToRun(cmd, params) {
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
    return tryToRun('haxelib', ['path', lib]).match(Success(_));
  
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
  
  function build(args:Array<String>, run) {
    foldOutput('build-$cmd', exec.bind('haxe', ['-lib', Travix.getInfos().name, 'tests.hxml', '-D', 'travix'].concat(args).concat(this.args)));
    run();
  }
  
  function exec(cmd, ?args) {
    var a = [cmd];
    if (args != null)
      a = a.concat(args);
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

  function aptGet(pckge:String, ?args:Array<String>) {
    foldOutput('aptGet-$pckge', function() {
      switch Sys.systemName() {
        case 'Linux':
          exec('sudo', ['apt-get', 'install', '-qq', pckge].concat(if (args == null) [] else args));
        case 'Mac':
          exec('brew', ['install', pckge].concat(if (args == null) [] else args));
        case v:
          println('Cannot run apt-get on $v');
        }
    });
  }
}


enum RunResult {
  Success(output:String);
  Failure(code:Int, output:String);
}