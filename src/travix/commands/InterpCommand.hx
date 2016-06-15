package travix.commands;

class InterpCommand extends Command {
  override function execute() {
    build(['--interp'], function () {});
  }
}