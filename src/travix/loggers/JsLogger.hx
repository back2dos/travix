package travix.loggers;

class JsLogger {
  public static function print(s:String) {
    untyped js.Browser.window.travixPrint(s);
  }
  
  public static function println(s:String) {
    untyped js.Browser.window.travixPrintln(s);
  }
  
  public static function exit(code:Int) {
    untyped js.Browser.window.travixExit(code);
  }
  
}