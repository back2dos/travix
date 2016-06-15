package travix.commands;

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
}