package travix.loggers;

class JsLogger {
  
  static var callPhantom = untyped js.Browser.window.callPhantom;
  
  static function print(s:String) {
    callPhantom({
     cmd: 'travix:print',
     message: s,
   });
  }
  
  static function println(s:String) {
    callPhantom({
     cmd: 'travix:println',
     message: s,
   });
  }
  
  static function exit(code:Int) {
    callPhantom({
     cmd: 'travix:exit',
     exitCode: 0,
   });
  }
  
}