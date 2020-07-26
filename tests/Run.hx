package;

import tink.testrunner.*;
import tink.unit.*;

#if (js && !nodejs)
import js.Browser.*;
#end

@:asserts
class Run {
  static function main() {
    Runner.run(TestBatch.make([
      new Run(),
    ])).handle(Runner.exit);
  }
  
  function new() {}
  
  #if (sys || nodejs)
  public function sys() {
    asserts.assert(Sys.getCwd() != null);
    return asserts.done();
  }
  #end
  
  #if (js && !nodejs)
  public function js() {
    asserts.assert(navigator.userAgent != null);
    return asserts.done();
  }
  #end
  
  
  #if flash
  public function flash() {
    trace('Flash trace should work as usual');
    asserts.assert(true);
    return asserts.done();
  }
  #end
  
  #if lua
  public function setEnv() {
    Sys.putEnv('TRAVIX_LUA', 'true');
    asserts.assert(Sys.getEnv('TRAVIX_LUA') == 'true', 'Make sure environ is installed');
    return asserts.done();
  }
  #end
}