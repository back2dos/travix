package travix.commands;

using sys.io.File;
using sys.FileSystem;

class JsCommand extends Command {
  override function execute() {
    if(Travix.isTravis) {
      if(Travix.isMac) {
        aptGet('phantomjs');
      } else if(Travix.isLinux) {
        
        foldOutput('phantomjs-update', function() {
          exec('sudo', ['apt-get', 'update']);
          
          for(dep in ['build-essential', 'chrpath', 'libssl-dev', 'libxft-dev', 'libfreetype6', 'libfreetype6-dev', 'libfontconfig1', 'libfontconfig1-dev'])
            aptGet(dep);

          var PHANTOM_JS = "phantomjs-2.1.1-linux-x86_64";
          exec('wget', ['https://github.com/Medium/phantomjs/releases/download/v2.1.1/$PHANTOM_JS.tar.bz2']);
          exec('tar', ['xvjf', '$PHANTOM_JS.tar.bz2']);
          exec('export PATH=$$PWD/$PHANTOM_JS/bin/:$$PATH');
          exec('echo $$PATH');
        }
      }
    }
    
    build(['-js', 'bin/js/tests.js'], function () {
      var index = 'bin/js/index.html';
      if(!index.exists()) index.saveContent(defaultIndexHtml());
      var runPhantom = 'bin/js/runPhantom.js';
      if(!runPhantom.exists()) runPhantom.saveContent(defaultPhantomScript());
      exec('phantomjs', ['-v']);
      exec('phantomjs', ['--web-security=no', runPhantom]);
    });
  }
  
  macro static function defaultIndexHtml() {
    return Macro.loadFile('js/index.html');
  }
  macro static function defaultPhantomScript() {
    return Macro.loadFile('js/runPhantom.js');
  }
}