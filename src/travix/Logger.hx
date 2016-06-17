package travix;

import travix.loggers.*;

class Logger {
  static var logger = 
    #if flash
      FlashLogger;
    #elseif (js && !nodejs)
      JsLogger;
    #else
      Sys;
    #end
  
  public static inline function print(s:String)
    logger.print(s);

  public static inline function println(s:String)
    logger.println(s);

  public static inline function exit(code:Int)
    logger.exit(code);

}