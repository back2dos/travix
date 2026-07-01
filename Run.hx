class Run {
	static function main() {
		Sys.command('haxe -lib tink_cli -lib hx3compat -cp src --run travix.Travix ${Sys.args().map(v -> '"$v"').join(' ')}');
	}
}
