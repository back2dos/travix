package travix.commands;

import tink.cli.Rest;

using sys.FileSystem;

class JvmCommand extends Command {
	public function install() {}

	public function buildAndRun(rest:Rest<String>) {
		final main = Travix.getMainClassLocalName();

		installLib('hxjava');

		final outputFile = main + (isDebugBuild(rest) ? '-Debug' : '');
		build('jvm', ['--jvm', 'bin/jvm/$outputFile.jar'].concat(rest), () -> exec('java', ['-jar', 'bin/jvm/$outputFile.jar']));
	}
}
