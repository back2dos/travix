package travix;

import sys.io.File;
using haxe.io.Path;

#if macro
import haxe.macro.MacroStringTools;
import haxe.macro.Context;
#end

class Macro {
	#if macro
	public static function loadFile(name:String) {
		return MacroStringTools.formatString(File.getContent(Context.getPosInfos((macro null).pos).file.directory() + '/$name'), Context.currentPos());
	}
	#end
}

