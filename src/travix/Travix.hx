package travix;

import haxe.DynamicAccess;
import haxe.Json;
import sys.FileSystem;
import haxe.ds.Option;
import sys.io.*;
import Sys.*;
import travix.commands.*;

using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using sys.io.File;

#if macro
import haxe.macro.MacroStringTools;
import haxe.macro.Context;
#end

class Travix {
  public static inline var TESTS = 'tests.hxml';
  static inline var TRAVIX_COUNTER = '.travix_counter';
  static inline var HAXELIB_CONFIG = 'haxelib.json';
  
  public static var isTravis = getEnv('TRAVIS') == 'true';
  
  // repeated calls, but ok...
  public static var isLinux = systemName() == 'Linux';
  public static var isMac = systemName() == 'Mac';
  public static var isWindows = systemName() == 'Windows';
  
  public static var counter = 0;
  
  public static function getInfos():Option<Infos> {
    return if(HAXELIB_CONFIG.exists()) Some(haxe.Json.parse(HAXELIB_CONFIG.getContent())) else None;
  }
    
  /**
   * @return fully qualified class name of the main class
   */
  public static function getMainClassFQName():String {
    
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
    
    var args = Sys.args();
    for(i in 0...args.length) {
      if(args[i] == '-main') return args[i + 1];
      else if(args[i].endsWith('.hxml')) switch read(args[i]) {
        case None: // do nothing
        case Some(v): return v;
      }
    }
    
    if(TESTS.exists()) switch read(TESTS) {
      case None: // do nothing
      case Some(v): return v;
    }
    
    return die('no -main class found');
  }
  
  /**
   * @return non-qualified class name of the main class (i.e. without package)
   */
  public static function getMainClassLocalName():String {
    return getMainClassFQName().split(".").pop();
  }

  public static function die(message:String, ?code = 500):Dynamic {
    println(message);
    exit(code);
    return null;
  }

  static function main() {
    incrementCounter();
    
    var args = Sys.args();
    
    if(Sys.getEnv('HAXELIB_RUN') == '1')
      Sys.setCwd(args.pop());
    
    var cmd = args.shift();
    var command:Command = switch cmd {
      case null | 'help': new HelpCommand(cmd, args);
      case 'install': new InstallCommand(cmd, args);
      case 'init': new InitCommand(cmd, args);
      case 'auth': new AuthCommand(cmd, args);
      case 'release': new ReleaseCommand(cmd, args);
      case 'interp': new InterpCommand(cmd, args);
      case 'neko': new NekoCommand(cmd, args);
      case 'node': new NodeCommand(cmd, args);
      case 'js': new JsCommand(cmd, args);
      case 'java': new JavaCommand(cmd, args);
      case 'flash': new FlashCommand(cmd, args);
      case 'cpp': new CppCommand(cmd, args);
      case 'php':
        #if (haxe_ver < 4)
          new PhpCommand(cmd, args);
        #else
          new Php7Command(cmd, args);
        #fi
      case 'php7': new Php7Command(cmd, args);
      case 'python': new PythonCommand(cmd, args);
      case 'cs': new CsCommand(cmd, args);
      case 'lua': new LuaCommand(cmd, args);
      case v: die('Unknown command $v');
    }
    command.execute();
  }

  static function incrementCounter()
    if(isTravis) {
      counter = TRAVIX_COUNTER.exists() ? Std.parseInt(TRAVIX_COUNTER.getContent()) : 0;
      TRAVIX_COUNTER.saveContent(Std.string(counter+1));
    }
}

