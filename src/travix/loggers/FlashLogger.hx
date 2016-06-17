package travix.loggers;

class FlashLogger {
  static var printBuf = new StringBuf();
  public static function print(s:String) {
    // print without newline is not supported on flash,
    // we try to emulate that by storing the text in a buffer and print them at a println call
    printBuf.add(s);
  }
  
  public static function println(s:String) {
    var pending = printBuf.toString();
    flash.Lib.trace(pending + s);
    if(pending.length > 0)
      printBuf = new StringBuf();
  }
  
  public static function exit(code:Int) {
    flash.system.System.exit(code);
  }
  
}