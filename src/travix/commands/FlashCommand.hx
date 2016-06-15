package travix.commands;

import Sys.*;

class FlashCommand extends Command {
  
  override function execute() {
    var homePath = Travix.isLinux ? "$HOME" : null;

    if(homePath == null) {
      build(['-swf', 'bin/swf/tests.swf'], function () {});
      return;
    }    

    var flashPath = '$homePath/.macromedia/Flash_Player';

    foldOutput('flash-install', function() {
      // Some xvfb settings
      exec('export', ['DISPLAY=:99.0']);
      exec('export', ['AUDIODEV=null']);

      // Create a configuration file so the trace log is enabled
      exec('eval', ['echo "ErrorReportingEnable=1\\nTraceOutputFileEnable=1" > "$homePath/mm.cfg"']);

      // Add the current directory as trusted, so exit can be used.
      exec('eval', ['mkdir -m 777 -p "$flashPath/#Security/FlashPlayerTrust"']);
      exec('eval', ['echo "`pwd`" > "$flashPath/#Security/FlashPlayerTrust/travix.cfg"']);

      exec('eval', ['mkdir -m 777 -p "$flashPath/Logs"']);
      exec('eval', ['rm -f "$flashPath/Logs/flashlog.txt"']);
      exec('eval', ['touch "$flashPath/Logs/flashlog.txt"']);

      // Download and unzip the player, unless it exists already
      if(command("eval", ['test -f "$flashPath/flashplayerdebugger"']) != 0) {
        exec('wget', ['-nv', 'http://fpdownload.macromedia.com/pub/flashplayer/updaters/11/flashplayer_11_sa_debug.i386.tar.gz']);
        exec('eval', ['tar -C "$flashPath" -xf flashplayer_11_sa_debug.i386.tar.gz --wildcards "flashplayerdebugger"']);
        exec('rm', ['-f', 'flashplayer_11_sa_debug.i386.tar.gz']);

        // Installing 386 packages on Travis/trusty is a mess.
        if(Travix.isTravis) {
          exec('eval', ['wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -']);
          exec('eval', ['sudo sed -i -e \'s/deb http/deb [arch=amd64] http/\' "/etc/apt/sources.list.d/google-chrome.list" "/opt/google/chrome/cron/google-chrome"']);
          exec('sudo', ['dpkg', '--add-architecture', 'i386']);
          exec('sudo', ['apt-get', 'update']);
        }

        // Required flash libs
        var packages = ["libcurl3:i386","libglib2.0-0:i386","libx11-6:i386", "libxext6:i386","libxt6:i386",
          "libxcursor1:i386","libnss3:i386", "libgtk2.0-0:i386"];

        for(pack in packages) aptGet(pack);

      }
      
      // Tail the logfile. Must use eval to start tail in background, to see the output.
      exec('eval', ['tail -f --follow=name --retry "$flashPath/Logs/flashlog.txt" &']);
    });


    build(['-swf', 'bin/swf/tests.swf', '-D', 'flash-exit'], function () {
      // The flash player has some issues with unexplained crashes,
      // but if it runs about 7 times, it should succeed one of those.
      var ok = false;
      for(i in 1 ... 8) {
        if(command('eval', ['xvfb-run "$flashPath/flashplayerdebugger" bin/swf/tests.swf']) == 0) {
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