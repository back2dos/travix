package travix.commands;

import tink.cli.Rest;

using sys.FileSystem;

class JvmCommand extends Command {
	public function install() {}

	public function buildAndRun(rest:Rest<String>) {
		var main = Travix.getMainClassLocalName();

		installLib('hxjava');

		build('jvm', ['--jvm', 'bin/jvm'].concat(rest), function() {
			var outputFile = main + (isDebugBuild(rest) ? '-Debug' : '');
			exec('java', ['-jar', 'bin/jvm/$outputFile.jar']);
		});
	}
}
