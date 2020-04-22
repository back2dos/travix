package travix.commands;

import tink.cli.Rest;

/**
 * CI Helper for Haxe
 */
class RunCommand {

  public function new() {}

  /**
   * Show this help
   */
  @:defaultCommand
  public function help() {
    Sys.println(tink.Cli.getDoc(this, new tink.cli.doc.DefaultFormatter('travix run')));
  }

  /**
   * Build and run test on the cs target
   */
  @:command
  public function cs(rest:Rest<String>)
    new CsCommand().buildAndRun(rest);

  /**
   * Build and run test on the node target
   */
  @:command
  public function node(rest:Rest<String>)
    new NodeCommand().buildAndRun(rest);

  /**
   * Build and run test on the cpp target
   */
  @:command
  public function cpp(rest:Rest<String>)
    new CppCommand().buildAndRun(rest);

  #if !nodejs
  /**
   * Build and run test on the flash target
   */
  @:command
  public function flash(rest:Rest<String>)
    new FlashCommand().buildAndRun(rest);
  #end

  /**
   * Build and run test on the interp target
   */
  @:command
  public function interp(rest:Rest<String>)
    new InterpCommand().buildAndRun(rest);

  /**
   * Build and run test on the java target
   */
  @:command
  public function java(rest:Rest<String>)
    new JavaCommand().buildAndRun(rest);

  /**
   * Build and run test on the js target
   */
  @:command
  public function js(rest:Rest<String>)
    new JsCommand().buildAndRun(rest);

  /**
   * Build and run test on the lua target
   */
  @:command
  public function lua(rest:Rest<String>)
    new LuaCommand().buildAndRun(rest);

  /**
   * Build and run test on the neko target
   */
  @:command
  public function neko(rest:Rest<String>)
    new NekoCommand().buildAndRun(rest);

  /**
   * Build and run test on the php target
   */
  @:command
  public function php(rest:Rest<String>)
    new PhpCommand(false).buildAndRun(rest);

  /**
   * Build and run test on the php7 target
   */
  @:command
  public function php7(rest:Rest<String>)
    new PhpCommand(true).buildAndRun(rest);

  /**
   * Build and run test on the python target
   */
  @:command
  public function python(rest:Rest<String>)
    new PythonCommand().buildAndRun(rest);

  /**
   * Build and run test on the hl target
   */
  @:command
  public function hl(rest:Rest<String>)
    new HashLinkCommand().buildAndRun(rest);
}
