class Run {
	static function main() {
		final code = Sys.command('haxe -lib tink_cli -lib hx3compat -cp src -D no-deprecation-warnings --run travix.Travix ${Sys.args().map(v -> '"$v"').join(' ')}');
		Sys.exit(code);
	}
}
