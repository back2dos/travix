package travix.commands;

import tink.cli.Rest;

import Sys.*;

class LuaCommand extends Command {
  
  public function install() {
    if(command('eval', ['which luarocks >/dev/null']) != 0) {
      foldOutput('lua-install', function() {
        if(Travix.isLinux) {
          if(command('eval', ['bash -c "[ \\"`lsb_release -s -c`\\" == \\"precise\\" ]"']) == 0) {
            // Required repo for precise to build cmake
            exec('eval', ['sudo add-apt-repository -y ppa:george-edison55/precise-backports']);
          }

          installPackages([
            "cmake",
            "libpcre3",
            "libpcre3-dev",
            "lua5.2",
            "make",
            "unzip"
          ]);

          var luaRocksVersion = '2.4.3';

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
        } else if(Travix.isMac) {
          installPackage('lua');
          installPackage('luarocks');
        }
      });
    }

    // Install lua libraries
    exec('sudo', 'luarocks install haxe-deps'.split(' '));

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
