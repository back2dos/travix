package travix;

using tink.CoreApi;
using StringTools;

typedef CommandResult = {
  final code:Int;
  final stdout:String;
  final stderr:String;
}

class Os {
  static public var isWindows(default, never):Bool = Sys.systemName() == 'Windows';
  static public function force<T>(o:Outcome<T, Error>)
    return switch o {
      case Success(v): v;
      case Failure(e):
        Sys.println(e.message);
        Sys.exit(e.code);
        throw 'unreachable';
    }
  /**
   * Attempts to run a command.
   * - results in failure if process creation fails
   * - otherwise results in success (even for non-zero exit codes)
   */
  static public function cmdResult(cmd:String, ?args:Array<String>):Outcome<CommandResult, Error>
    return try {
      #if (hxnodejs && !macro)
        var ret = js.node.ChildProcess.spawnSync(cmd, args);
        function str(buf:js.node.Buffer)
          return buf.toString();
        if (ret.status == 0)
          Success(str(ret.stderr) + str(ret.stdout));
        else
          Failure(ret.status, str(ret.stderr));
      #else
        var p = new sys.io.Process(cmd, args);
        Success({
          code: p.exitCode(),
          stdout: p.stdout.readAll().toString(),
          stderr: p.stderr.readAll().toString(),
        });
      #end
    }
    catch (e:Dynamic) {
      Failure(Error.withData(404, 'could not run `$cmd ${args.join(" ")}`', e));
    }

  /**
   * Runs a command and returns stdout if process successfully terminated with code 0.
   */
  static public function cmdOutput(cmd:String, args:Array<String>):Outcome<String, Error>
    return
      switch cmdResult(cmd, args) {
        case Success({ code: 0, stdout: v }): Success(v);
        case Success(d = { code: code, stderr: v }):
          Failure(Error.withData(code, 'The command `$cmd ${args.join(" ")}` exited with code $code', d));
        case Failure(e): Failure(e);
      }

  static public function which(cmd:String) {
		return cmdOutput(isWindows ? 'where' : 'which', [cmd])
			.map(function(path) return path.replace('\r\n', '\n').split('\n')[0]);
  }
}