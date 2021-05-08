package travix.commands;

import tink.cli.Rest;

using sys.FileSystem;

class JavaCommand extends Command {
  
  public function install() {
    
  }

  public function buildAndRun(rest:Rest<String>) {
    var main = Travix.getMainClassLocalName();
    
    installLib('hxjava');
    
    build('java', ['-java', 'bin/java'].concat(rest), function () {
      if('.buckconfig'.exists()) {
        withCwd('bin/java', function() {
          exec('buck', ['build', ':run']);
          exec('buck', ['run', ':run']);
        });
      } else {
        var outputFile = main + (isDebugBuild(rest) ? '-Debug' : '');
        exec('java', ['-jar', 'bin/java/$outputFile.jar']);
      }
    });
  }
}
