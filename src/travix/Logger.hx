package travix;

import travix.loggers.*;

// wrap the underlying implemention, to expose only the required methods
class Logger {
  
  public static inline function print(s:String)
    LoggerImpl.print(s);

  public static inline function println(s:String)
    LoggerImpl.println(s);

  public static inline function exit(code:Int)
    LoggerImpl.exit(code);

}

private typedef LoggerImpl = 
  #if flash
    FlashLogger;
  #elseif (js && !nodejs)
    JsLogger;
  #else
    Sys;
  #end
