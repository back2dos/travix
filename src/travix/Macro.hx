package travix;

import sys.io.File;
using haxe.io.Path;

#if macro
import haxe.macro.MacroStringTools;
import haxe.macro.Context;
import haxe.macro.Compiler;
#end

class Macro {
	#if macro
	public static function shebang() {
		Context.onAfterGenerate(function() {
			var out = Compiler.getOutput();
			File.saveContent(out, '#!/usr/bin/env node\n\n' + File.getContent(out));
		});
	}

	public static function loadFile(name:String) {
		return MacroStringTools.formatString(File.getContent(Context.getPosInfos((macro null).pos).file.directory() + '/$name'), Context.currentPos());
	}

	static function setup() {
		if (Context.defined('js') && !Context.defined('nodejs'))
			Compiler.addGlobalMetadata("js.Boot.HaxeError", '@:expose("HaxeError")');
	}
	#end
}

