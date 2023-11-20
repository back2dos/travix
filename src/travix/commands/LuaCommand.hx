package travix.commands;

import tink.cli.Rest;

import Sys.*;

using StringTools;

class LuaCommand extends Command {

  public function install() {
    if(Travix.isTravis || Travix.isGithubActions) { // if(command('eval', ['which luarocks >/dev/null']) != 0) {
      if(Os.isLinux) {
        var lsb = switch tryToRun('lsb_release', ['-s', '-c']) {
          case Success(output): output.trim();
          case Failure(_): null;
        }

        Sys.println('lsb: $lsb');

        switch lsb {
          case 'precise':
            // Required repo for precise to build cmake
            exec('eval', ['sudo add-apt-repository -y ppa:george-edison55/precise-backports']);
          case 'trusty':
            // Required repo for trusty to build cmake
            Sys.println('preparing for trusty');
            installPackage('software-properties-common');
            exec('eval', ['sudo add-apt-repository -y ppa:george-edison55/cmake-3.x']);
            exec('eval', ['sudo apt-get update']);
        }

        installPackages([
          "cmake",
          "libpcre3",
          "libpcre3-dev",
          "lua5.2",
          "make",
          "unzip"
        ]);

        foldOutput('luarocks-install', function() {
          var luaRocksVersion = '3.8.0';

          // Add source files so luarocks can be compiled
          exec('sudo', ['mkdir', '-p', '/usr/include/lua/5.2']);
          exec('wget', ['-q', 'http://www.lua.org/ftp/lua-5.2.0.tar.gz']);
          exec('tar', ['xf', 'lua-5.2.0.tar.gz']);
          exec('eval', ['sudo cp lua-5.2.0/src/* /usr/include/lua/5.2']);
          exec('rm', ['-rf', 'lua-5.2.0']);
          exec('rm', ['-f', 'lua-5.2.0.tar.gz']);

          // Compile luarocks
          exec('wget', ['-q', 'http://luarocks.org/releases/luarocks-$luaRocksVersion.tar.gz']);
          exec('tar', ['zxpf', 'luarocks-$luaRocksVersion.tar.gz']);

          withCwd('luarocks-$luaRocksVersion', function() {
            exec('./configure');
            exec('eval', ['make build >/dev/null']);
            exec('eval', ['sudo make install >/dev/null']);
          });

          exec('rm', ['-f', 'luarocks-$luaRocksVersion.tar.gz']);
          exec('rm', ['-rf', 'luarocks-$luaRocksVersion']);
        });

      } else if(Os.isMac) {
        installPackage('lua');
        installPackage('luarocks');
      }
    }

    // Install lua libraries
    exec('sudo', 'luarocks install pcre2 haxe-deps'.split(' '));
    exec('eval', ['sudo luarocks install environ 0.1.0-1']); // for haxe 3

    // print the effective versions
    exec("luarocks", ['--version']);
    exec("lua", ['-v']);
  }

  public function buildAndRun(rest:Rest<String>) {
    build('lua', ['-lua', 'bin/lua/tests.lua'].concat(rest), function () {
      exec('lua', ['bin/lua/tests.lua']);
    });
  }
}
