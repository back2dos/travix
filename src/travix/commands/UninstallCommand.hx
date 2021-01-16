package travix.commands;

import travix.*;

class UninstallCommand extends Command {

  @:defaultCommand
  public function help() {
    Sys.println(tink.Cli.getDoc(this));
  }

  @:command
  public function php()
    new PhpCommand(false).uninstall();

  @:command
  public function php7()
    new PhpCommand(true).uninstall();

}