package travix.commands;

import haxe.zip.*;
import haxe.io.*;
import sys.io.*;
import tink.cli.*;

using StringTools;
using haxe.Json;
using sys.io.File;
using sys.FileSystem;

class ReleaseCommand {
	
	static var README = 'README.md';
	static var EXTRAS = 'extraParams.hxml';
	static var INFO = 'haxelib.json';
	static var PRERELEASE = 'prerelease.hxml';
	static var RUN = 'run.n';
  
  public function new() {}
	
  @:defaultCommand
	public function doIt(args:Rest<String>) {
		var version = args[0];
		if(version == null) {
			var p = new Process('git', ['describe', '--exact-match', '--tags']);
			switch p.exitCode() {
				case 0: version = p.stdout.readAll().toString().trim();
				case _: error('Please specify version. e.g. "haxelib run travix release 1.0.0"');
			}
		}
		
		var info:HaxelibInfo = INFO.getContent().parse();
		info.version = version;
		
		
		if(PRERELEASE.exists()) {
			Sys.println('== Compiling $PRERELEASE');
			switch Sys.command('haxe', [PRERELEASE]) {
				case 0: // ok
				case v: error('Error compiling $PRERELEASE');
			}
		}
		
		Sys.println('== Preparing bundle');
		INFO.saveContent(info.stringify('  '));
		var bundle = 'bundle.zip';
		
		if (bundle.exists()) bundle.deleteFile();
		
		var files = 
			try info.travix.release.files // Too lazy to do null checks...
			catch(e:Dynamic) null;
			
		if(files == null) {
			files = [INFO, README, info.classPath];
			if(EXTRAS.exists()) files.push(EXTRAS);
			if(RUN.exists()) files.push(RUN);
		}
			
		var a = new Archive();
		for(f in files) a.add(f);
		bundle.saveBytes(a.getAll());
		
		switch Sys.getEnv('HAXELIB_AUTH') {
			case null:
				error('Haxelib credentials missing. Use travix_auth to set it up.');
				
			case v:
				var i = v.indexOf(':');
				if(i == -1) error('Incorrect format for the haxelib credentials. Use travix_auth to set it up.');
				var user = v.substr(0, i);
				var pass = v.substr(i + 1);
				Sys.println('== Submitting haxelib');
				var proc = new Process('haxelib', ['submit', bundle]);
				if(info.contributors.length > 1)
					proc.stdin.writeString('$user\n');
				proc.stdin.writeString('$pass\n');
				proc.stdin.writeString('y\n'); // overwrite if version already exists
				Sys.println((proc.exitCode() == 0 ? proc.stdout : proc.stderr).readAll().toString());
				Sys.println('== Cleanup');
				bundle.deleteFile();
				Sys.println('== Done');
		}
		
	}
	
	static function error(msg:String) {
		Sys.println(msg);
		Sys.exit(1);
	}
}

typedef HaxelibInfo = {
	classPath:String,
	contributors:Array<String>,
	version:String,
	travix:{
		release: {
			files:Array<String>
		}
	}
}

abstract Archive(List<Entry>) {
	public function new() 
		this = new List();
		
	public function add(path:String) 
		if(path.exists()) {
			if (path.isDirectory()) 
				for (file in path.readDirectory()) 
					add('$path/$file');
			else {
				var blob = path.getBytes();
				this.push({
					fileName: path,
					fileSize : blob.length,
					fileTime : path.stat().mtime,
					compressed : false,
					dataSize : blob.length,
					data : blob,
					crc32: null,//TODO: consider calculating this one
				});
			}			
		}
	
	public function getAll():Bytes {
		var o = new BytesOutput();
		write(o);
		return o.getBytes();
	}
	
	public function write(o:Output) {
		var w = new Writer(o);
		w.write(this);
	}
}