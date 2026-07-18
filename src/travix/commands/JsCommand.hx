package travix.commands;

import tink.cli.Rest;
import travix.Macro;
import Sys.*;

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
        exec('npm', ['i', '--save-dev', 'puppeteer@24', 'serve']);
      }
    });
  }

  public function buildAndRun(rest:Rest<String>) {
    build('js', ['-js', 'bin/js/tests.js'].concat(rest), function () {
      'bin/js/run.travix.html'.saveContent(defaultIndexHtml());
      'bin/js/run.travix.js'.saveContent(defaultRunScript());

      var userHtml = 'bin/js/run.html';
      if(userHtml.exists())
        println('WARN: bin/js/run.html overrides the default runner page and is deprecated. Prefer customizing via .travix/js/hooks.js, then remove bin/js/run.html.');

      var userRun = 'bin/js/run.js';
      if(userRun.exists()) {
        println('WARN: bin/js/run.js overrides the default JS runner and is deprecated. Prefer customizing via .travix/js/hooks.js, then remove bin/js/run.js.');
        exec('node', [userRun]);
      } else {
        exec('node', ['bin/js/run.travix.js']);
      }
    });
  }

  macro static function defaultIndexHtml() {
    return Macro.loadFile('js/index.html');
  }
  macro static function defaultRunScript() {
    return Macro.loadFile('js/run.js');
  }
}
