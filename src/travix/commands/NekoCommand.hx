package travix.commands;

class NekoCommand extends Command {
  
  override function execute() {
    build(['-neko', 'bin/neko/tests.n'], function () {
      exec('neko', ['bin/neko/tests.n']);
    });
  }
}