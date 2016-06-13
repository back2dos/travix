package ${pack.join('.')};

class $name {

  static function main() {
    trace('it works');
    #if flash
      flash.system.System.exit(0);//Don't forget to exit on flash!
    #end
    
    #if (travix && js)
      // travix run js tests in phantomjs, so we need to exit properly
      var callPhantom = untyped js.Browser.window.callPhantom;
      callPhantom({
        cmd: 'travix:exit',
        exitCode: 0,
      });
    #end
  }
  
}