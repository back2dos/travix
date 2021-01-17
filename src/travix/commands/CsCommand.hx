package travix.commands;

import tink.cli.Rest;

class CsCommand extends Command {

  public function install() {

    if (Os.isMac) {

      installPackage('mono');

    } else if (Os.isLinux) {

      // http://www.mono-project.com/download/#download-lin
      exec('eval', ['sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF']);
      switch tryToRun('lsb_release', ['-cs']) {
        case Success('precise\n'):
          exec('eval', ['echo "deb http://download.mono-project.com/repo/ubuntu precise main" | sudo tee /etc/apt/sources.list.d/mono-official.list']);
        case Success('trusty\n'):
          exec('eval', ['echo "deb http://download.mono-project.com/repo/ubuntu trusty main" | sudo tee /etc/apt/sources.list.d/mono-official.list']);
        case Success('xenial\n'):
          exec('eval', ['echo "deb http://download.mono-project.com/repo/ubuntu xenial main" | sudo tee /etc/apt/sources.list.d/mono-official.list']);
        default:
      }

      installPackage('mono-devel');
      installPackage('mono-mcs');

      // print the effective mono version
      exec('mono', ['-V']);
    }
  }
  
  public function buildAndRun(rest:Rest<String>) {

    var main = Travix.getMainClassLocalName();

    installLib('hxcs');

    build('cs', ['-cs', 'bin/cs/'].concat(rest), function () {
      var outputFile = main + (isDebugBuild(rest) ? '-Debug' : '');
      if (Os.isWindows)
        exec('bin\\cs\\bin\\$outputFile.exe');
      else
        exec('mono', ['bin/cs/bin/$outputFile.exe']);
    });
  }
}