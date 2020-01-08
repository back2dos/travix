package travix.commands;

import tink.cli.Rest;

using sys.io.File;
using sys.FileSystem;

class JsCommand extends Command {

  public function install() {
    new NodeCommand().install();
    if(!'bin/js'.exists()) 'bin/js'.createDirectory();
    withCwd('bin/js', function() {
      if(!'package.json'.exists()) 'package.json'.saveContent('{}');
      if (!'node_modules/puppeteer'.exists()) {
        switch Sys.getEnv('PUPPETEER_EXECUTABLE_PATH') {
          case null:
          case v if (v.exists()):
            Sys.putEnv('PUPPETEER_SKIP_CHROMIUM_DOWNLOAD', 'true');
          default:
        }
        exec('npm', ['i', '--save-dev', 'puppeteer', 'http-server-legacy']);
      }
    });
  }

  public function buildAndRun(rest:Rest<String>) {
    build('js', ['-js', 'bin/js/tests.js', '--macro', 'addGlobalMetadata("js.Boot.HaxeError", "@:expose(\'HaxeError\')")'].concat(rest), function () {
      var index = 'bin/js/run.html';
      if(!index.exists()) index.saveContent(defaultIndexHtml());
      var run = 'bin/js/run.js';
      if(!run.exists()) run.saveContent(defaultRunScript());
      exec('node', ['bin/js/run.js']);
    });
  }

  macro static function defaultIndexHtml() {
    return Macro.loadFile('js/index.html');
  }
  macro static function defaultRunScript() {
    return Macro.loadFile('js/run.js');
  }
}