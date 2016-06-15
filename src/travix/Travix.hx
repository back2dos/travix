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
  static inline var TESTS = 'tests.hxml';
  static inline var TRAVIX_COUNTER = '.travix_counter';
  static inline var HAXELIB_CONFIG = 'haxelib.json';
  
  public static var isTravis = getEnv('TRAVIS') == 'true';
  
  // repeated calls, but ok...
  public static var isLinux = systemName() == 'Linux';
  public static var isMac = systemName() == 'Mac';
  public static var isWindows = systemName() == 'Windows';
  
  public static var counter = 0;
  
  public static function getInfos():Infos
    return haxe.Json.parse(HAXELIB_CONFIG.getContent());
    
  public static function getMainClass() {
    
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
  
  public static function die(message:String, ?code = 500):Dynamic {
    println(message);
    exit(code);
    return null;
  }

  static function main() {
    
    incrementCounter();
    
    var args = Sys.args();
    #if interp
      Sys.setCwd(args.pop());
    #end
    var cmd = args.shift();
    var command:Command = switch cmd {
      case null | 'help': new HelpCommand(cmd, args);
      case 'install': new InstallCommand(cmd, args);
      case 'init': new InitCommand(cmd, args);
      case 'interp': new InterpCommand(cmd, args);
      case 'neko': new NekoCommand(cmd, args);
      case 'node': new NodeCommand(cmd, args);
      case 'js': new JsCommand(cmd, args);
      case 'java': new JavaCommand(cmd, args);
      case 'flash': new FlashCommand(cmd, args);
      case 'cpp': new CppCommand(cmd, args);
      case 'php': new PhpCommand(cmd, args);
      case 'python': new PythonCommand(cmd, args);
      case 'cs': new CsCommand(cmd, args);
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

