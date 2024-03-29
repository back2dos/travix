package travix.commands;

import tink.cli.Rest;
import Sys.*;

using sys.FileSystem;
using StringTools;

class HashLinkCommand extends Command {

  static inline var HL_GITHUB_RELEASES_BASE_URL = "https://github.com/HaxeFoundation/hashlink/releases/download";

  var hlCommand = "hl";

  public function install() {
    if(!Travix.isCI)
      return;

    var haxeVersion = getHaxeVersion();

    if(Os.isMac && haxeVersion.startsWith('4.')) {
      foldOutput('hashlink-install', function() {
        if (haxeVersion == '4.0.0-preview.1' || haxeVersion == '4.0.0-preview.2') {
          // V1.3 only supports byte code generated by Haxe 4.0.0-preview.1 and 4.0.0-preview.2
          exec('wget', ['$HL_GITHUB_RELEASES_BASE_URL/1.3/hl-1.3-osx32.zip']);
          exec('unzip', ['hl-1.3-osx32.zip']);

          // workaround for: 'dyld: Library not loaded: libhl.dylib' ...  Reason: image not found
          exec('install_name_tool', ['-change', 'libhl.dylib', "hl-1.3-osx32/libhl.dylib".fullPath(), 'hl-1.3-osx32/hl']);

          hlCommand = "hl-1.3-osx32/hl";
          exec('chmod', ['u+x', hlCommand]);
        } else {
          installPackage('hashlink');
        }
      });
      return;
    }

    if(Os.isLinux && haxeVersion == '4.0.0-preview.4') {
      foldOutput('hashlink-install', function() {
        // V1.6 only supports byte code generated by Haxe 4.0.0-preview.4
        exec('wget', ['$HL_GITHUB_RELEASES_BASE_URL/1.6/hl-1.6.0-linux.tgz']);
        exec('tar', ['xvzf', 'hl-1.6.0-linux.tgz']);

        // workaround for "error while loading shared libraries: libhl.so cannot open shared object file: No such file or directory"
        Sys.putEnv("LD_LIBRARY_PATH", "hl-1.6.0-linux".fullPath());

        hlCommand = "hl-1.6.0-linux/hl";
        exec('chmod', ['u+x', hlCommand]);
      });
      return;
    }

    if(Os.isWindows) {
      foldOutput('hashlink-install', function() {

        var temp = getEnv("TEMP");

        run('curl', [ // https://stackoverflow.com/a/50200838/5116073
          "-sSLo", '$temp\\hl-1.12.0-win.zip',
          '$HL_GITHUB_RELEASES_BASE_URL/1.12/hl-1.12.0-win.zip'
        ]);

        run('tar', [ // https://superuser.com/a/1473255/1139467
          "-C", temp,
          "-xvf", '$temp\\hl-1.12.0-win.zip'
         ]);

        hlCommand = '$temp\\hl-1.12.0-win\\hl.exe';
      });
      return;
    }
    println('Don\'t know how to install matching HashLink version for Haxe $haxeVersion.');
  }

  public function buildAndRun(rest:Rest<String>) {
    build('hl', ['-hl', 'bin/hl/tests.hl'].concat(rest), function () {
      exec(hlCommand, ['bin/hl/tests.hl']);
    });
  }
}
