package travix.commands;

using sys.FileSystem;

class NodeCommand extends Command {
  
  override function execute() {
    if (Travix.isTravis && Travix.isMac) {
        // TODO: remove this when travis decided to update their stock node version
        foldOutput('upgrade-nodejs', function() {
          exec('brew', ['update']);
          exec('brew', ['upgrade', 'node']);
        });
    }
    installLib('hxnodejs');
    
    build(['-js', 'bin/node/tests.js', '-lib', 'hxnodejs'], function () {
      if('bin/node/package.json'.exists()) {
        foldOutput('npm-install', withCwd.bind('bin/node', exec.bind('npm', ['install'])));
      }
      exec('node', ['bin/node/tests.js']);
    });
  }
}