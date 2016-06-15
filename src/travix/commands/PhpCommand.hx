package travix.commands;

class PhpCommand extends Command {
  
  override function execute() {
    build(['-php', 'bin/php'], function () {
    
      if (tryToRun('php', ['--version']).match(Failure(_, _)))
        aptGet('php5');
        
      exec('php', ['bin/php/index.php']);
    });
  }
}