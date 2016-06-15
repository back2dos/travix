package travix.commands;

using StringTools;

class CsCommand extends Command {
  
  override function execute() {
    
    if (!Travix.isWindows)
      if (tryToRun('mono', ['--version']).match(Failure(_, _))) {
        if(Travix.isLinux) {
          aptGet('mono-devel');
          aptGet('mono-mcs');
        } else {
          aptGet('mono');
        }
      }
      
    var main = Travix.getMainClass();
    
    installLib('hxcs');
    
    build(['-cs', 'bin/cs/'], function () {
    
      if (Travix.isWindows)
        exec('bin/cs/bin/$main.exe'.replace('/', '\\'));
      else
        exec('mono', ['bin/cs/bin/$main.exe']);
    });
  }
}