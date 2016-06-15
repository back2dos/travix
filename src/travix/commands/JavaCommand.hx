package travix.commands;

class JavaCommand extends Command {
  
  override function execute() {
    var main = Travix.getMainClass();
    
    installLib('hxjava');
    
    build(['-java', 'bin/java'], function () {
      exec('java', ['-jar', 'bin/java/$main.jar']);
    });
  }
}