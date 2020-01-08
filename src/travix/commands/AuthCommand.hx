package travix.commands;

import tink.Cli;
import tink.cli.*;
import haxe.remoting.*;
import haxe.crypto.*;
import sys.io.*;
import sys.*;
import travix.Os.*;

using StringTools;
using haxe.io.Path;
using tink.CoreApi;

/**
 *  Handy little tool for generating secure environment variables that stores haxelib credentials. To be used with the travix tool.
 */
class AuthCommand {

	/**
	 *  Haxelib username
	 */
	@:required
	public var username:String;

	/**
	 *  Haxelib password
	 */
	@:required
	public var password:String;

	/**
	 *  Github repo in the form of <owner>/<repo>. Example: back2dos/travix
	 */
	public var repo:String;

	/**
	 *  Don't add an entry to .travis.yml
	 */
	public var noadd:Bool;

	public function new() {}

	/** */
	@:defaultCommand @:skipFlags
	public function help() {
		Sys.println(Cli.getDoc(this));
	}

	/**
	 *  Encrypt haxelib credentials as travis secure environment variable
	 *  Usage: haxelib run travix_auth encrypt <haxelib_user> <haxelib_password> -r <owner>/<repo>
	 */
	@:command
	public function encrypt(prompt:Prompt):Promise<Noise> {

		if(repo == null) {
			var p = new Process('git', ['config', '--get', 'remote.origin.url']);
			switch p.exitCode() {
				case 0:
					var url = p.stdout.readAll().toString();
					if (url.startsWith('https://github.com/')) {
						var parts = url.split('/');
						var user = parts[3],
							project = parts[4].trim();

						if (project.endsWith('.git'))
						project = project.substr(0, project.length - 4);

						repo = '$user/$project';
						// prompt.println('Guessed repo: $repo');
					}
				default:
			}
		}

		var prompt:Promise<tink.Stringly> = if(repo == null) prompt.prompt('repo') else repo;
		return prompt.next(function(repo) {
			var cnx = HttpConnection.urlConnect('http://lib.haxe.org/api/3.0/index.n');

			// https://github.com/HaxeFoundation/haxelib/blob/302160b/src/haxelib/SiteApi.hx#L34
			if(cnx.resolve('api').resolve('checkPassword').call([username, Md5.encode(password)])) {
				switch which('travis') {
					case Success(path):
						var args = ['encrypt', 'HAXELIB_AUTH=$username:$password', '-r', repo];
						switch cmdOutput(path, args) {
							case Success(hash):
								if(noadd) Sys.println(hash);
								else {
									// add an entry in a not-so-robust way
									var yml = File.getContent('.travis.yml');
									var env = ~/^env:/;
									var secure = ~/secure:\s*.*/;
									var lines = yml.split('\n');
									var added = false;
									for(i in 0...lines.length) {
										if(env.match(lines[i])) {
											if(secure.match(lines[i + 1]))
												lines[i + 1] = secure.replace(lines[i + 1], 'secure: $hash');
											else
												lines.insert(i + 1, '  - secure: $hash');
											added = true;
											break;
										}
									}
									if(!added) lines.push('env:\n  - secure: $hash');
									File.saveContent('.travis.yml', lines.join('\n'));
									Sys.println('Added secure variable entry to .travis.yml');
								}
							case Failure(e):
								return Error.withData('Cannot encrypt variable', e.data);
						}
					case Failure(_):
						return new Error('travis not installed. Install Ruby and then run `gem install travis`');
				}

			} else {
				return new Error('Incorrect haxelib credentials');
			}

			return Noise;
		});
	}
}