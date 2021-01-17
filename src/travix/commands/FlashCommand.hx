package travix.commands;

import tink.cli.Rest;
import Sys.*;

class FlashCommand extends Command {

  static var homePath = "$HOME";
  static var flashPath = '$homePath/.macromedia/Flash_Player';

  static function getLatestFPVersion():Array<Int> {
    var appcast = Xml.parse(haxe.Http.requestUrl("http://fpdownload2.macromedia.com/get/flashplayer/update/current/xml/version_en_mac_pep.xml"));
    var update = [for (update in appcast.firstElement().elementsNamed("update")) update][0];
    var versionStr = update.get("version");
    return versionStr.split(",").map(Std.parseInt);
  }

  public function install() {

    if(!Os.isLinux) {
      println('Don\'t know how to install Flash on ' + systemName());
      return;
    }

    foldOutput('flash-install', function() {
      // Some xvfb settings
      exec('export', ['AUDIODEV=null']);

      // Create a configuration file so the trace log is enabled
      exec('eval', ['echo "ErrorReportingEnable=1\\nTraceOutputFileEnable=1" > "$homePath/mm.cfg"']);

      // Add the current directory as trusted, so exit can be used.
      exec('eval', ['mkdir -m 777 -p "$flashPath/#Security/FlashPlayerTrust"']);
      exec('eval', ['echo "`pwd`" > "$flashPath/#Security/FlashPlayerTrust/travix.cfg"']);

      exec('eval', ['mkdir -m 777 -p "$flashPath/Logs"']);
      exec('eval', ['rm -f "$flashPath/Logs/flashlog.txt"']);
      exec('eval', ['touch "$flashPath/Logs/flashlog.txt"']);

      // Download and unpack the player, unless it exists already
      if (command("eval", ['test -f "$flashPath/flashplayerdebugger"']) != 0) {
        var flashPlayerVersion = getLatestFPVersion()[0];
        exec('eval', ['wget -nv -O flash_player_sa_linux.tar.gz https://fpdownload.macromedia.com/pub/flashplayer/updaters/$flashPlayerVersion/flash_player_sa_linux_debug.x86_64.tar.gz']);
        exec('eval', ['tar -C "$flashPath" -xf flash_player_sa_linux.tar.gz --wildcards "flashplayerdebugger"']);
        exec('eval', ['rm -f flash_player_sa_linux.tar.gz']);

        // Required flash libs
        installPackages([
          "libcurl3",
          "libglib2.0-0",
          "libgtk2.0-0",
          "libnss3",
          "libx11-6",
          "libxcursor1",
          "libxext6",
          "libxt6",
          "xvfb"
        ]);
      }

      // Tail the logfile. Must use eval to start tail in background, to see the output.
      exec('eval', ['tail -f --follow=name --retry "$flashPath/Logs/flashlog.txt" &']);
    });


  }

  public function buildAndRun(rest:Rest<String>) {
    if(!Os.isLinux) {
      println('Don\'t know how to run Flash on ' + systemName());
      return;
    }

    build('flash', ['-swf', 'bin/swf/tests.swf', '-D', 'flash-exit'].concat(rest), function () {
      // The flash player has some issues with unexplained crashes,
      // but if it runs about 7 times, it should succeed one of those.
      var ok = false;
      for(i in 1 ... 8) {
        if(command('eval', ['xvfb-run -e /dev/null -a --server-args="-ac -screen 0 1024x768x24 +extension RANDR" "$flashPath/flashplayerdebugger" bin/swf/tests.swf']) == 0) {
          ok = true; break;
        }
      }

      // Kill the tail process
      exec('eval', ["ps aux | grep -ie [L]ogs/flashlog.txt | awk '{print $2}' | xargs kill -9"]);

      if(!ok) {
        // Testing didn't complete, so xvfb may have crashed even though tests are passing.
        // Special solution for Buddy: As a final measure, check flashlog.txt if tests passed.
        if(command('eval', ['grep -E "^[0-9]+ specs, 0 failures, [0-9]+ pending$$" "$flashPath/Logs/flashlog.txt"']) != 0) {
          println('Flash execution failed too many times, build failure.');
          exit(1);
        }
      }
    });
  }
}
