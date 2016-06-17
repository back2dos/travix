package travix.loggers;

class JsLogger {
  
  static var callPhantom:Dynamic = untyped js.Browser.window.callPhantom;
  
  public static function print(s:String) {
    callPhantom({
     cmd: 'travix:print',
     message: s,
   });
  }
  
  public static function println(s:String) {
    callPhantom({
     cmd: 'travix:println',
     message: s,
   });
  }
  
  public static function exit(code:Int) {
    callPhantom({
     cmd: 'travix:exit',
     exitCode: 0,
   });
  }
  
}