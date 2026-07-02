package travix.commands;

import tink.cli.Rest;

class PythonCommand extends Command {

  public function install() {
    if (tryToRun('python3', ['--version']).match(Failure(_, _))) {

      // fix for https://github.com/back2dos/travix/issues/83
      if (Sys.systemName() == 'Mac' && tryToRun('python', ['--version']).match(Success(_))) {
        // https://stackoverflow.com/questions/49672642/trying-to-install-python3-using-brew
        brewExec(['upgrade', "python"]);
      } else {
        installPackage('python3');
      }
    }
  }

  public function buildAndRun(rest:Rest<String>) {
    build('python', ['-python', 'bin/python/tests.py'].concat(rest), function () {
      exec('python3', ['bin/python/tests.py']);
    });
  }
}
