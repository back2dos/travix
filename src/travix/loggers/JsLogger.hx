package travix.loggers;

class JsLogger {
  public static function print(s:String) {
    switch untyped js.Browser.window.travixPrint {
      case null: js.Browser.console.log(s);
      case f: f(s);
    }
  }
  
  public static function println(s:String) {
    switch untyped js.Browser.window.travixPrintln {
      case null: js.Browser.console.log(s);
      case f: f(s);
    }
  }
  
  public static function exit(code:Int) {
    switch untyped js.Browser.window.travixExit {
      case null: // do nothing
      case f: f(code);
    }
  }
  
}