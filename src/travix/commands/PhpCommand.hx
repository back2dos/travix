package travix.commands;

import tink.cli.Rest;
import Sys.*;

class PhpCommand extends Command {

  var isPHP7Target:Bool;
  var isPHP7Required:Bool;
  var isPHPInstallationRequired:Bool;

  var phpPackage:String;
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
      case Success(out): !new EReg(isPHP7Required ? "PHP 7\\." : "PHP 5\\.", "").match(out);
      case Failure(_):   true;
    }

    if(isPHPInstallationRequired) {
      switch Sys.systemName() {
        case 'Linux':
          phpPackage = "php";
          phpPackageVersion = isPHP7Required ? "7.4" : "5.6";
          phpCmd = "php" + phpPackageVersion;

        case 'Mac':
          phpPackage = isPHP7Required ? "php" : "shivammathur/php/php";
          phpPackageVersion = isPHP7Required ? "7.4" : "5.6";

        case 'Windows':
          phpPackage = "php";
          phpPackageVersion = isPHP7Required ? "7.4.14" : "5.6.40";
          phpCmd = "C:\\tools\\" + (isPHP7Required ? "php74" : "php56") + "\\php.exe";
      }
    }
  }

  public function install() {
    foldOutput("php-install", function() {
      if (isPHPInstallationRequired) {
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
            if(!isPHP7Required) {
              exec('brew', ['tap', 'shivammathur/php']); // https://github.com/shivammathur/homebrew-php
            }
            exec('brew', ['tap', 'ezzatron/brew-php']); // https://github.com/ezzatron/brew-php
            exec('brew', ['install', 'brew-php']);
            exec('brew', ['php', 'install', phpPackage + "@" + phpPackageVersion]);
            exec('brew', ['php', 'link', phpPackage + "@" + phpPackageVersion]);
          case 'Windows':
            installPackage(phpPackage, ['--version', phpPackageVersion, '--allow-downgrade']);
          case v:
            println('[ERROR] Don\'t know how to install PHP on $v');
            exit(1);
        }
      }
    });

    foldOutput("php-version", function() {
      // print the effective PHP version
      exec(phpCmd, ['--version']);
    });
  }

  public function buildAndRun(rest:Rest<String>) {
    build(
      isPHP7Target ? 'php7' : 'php',
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
