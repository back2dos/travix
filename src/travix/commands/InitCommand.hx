package travix.commands;

import haxe.Json;
import sys.io.*;
import Sys.*;
import tink.cli.Prompt;
import travix.Travix;
import travix.Macro;

using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using sys.io.File;

class InitCommand extends Command {
  static inline var PROFILE = 'https://travis-ci.org/profile/';
  static inline var DEFAULT_PLATFORMS = 'interp, neko, node, python, java';
  static inline var ALL = 'interp,neko,python,node,js,flash,java,cpp,cs,php,php7,lua';

  static inline var GITHUB_ACTIONS_CONFIG = '.github/workflows/build.yml';
  static inline var TRAVIS_CONFIG = '.travis.yml';
  static inline var TESTS = @:privateAccess Travix.TESTS;
  static inline var HAXELIB_CONFIG = @:privateAccess Travix.HAXELIB_CONFIG;

  var ci:String;

  @:defaultCommand
  public function doIt(prompt:Prompt) {
    prompt.prompt(MultipleChoices('Which CI?', ['github-actions', 'travis'])).handle(function(o) switch o {
      case Success(result): ci = result;
      case Failure(e): println(e); exit(1);
    });

    var source = Unknown;
    switch tryToRun('git', ['config', '--get', 'remote.origin.url']) {
      case Success(url):
        if (url.startsWith('https://github.com/')) {
          var parts = url.split('/');
          var user = parts[3],
              project = parts[4].trim();

          if (project.endsWith('.git'))
            project = project.substr(0, project.length - 4);

          source = GitHub(user, project);
        }
        else {
          println('Git remote found, but does not seem to be on GitHub. Assuming plain Git');
          source = Git(url);
        }
      case Failure(_, ''):
        println('Project doesn\'t seem to be a git repo');
      case Failure(404, _):
        println('No git installed. Cannot guess remote url.');
      case Failure(_, msg):
        println('Error while running git: $msg');
    }

    makeYml();
    makeJson(source);

    if (!TESTS.exists()) {
      println('no $TESTS found');

      var cp = enter('class path for tests', 'tests');
      var main = 'RunTests';

      for (m in 'Run,Main'.split(','))
        if ('$cp/$m.hx'.exists()) {
          main = m;
          break;
        }

      main = enter('test entry point', main);

      TESTS.saveContent([
        '-cp $cp',
        '-main $main',
        '-dce full',
      ].join('\n'));

      {
        var mainFile = cp + '/' + main.replace('.', '/') + '.hx';

        if (!mainFile.exists()) {
          println('Generating entrypoint in $mainFile');
          try {
            ensureDir(mainFile.normalize());

            var pack = main.split('.');
            var name = pack.pop();

            mainFile.saveContent(defaultEntryPoint());
          }
          catch (e:Dynamic) {
            println('Failed to generate entrypoint because $e');
          }
        }
      }

      var profile = PROFILE;

      switch source {
        case GitHub(user, _):
          profile += user;
        default:
      }

      if (ask('Activate CI for this project now', true))
        switch systemName() {
          case 'Windows':
            exec('start', [profile]);
          case 'Linux':
            exec('xdg-open', [profile]);
          case 'Mac':
            exec('open', [profile]);
          default:
            println('Unknown OS. Please go to $profile');
        }
    }
  }


  function makeYml() {
    var configFile = ci == "github-actions" ? GITHUB_ACTIONS_CONFIG : TRAVIS_CONFIG;

    if (configFile.exists() && !ask('The $configFile is already present. Do you wish to replace it with a new one', false)) return;

    var platforms = [for (p in enter('platforms as a comma-separated list or `all`', DEFAULT_PLATFORMS).split(','))
        switch p.trim() {
          case '': continue;
          case v: v;
        }
    ];

    if (platforms.remove('all'))
      platforms = ALL.split(',');

    if (!configFile.directory().exists())
      configFile.directory().createDirectory();

    configFile.saveContent(ci == "github-actions" ? defaultGithubActionsFile() : defaultTravisFile());
  }

  function makeJson(source:ProjectSource) {
    if (HAXELIB_CONFIG.exists()) return;

    function defaultClassPath() {
      for (option in 'src,hx'.split(','))
        if (option.exists()) return '$option';
      return '.';
    }

    var infos:Infos = {
      name: enter('library name', Sys.getCwd().removeTrailingSlashes().withoutDirectory()),
      classPath: enter('classpath', defaultClassPath()),
      dependencies: { },
      contributors: [enter('User name', switch source {
        case GitHub(user, _): user;
        default: null;
      })],
      tags: [for (t in enter('Tags (comma separated)', '').split(','))
        switch t.trim() {
          case '': continue;
          case v: v;
        }
      ],
      version: '0.0.0',
      license: 'MIT',
      releasenote: 'initial release',
    }

    switch source {
      case GitHub(u, p):
        infos.url = 'https://github.com/$u/$p/';
      default:
    }

    HAXELIB_CONFIG.saveContent(Json.stringify(infos, '  '));
  }

  macro static function defaultGithubActionsFile() {
    return Macro.loadFile('default_github_actions.yml');
  }
  macro static function defaultTravisFile() {
    return Macro.loadFile('default_travis.yml');
  }
  macro static function defaultEntryPoint() {
    return Macro.loadFile('default.hx');
  }
}


enum ProjectSource {
  Unknown;
  GitHub(user:String, project:String);
  Git(url:String);
}
