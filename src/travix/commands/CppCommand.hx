package travix.commands;

import Sys.*;

class CppCommand extends Command {
  
  override function execute() {
    var main = Travix.getMainClass();
    
    if (getEnv('TRAVIS_HAXE_VERSION') == 'development') {
      
      if(systemName() == 'Linux') {
          aptGet('gcc-multilib');
          aptGet('g++-multilib'); 
      }
      
      if (!libInstalled('hxcpp')) {
        foldOutput('git-hxcpp', function() {
          exec('haxelib', ['git', 'hxcpp', 'https://github.com/HaxeFoundation/hxcpp.git']);
          withCwd(run('haxelib', ['path', 'hxcpp']).split('\n')[0], buildHxcpp);
        });
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
}