package travix;

import haxe.DynamicAccess;
import haxe.Json;
import sys.FileSystem;
import haxe.ds.Option;
import sys.io.*;
import Sys.*;

using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using sys.io.File;

#if macro
import haxe.macro.MacroStringTools;
import haxe.macro.Context;
#end

enum RunResult {
  Success(output:String);
  Failure(code:Int, output:String);
}

class Travix {
  static inline var PROFILE = 'https://travis-ci.org/profile/';
  static inline var TESTS = 'tests.hxml';
  
  static inline var DEFAULT_PLATFORMS = 'interp, neko, node, python, java';
  static inline var ALL = 'interp,neko,python,node,flash,java,cpp,cs,php';
  
  static inline var TRAVIS_CONFIG = '.travis.yml';
  static inline var HAXELIB_CONFIG = 'haxelib.json';
  
  static inline var TRAVIX_COUNTER = '.travix_counter';
  
  static var isTravis = Sys.getEnv('TRAVIS') == 'true';
  static var counter = 0;
  
  var cmd:String;
  var args:Array<String>;
  function new(cmd, args) { 
    this.cmd = cmd;
    this.args = args;
  }
  
  function enter(what:String, def:String) {
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
  function makeYml() {
    if (TRAVIS_CONFIG.exists() && !ask('The $TRAVIS_CONFIG is already present. Do you wish to replace it with a new one')) return;
    
    var platforms = [for (p in enter('platforms as a comma-separated list or `all`', DEFAULT_PLATFORMS).split(',')) 
        switch p.trim() {
          case '': continue;
          case v: v;
        }
    ];
    
    if (platforms.remove('all'))
      platforms = ALL.split(',');
    
    TRAVIS_CONFIG.saveContent(defaultFile());
  }
  
  function makeJson() {
    if (HAXELIB_CONFIG.exists()) return;
    
    function defaultClassPath() {
      for (option in 'src,hx'.split(','))
        if (option.exists()) return './$option';
      return '.';
    }
    
    var infos:Infos = {
      name: enter('library name', Sys.getCwd().removeTrailingSlashes().withoutDirectory()),
      classPath: enter('classpath', defaultClassPath()),
      dependencies: {}
    }
    
    HAXELIB_CONFIG.saveContent(Json.stringify(infos, '  '));
  }
  
  function doInit() {
    
    makeYml();
    makeJson();
    
    if (!TESTS.exists()) {
      println('no $TESTS found');
      
      var cp = enter('class path for tests', './tests/');
      var main = 'RunTests';
      
      for (m in 'Run,Main'.split(',')) 
        if ('$cp/$m.hx'.exists()) {
          main = m;
          break;
        }
        
      main = enter('test entry point', main);
      
      TESTS.saveContent([
        '-cp $cp',
        '-main $main',
      ].join('\n'));
      
      if (ask('Activate CI for this project now'))      
        switch Sys.systemName() {
          case 'Windows':
            exec('start', [PROFILE]);
          case 'Linux':
            exec('xdg-open', [PROFILE]);
          case 'Mac':
            exec('open', [PROFILE]);
          default:
            println('Unknown OS. Please go to $PROFILE');
        }
    }
  }
  
  macro static function defaultFile() {
    return MacroStringTools.formatString(File.getContent(Context.getPosInfos((macro null).pos).file.directory() + '/default.yml'), Context.currentPos());
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
    
    startFold('installLib-$lib');
    if (!libInstalled(lib))
      switch version {
        case null | '':
          exec('haxelib', ['install', lib, '--always']);
        default:
          exec('haxelib', ['install', lib, version, '--always']);
      }
    endFold('installLib-$lib');
  }
  
  static function die(message:String, ?code = 500):Dynamic {
    println(message);
    exit(code);
    return null;
  }
  
  function doInstall() {
    
    if (!TESTS.exists())
      die('$TESTS not found');
    
    var info = getInfos();
    
    run('haxelib', ['dev', info.name, '.']);
    
    switch info.dependencies {
      case null:
      case v:
        
        for (lib in v.keys())
          installLib(lib, v[lib]);
    }
    run('haxelib', ['install', TESTS, '--always']);  
    
    exec('haxelib', ['list']);
  }
  
  function getInfos():Infos
    return haxe.Json.parse(File.getContent(HAXELIB_CONFIG));
  
  function classPath()
    return switch getInfos().classPath {
      case null: '.';
      case v: v;
    }    
    
  function build(args:Array<String>, run) {
      
    startFold('build-$cmd');
    exec('haxe', ['-lib', getInfos().name, 'tests.hxml'].concat(args).concat(this.args));
    endFold('build-$cmd');
    run();
    
  }
  
  function aptGet(pckge:String, ?args:Array<String>) {
    startFold('aptGet-$pckge');
    switch Sys.systemName() {
      case 'Linux':
        exec('sudo', ['apt-get', 'install', '-qq', pckge].concat(if (args == null) [] else args));
      case 'Mac':
        exec('brew', ['install', pckge].concat(if (args == null) [] else args));
      case v:
        println('Cannot run apt-get on $v');
    }  
    endFold('aptGet-$pckge');
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
  
  function startFold(tag:String) {
      if(!isTravis) return;
      tag = tag.replace('+', 'plus');
      Sys.println('travis_fold:start:$tag.$counter');
  }
    
  function endFold(tag:String) {
      if(!isTravis) return;
      tag = tag.replace('+', 'plus');
      Sys.println('travis_fold:end:$tag.$counter');
  }
  
  function getMainClass() {
    
    function read(file:String) {
      for (line in file.getContent().split('\n').map(function (s:String) return s.split('#')[0].trim())) 
        if (line.startsWith('-main'))
          return Some(line.substr(5).trim());
        else
          if (line.endsWith('.hxml'))
            switch read(line) {
              case None:
              case v: return v;
            }
            
      return None;
    }
    return switch read(TESTS) {
      case Some(v): v;
      default: die('no -main class found in $TESTS');
    }
  }
  
  function doPhp() {
    build(['-php', 'bin/php'], function () {
    
      if (tryToRun('php', ['--version']).match(Failure(_, _)))
        aptGet('php5');
        
      exec('php', ['bin/php/index.php']);
    });
  }
  
  function doInterp() {
    build(['--interp'], function () {});
  }
  
  function doJava() {
    
    var main = getMainClass();
    
    installLib('hxjava');
    
    build(['-java', 'bin/java'], function () {
      exec('java', ['-jar', 'bin/java/$main.jar']);
    });
  }
  
  function withCwd<T>(dir:String, f:Void->T) {
    var old = getCwd();
    setCwd(dir);
    var ret = f();
    setCwd(old);
    return ret;
  }
  
  function doCpp() {
    
    var main = getMainClass();
    
    if (Sys.getEnv('TRAVIS_HAXE_VERSION') == 'development') {
      
      if(Sys.systemName() == 'Linux') {
          aptGet('gcc-multilib');
          aptGet('g++-multilib'); 
      }
      
      if (!libInstalled('hxcpp')) {
        startFold('git-hxcpp');
        exec('haxelib', ['git', 'hxcpp', 'https://github.com/HaxeFoundation/hxcpp.git']);
        withCwd(run('haxelib', ['path', 'hxcpp']).split('\n')[0], buildHxcpp);
        endFold('git-hxcpp');
      }      
    }
    else installLib('hxcpp');
    
    build(['-cpp', 'bin/cpp'], function () {
      exec('./bin/cpp/$main');
    });
  }
  
  function buildHxcpp() {
    withCwd('tools/hxcpp', exec.bind('haxe', ['compile.hxml']));
    withCwd('project', exec.bind('neko', ['build.n']));
  }
  
  function doCs() {
    
    var isWindows = Sys.systemName() == 'Windows';
    
    if (!isWindows)
      if (tryToRun('mono', ['--version']).match(Failure(_, _))) {
        if(Sys.systemName() == 'Linux') {
          aptGet('mono-devel');
          aptGet('mono-mcs');
        } else {
          aptGet('mono');
        }
      }
      
    var main = getMainClass();
    
    installLib('hxcs');
    
    build(['-cs', 'bin/cs/'], function () {
    
      if (isWindows)
        exec('bin/cs/bin/$main.exe'.replace('/', '\\'));
      else
        exec('mono', ['bin/cs/bin/$main.exe']);
    });
  }
  
    
  function doNeko() {
    build(['-neko', 'bin/neko/tests.n'], function () {
      exec('neko', ['bin/neko/tests.n']);
    });
  }
  
  function doPython() {
    build(['-python', 'bin/python/tests.py'], function () {
      if (tryToRun('python3', ['--version']).match(Failure(_, _)))
        aptGet('python3');
      exec('python3', ['bin/python/tests.py']);      
    });
  }
  
  function doFlash() {
    var flashPath = switch Sys.systemName() {
      case 'Linux': '~/.macromedia/Flash_Player';
      case 'Mac': '~/Library/Preferences/Macromedia/Flash\\ Player';
      case _: null;
    }

    if(flashPath == null) {
      build(['-swf', 'bin/swf/tests.swf'], function () {});
      return;
    }

    startFold('flash-install');
    // Some xvfb settings
    exec('export', ['DISPLAY=:99.0']);
    exec('export', ['AUDIODEV=null']);

    // Create a configuration file so the trace log is enabled
    exec('eval', ['echo "ErrorReportingEnable=1\\nTraceOutputFileEnable=1" > ~/mm.cfg']);

    // Add the current directory as trusted, so exit can be used.
    exec('eval', ['mkdir -p $flashPath/#Security/FlashPlayerTrust']);
    exec('eval', ['mkdir -p $flashPath/Logs']);
    exec('eval', ['echo "`pwd`" > $flashPath/#Security/FlashPlayerTrust/travix.cfg']);

    // Download and unzip the player, unless it exists already
    if(command("test", ["-f", "~/flashplayerdebugger"]) != 0) {
	    exec('wget', ['-nv', 'http://fpdownload.macromedia.com/pub/flashplayer/updaters/11/flashplayer_11_sa_debug.i386.tar.gz']);
	    exec('tar', ['-xf', 'flashplayer_11_sa_debug.i386.tar.gz', '-C', '~']);
	    exec('rm', ['-f', 'flashplayer_11_sa_debug.i386.tar.gz']);
	}

    ///// DEBUGGING /////

    //exec('sudo', ['dpkg', '--add-architecture', 'i386']);
    //exec('sudo', ['apt-get', 'clean']);
    //exec('sudo', ['apt-get', 'update']);

    exec("sudo", ['cat', '/etc/apt/sources.list']);

    /////////////////////

    // Required flash libs
    var packages = ["libcurl3:i386","libglib2.0-0:i386","libx11-6:i386", "libxext6:i386","libxt6:i386",
      "libxcursor1:i386","libnss3:i386", "libgtk2.0-0:i386"];

    for(pack in packages) aptGet(pack);

    endFold('flash-install');

    build(['-swf', 'bin/swf/tests.swf'], function () {
      startFold('flash-run');
      // Create the logfile
      exec('rm', ['-f', '$flashPath/Logs/flashlog.txt']);
      exec('touch', ['$flashPath/Logs/flashlog.txt']);

      // Must use eval to start tail in background, to get output
      exec('eval', ['tail -f $flashPath/Logs/flashlog.txt &']);

      // The flash player has some issues with unexplained crashes,
      // but if it runs about 7 times, it should succeed one of those.
      var ok = false;
      for(i in 1 ... 8) {
        if(command('xvfb-run', ['~/flashplayerdebugger', 'bin/swf/tests.swf']) == 0) {
          ok = true; break;
        }
      }

      // Kill the tail process
      exec('eval', ["ps aux | grep -ie [L]ogs/flashlog.txt | awk '{print $2}' | xargs kill -9"]);
      endFold('flash-run');

      if(!ok) {
        println('Flash execution failed too many times, build failure.');
        exit(1);
      }
    });
  }
  
  function doNode() {
    if (isTravis && Sys.systemName() == 'Mac') {
        // TODO: remove this when travis decided to update their stock node version
        startFold('upgrade-nodejs');
        exec('brew', ['update']);
        exec('brew', ['upgrade', 'node']);
        endFold('upgrade-nodejs');
    }
    installLib('hxnodejs');
    
    build(['-js', 'bin/node/tests.js', '-lib', 'hxnodejs'], function () {
      if('bin/node/package.json'.exists()) {
        startFold('npm-install');
        Sys.setCwd('bin/node');
        exec('npm', ['install']);
        Sys.setCwd('../..');
        endFold('npm-install');
      }
      exec('node', ['bin/node/tests.js']);
    });
  }  
  
  function doHelp() {
    println('Commands');
    println('  ');
    println('  init - initializes a project with a .travis.yml');
    println('  install - installs dependencies');
    println('  interp - run tests on interpreter');
    println('  neko - run tests on neko');
    println('  node - run tests on nodejs (with hxnodejs)');
    println('  php - run tests on php');
    println('  java - run tests on java');
    println('  flash - compiles tests on flash');
    println('  python - run tests on python');
    println('  cs - run tests on cs');
    println('  cpp - run tests on cpp');
  }
  
  static function main() {
    
    incrementCounter();
    
    var args = Sys.args();
    
    #if interp
      Sys.setCwd(args.pop());
    #end
    
    var cmd = args.shift();
    var t = new Travix(cmd, args);
    switch cmd {
      case null | 'help': t.doHelp();
      case 'install': t.doInstall();
      case 'init': t.doInit();
      case 'interp': t.doInterp();
      case 'neko': t.doNeko();
      case 'node': t.doNode();
      case 'java': t.doJava();
      case 'flash': t.doFlash();
      case 'cpp': t.doCpp();
      case 'php': t.doPhp();
      case 'python': t.doPython();
      case 'cs': t.doCs();
      case v:
        die('Unknown command $v');
    }
  }
  
  static function incrementCounter()
    if(isTravis) {
      counter = TRAVIX_COUNTER.exists() ? Std.parseInt(TRAVIX_COUNTER.getContent()) : 0;
      TRAVIX_COUNTER.saveContent(Std.string(counter+1));
    }
  
}

private typedef Infos = { 
  name: String, 
  ?dependencies:DynamicAccess<String>,
  ?classPath: String,
}