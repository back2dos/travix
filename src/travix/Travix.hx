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
  static var ALL = 'interp,neko,python,node,flash,java,cpp,cs,php';
  
  static inline var TRAVIS_CONFIG = '.travis.yml';
  static inline var HAXELIB_CONFIG = 'haxelib.json';
  
  static inline var TRAVIX_COUNTER = '.travix_counter';
  
  static var isTravis = Sys.getEnv('TRAVIS') == 'true';
  static var counter = 0;
  static var haxeVersion:String;
  
  var cmd:String;
  var args:Array<String>;

  function new(cmd, args) { 
    this.cmd = cmd;
    this.args = args;
  }

  ///// General functions ///////////////////////////////////////////////////////
  
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

  function makeJson(source:ProjectSource) {
    if (HAXELIB_CONFIG.exists()) return;
    
    function defaultClassPath() {
      for (option in 'src,hx'.split(','))
        if (option.exists()) return '$option';
      return '.';
    }
    
    var infos:Infos = {
      name: enter('library name', Sys.getCwd().removeTrailingSlashes().withoutDirectory()),
      classPath: enter('classpath', defaultClassPath()),
      dependencies: { },
      contributors: [enter('User name', switch source {
        case GitHub(user, _): user;
        default: null;
      })],
      tags: [for (t in enter('Tags (comma separated)', '').split(','))
        switch t.trim() {
          case '': continue;
          case v: v;
        }
      ],
      version: '0.0.0',
      license: 'MIT',
      releasenote: 'initial release',
    }
    
    switch source {
      case GitHub(u, p):
        infos.url = 'https://github.com/$u/$p/';
      default:
    }
    
    HAXELIB_CONFIG.saveContent(Json.stringify(infos, '  '));
  }
  
  function doInit() {
    
    var source = Unknown;
    {
      var p = new Process('git', ['config', '--get', 'remote.origin.url']);
      switch p.exitCode() {
        case 0: 
          var url = p.stdout.readAll().toString();
          if (url.startsWith('https://github.com/')) {
            var parts = url.split('/');
            var user = parts[3],
                project = parts[4].trim();
                
            if (project.endsWith('.git'))
              project = project.substr(0, project.length - 4);
              
            source = GitHub(user, project);
          }
          else {
            println('Git remote found, but does not seem to be on GitHub. Assuming plain Git');
            source = Git(url);
          }
        default: 
          println('No git installed. Cannot guess remote url.');
      }
    }
    
    makeYml();
    makeJson(source);
    
    if (!TESTS.exists()) {
      println('no $TESTS found');
      
      var cp = enter('class path for tests', 'tests');
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
      
      {
        var mainFile = cp + '/' + main.replace('.', '/') + '.hx';
        
        if (!mainFile.exists()) {
          println('Generating entrypoint in $mainFile');
          try {
            ensureDir(mainFile.normalize());
            
            var pack = main.split('.');
            var name = pack.pop();
            
            mainFile.saveContent(defaultEntryPoint());
          }
          catch (e:Dynamic) {
            println('Failed to generate entrypoint because $e');
          }
        }
      }
      
      var profile = PROFILE;
      
      switch source {
        case GitHub(user, _):
          profile += user;
        default:
      }
      
      if (ask('Activate CI for this project now'))      
        switch Sys.systemName() {
          case 'Windows':
            exec('start', [profile]);
          case 'Linux':
            exec('xdg-open', [profile]);
          case 'Mac':
            exec('open', [profile]);
          default:
            println('Unknown OS. Please go to $profile');
        }
    }
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
  
  function getInfos():Infos
    return haxe.Json.parse(File.getContent(HAXELIB_CONFIG));

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
  
  function classPath()
    return switch getInfos().classPath {
      case null: '.';
      case v: v;
    }    
    
  function build(args:Array<String>, run) {
      
    startFold('build-$cmd');
    exec('haxe', ['-lib', getInfos().name, 'tests.hxml', '-D', 'travix'].concat(args).concat(this.args));
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

  function withCwd<T>(dir:String, f:Void->T) {
    var old = getCwd();
    setCwd(dir);
    var ret = f();
    setCwd(old);
    return ret;
  }

  ///// Build methods for each target //////////////////////////////////////////////////////
  
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
    var homePath = switch Sys.systemName() {
      case 'Linux': "$HOME";
      case _: null;
    }

    if(homePath == null) {
      build(['-swf', 'bin/swf/tests.swf'], function () {});
      return;
    }    

    var flashPath = '$homePath/.macromedia/Flash_Player';

    startFold('flash-install');

    // Some xvfb settings
    exec('export', ['DISPLAY=:99.0']);
    exec('export', ['AUDIODEV=null']);

    // Create a configuration file so the trace log is enabled
    exec('eval', ['echo "ErrorReportingEnable=1\\nTraceOutputFileEnable=1" > "$homePath/mm.cfg"']);

    // Add the current directory as trusted, so exit can be used.
    exec('eval', ['mkdir -m 777 -p "$flashPath/#Security/FlashPlayerTrust"']);
    exec('eval', ['echo "`pwd`" > "$flashPath/#Security/FlashPlayerTrust/travix.cfg"']);

    exec('eval', ['mkdir -m 777 -p "$flashPath/Logs"']);
    exec('eval', ['rm -f "$flashPath/Logs/flashlog.txt"']);
    exec('eval', ['touch "$flashPath/Logs/flashlog.txt"']);

    // Download and unzip the player, unless it exists already
    if(command("eval", ['test -f "$flashPath/flashplayerdebugger"']) != 0) {
      exec('wget', ['-nv', 'http://fpdownload.macromedia.com/pub/flashplayer/updaters/11/flashplayer_11_sa_debug.i386.tar.gz']);
      exec('eval', ['tar -C "$flashPath" -xf flashplayer_11_sa_debug.i386.tar.gz --wildcards "flashplayerdebugger"']);
      exec('rm', ['-f', 'flashplayer_11_sa_debug.i386.tar.gz']);

      // Installing 386 packages on Travis/trusty is a mess.
      if(isTravis) {
        exec('eval', ['wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -']);
        exec('eval', ['sudo sed -i -e \'s/deb http/deb [arch=amd64] http/\' "/etc/apt/sources.list.d/google-chrome.list" "/opt/google/chrome/cron/google-chrome"']);
        exec('sudo', ['dpkg', '--add-architecture', 'i386']);
        exec('sudo', ['apt-get', 'update']);
      }

      // Required flash libs
      var packages = ["libcurl3:i386","libglib2.0-0:i386","libx11-6:i386", "libxext6:i386","libxt6:i386",
        "libxcursor1:i386","libnss3:i386", "libgtk2.0-0:i386"];

      for(pack in packages) aptGet(pack);

    }
    
    // Tail the logfile. Must use eval to start tail in background, to see the output.
    exec('eval', ['tail -f --follow=name --retry "$flashPath/Logs/flashlog.txt" &']);
    endFold('flash-install');

    build(['-swf', 'bin/swf/tests.swf', '-D', 'flash-exit'], function () {
      // The flash player has some issues with unexplained crashes,
      // but if it runs about 7 times, it should succeed one of those.
      var ok = false;
      for(i in 1 ... 8) {
        if(command('eval', ['xvfb-run "$flashPath/flashplayerdebugger" bin/swf/tests.swf']) == 0) {
          ok = true; break;
        }
      }

      // Kill the tail process
      exec('eval', ["ps aux | grep -ie [L]ogs/flashlog.txt | awk '{print $2}' | xargs kill -9"]);

      if(!ok) {
        // Testing didn't complete, so xvfb may have crashed even though tests are passing.
        // Special solution for Buddy: As a final measure, check flashlog.txt if tests passed.
        if(command('eval', ['grep -E "^[0-9]+ specs, 0 failures, [0-9]+ pending$$" "$flashPath/Logs/flashlog.txt"']) != 0) {
          println('Flash execution failed too many times, build failure.');
          exit(1);
        }
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

  function doLua() {
    startFold('lua-install');
    if(command('eval', ['which luarocks >/dev/null']) != 0) {

      for(pack in ["lua5.2","make","unzip","libpcre3","libpcre3-dev"]) 
        aptGet(pack);

      // Add source files so luarocks can be compiled
      exec('sudo', ['mkdir', '-p', '/usr/include/lua/5.2']);
      exec('wget', ['-q', 'http://www.lua.org/ftp/lua-5.2.0.tar.gz']);
      exec('tar', ['xf', 'lua-5.2.0.tar.gz']);
      exec('eval', ['sudo cp lua-5.2.0/src/* /usr/include/lua/5.2']);
      exec('rm', ['-rf', 'lua-5.2.0']);
      exec('rm', ['-f', 'lua-5.2.0.tar.gz']);

      // Compile luarocks
      exec('wget', ['-q', 'http://luarocks.org/releases/luarocks-2.3.0.tar.gz']);
      exec('tar', ['zxpf', 'luarocks-2.3.0.tar.gz']);

      withCwd('luarocks-2.3.0', function() {
        exec('./configure');
        exec('eval', ['make build >/dev/null']);
        exec('eval', ['sudo make install >/dev/null']);
      });

      exec('rm', ['-f', 'luarocks-2.3.0.tar.gz']);
      exec('rm', ['-rf', 'luarocks-2.3.0']);

      // Install lua pcre and lfs so it works with Haxe
      exec('eval', ['sudo luarocks install lrexlib-pcre 2.7.2-1']);
      exec('eval', ['sudo luarocks install luafilesystem']);
    }
    endFold('lua-install');

    build(['-lua', 'bin/lua/tests.lua'], function () {
      exec('lua', ['bin/lua/tests.lua']);
    });
  }
  
  function doHelp() {
    println('Commands');
    println('  ');
    println('  init - initializes a project with a .travis.yml');
    println('  install - installs dependencies');
    println('  ');
    println('  cpp - run tests on cpp');
    println('  cs - run tests on cs');
    println('  flash - run tests on flash');
    println('  interp - run tests on interpreter');
    println('  java - run tests on java');

    if(haxeVersion >= "3.3.0") 
      println('  lua - run tests on lua');

    println('  neko - run tests on neko');
    println('  node - run tests on nodejs (with hxnodejs)');
    println('  php - run tests on php');
    println('  python - run tests on python');
  }

  ///// Static methods /////////////////////////////////////////////////////////////////////
  
  static function main() {
    
    haxeVersion = {
      var p = new Process('haxe', ['-version']);
      p.stderr.readAll().toString();
    }
    if(haxeVersion >= "3.3.0") ALL += ",lua";

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
      case 'lua': 
        if(haxeVersion < "3.3.0") die('lua requires haxe >= 3.3.0');
        else t.doLua();
      case v:
        die('Unknown command $v');
    }
  }

  static function incrementCounter()
    if(isTravis) {
      counter = TRAVIX_COUNTER.exists() ? Std.parseInt(TRAVIX_COUNTER.getContent()) : 0;
      TRAVIX_COUNTER.saveContent(Std.string(counter+1));
    }
  
  static function die(message:String, ?code = 500):Dynamic {
    println(message);
    exit(code);
    return null;
  }
  
  static function ensureDir(dir:String) {
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
  
  macro static function defaultFile() {
    return loadFile('default.yml');
  }  
  macro static function defaultEntryPoint() {
    return loadFile('default.hx');
  }  
  #if macro
  static function loadFile(name:String) {
    return MacroStringTools.formatString(File.getContent(Context.getPosInfos((macro null).pos).file.directory() + '/$name'), Context.currentPos());
  }
  #end
}

private typedef Infos = { 
  name: String, 
  ?dependencies:DynamicAccess<String>,
  ?classPath:String,
  contributors:Array<String>,
  ?url:String,
  tags:Array<String>,
  license:String,
  version:String,
  releasenote:String,
}

enum ProjectSource {
  Unknown;
  GitHub(user:String, project:String);
  Git(url:String);
}