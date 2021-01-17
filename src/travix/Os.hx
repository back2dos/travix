package travix;

using tink.CoreApi;
using StringTools;
using haxe.io.Path;

typedef CommandResult = {
  var code(default, null):Int;
  var stdout(default, null):String;
  var stderr(default, null):String;
}

class Os {
  public static var isLinux(default, never) = Sys.systemName() == 'Linux';
  public static var isMac(default, never) = Sys.systemName() == 'Mac';
  public static var isWindows(default, never) = Sys.systemName() == 'Windows';

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
        Success({
          code: ret.status,
          stdout: str(ret.stdout),
          stderr: str(ret.stderr),
        });
      #else
        var p = new sys.io.Process(cmd, args);

        function str(buf:haxe.io.Input)
          return buf.readAll().toString();

        Success({
          code: p.exitCode(),
          stdout: str(p.stdout),
          stderr: str(p.stderr),
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

  static public function which(cmd:String):Outcome<String, Error> {
    return switch cmdOutput(isWindows ? 'where' : 'which', [cmd]) {
      case Failure(e): Failure(e);
      case Success(out) if (isWindows):
        var ret = Failure(new Error(404, 'could not find $cmd'));
        for (l in out.split('\n'))
          switch l.trim() {
            case _.extension() => null | '':
            case v:
              ret = Success(v);
              break;
          }
        ret;
      case Success(out): Success(out.split('\n')[0]);
    }
  }
}