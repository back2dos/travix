package travix.commands;

import tink.cli.Rest;

using sys.FileSystem;

class NodeCommand extends Command {
  
  static var VERSION_RE = ~/(\d*)\.(\d*)\.(\d*)/;
  
  public function install() {
    if (Travix.isTravis && Os.isMac) {
        foldOutput('upgrade-nodejs', function() {
          // homebrew will fail if current version is already latest
          // so we need to check it first
          switch [tryToRun('node', ['-v']), tryToRun('brew', ['info', 'node'])] {
            case [Success(current), Success(available)]:
              var current = VERSION_RE.match(current) ? Std.parseInt(VERSION_RE.matched(1)) : 0;
              var available = VERSION_RE.match(available) ? Std.parseInt(VERSION_RE.matched(1)) : 0;
              if(current < available) exec('brew', ['upgrade', 'node']);
            default:
                exec('brew', ['upgrade', 'node']);
          }
        });
    }
  }

  public function buildAndRun(rest:Rest<String>) {
    installLib('hxnodejs');
    
    build('node', ['-js', 'bin/node/tests.js', '-lib', 'hxnodejs'].concat(rest), function () {
      if(Travix.isCI && 'bin/node/package.json'.exists()) {
        foldOutput('npm-install', withCwd.bind('bin/node', exec.bind('npm', ['install'])));
      }
      exec('node', ['bin/node/tests.js']);
    });
  }
}