package travix.commands;

using sys.io.File;
using sys.FileSystem;

class JsCommand extends Command {
  override function execute() {
    build(['-js', 'bin/js/tests.js'], function () {
      var index = 'bin/js/index.html';
      if(!index.exists()) index.saveContent(defaultIndexHtml());
      var runPhantom = 'bin/js/runPhantom.js';
      if(!runPhantom.exists()) runPhantom.saveContent(defaultPhantomScript());
      exec('phantomjs', [runPhantom]);
    });
  }
  
  macro static function defaultIndexHtml() {
    return Macro.loadFile('js/index.html');
  }
  macro static function defaultPhantomScript() {
    return Macro.loadFile('js/runPhantom.js');
  }
}