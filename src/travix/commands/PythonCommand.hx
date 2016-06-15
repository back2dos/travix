package travix.commands;

class PythonCommand extends Command {
  
  override function execute() {
    build(['-python', 'bin/python/tests.py'], function () {
      if (tryToRun('python3', ['--version']).match(Failure(_, _)))
        aptGet('python3');
      exec('python3', ['bin/python/tests.py']);
    });
  }
}