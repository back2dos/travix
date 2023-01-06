package travix.commands;

import tink.cli.Rest;
import Sys.*;

class PhpCommand extends Command {

  var isPHP7Target:Bool;
  var isPHP7Required:Bool;
  var isPHPInstallationRequired:Bool;

  var phpPackage = "php";
  var phpPackageVersion:String;
  var phpCmd = "php";

  /**
   * @param isPHP7Target if true build with new PHP7 target, if false build with old PHP5 target
   */
  public function new(isPHP7Target:Bool) {
    super();

    this.isPHP7Target = isPHP7Target;
    isPHP7Required = isPHP7Target;

    if(!isPHP7Target) {
      // Have 4+ always requires a PHP7 runtime no matter if the PHP5 or PHP7 target is used to generate PHP code
      if(getHaxeMajorVersion() > 3)
        isPHP7Required = true;
    }

    isPHPInstallationRequired = switch(tryToRun(phpCmd, ['--version'])) {
      case Success(out):
        var r = ~/^PHP ([0-9]+\.[0-9]+)/;
        if (r.match(out)) {
          var phpVer = Std.parseFloat(r.matched(1));
          isPHP7Required ? phpVer < 7 || phpVer >= 8 : phpVer < 5 || phpVer >= 7;
        } else {
          true;
        }
      case Failure(_):   true;
    }

    if(isPHPInstallationRequired) {
      switch Sys.systemName() {
        case 'Linux':
          phpPackageVersion = isPHP7Required ? "7.4" : "5.6";
          phpCmd = "php" + phpPackageVersion;

        case 'Mac':
          phpPackageVersion = isPHP7Required ? "7.4" : "5.6";

        case 'Windows':
          phpPackageVersion = isPHP7Required ? "7.4.14" : "5.6.40";
          phpCmd = "C:\\tools\\" + (isPHP7Required ? "php74" : "php56") + "\\php.exe";
      }
    }
  }

  public function install() {
    if (isPHPInstallationRequired) {
      foldOutput("php-install", function() {
        switch Sys.systemName() {
          case "Linux":
            installPackage('software-properties-common'); // ensure 'add-apt-repository' command is present
            exec('sudo', ['add-apt-repository', '-y', 'ppa:ondrej/php']);
            exec('sudo', ['apt-get', 'update']);
            installPackages([
              phpPackage + phpPackageVersion + "-cli",
              phpPackage + phpPackageVersion + "-mbstring",
              phpPackage + phpPackageVersion + "-xml"
            ], [ "--allow-unauthenticated" ]);
          case 'Mac':
            exec('brew', ['tap', 'ezzatron/brew-php']); // https://github.com/ezzatron/brew-php
            exec('brew', ['install', 'brew-php']);

            // PHP 7 and older are unavailable in brew, so we have to install them differently
            if (Std.parseInt(phpPackageVersion.split("\\.")[0]) < 8) {
              exec('brew', ['tap', 'shivammathur/php']); // https://github.com/shivammathur/homebrew-php
              exec('brew', ['php', 'install', 'shivammathur/php/' + phpPackage + "@" + phpPackageVersion]);
            } else {
              exec('brew', ['php', 'install', phpPackage + "@" + phpPackageVersion]);
            }

            exec('brew', ['php', 'link', phpPackage + "@" + phpPackageVersion]);
          case 'Windows':
            // --ignore-package-exit-codes is to prevent
            // "Packages requiring reboot: - vcredist140 (exit code 3010)" from failing the installation
            installPackage(phpPackage, ['--version', phpPackageVersion, '--allow-downgrade', '--ignore-package-exit-codes']);
          case v:
            println('[ERROR] Don\'t know how to install PHP on $v');
            exit(1);
        }
      });
    }

    foldOutput("php-version", function() {
      // print the effective PHP version
      exec(phpCmd, ['--version']);
    });
  }

  public function buildAndRun(rest:Rest<String>) {
    build(
      'php' + phpPackageVersion,
      (isPHP7Target ? ['-php', 'bin/php', '-D', 'php7'] : ['-php', 'bin/php']).concat(rest),
      function() {
        exec(phpCmd, ['-d', 'xdebug.max_nesting_level=9999', 'bin/php/index.php']);
      }
    );
  }

  public function uninstall() {
    if(!isPHPInstallationRequired)
      return;

    // removing PHP to be able to run another PhpCommand that may need another PHP version
    foldOutput('php-uninstall', function() {
      switch Sys.systemName() {
        case 'Linux': exec('sudo', ['apt-get', '-qy', 'remove', phpPackage + phpPackageVersion]);
        case 'Mac':   exec('brew', ['remove', phpPackage + "@" + phpPackageVersion]);
      }
    });
  }
}
