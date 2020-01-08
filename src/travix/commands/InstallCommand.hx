package travix.commands;

import travix.*;

/**
 * CI Helper for Haxe
 */
class InstallCommand extends Command {

	static inline var TESTS = @:privateAccess Travix.TESTS;

  /**
   * Install haxelib dependencies
   */
  @:defaultCommand
  public function dependencies() {

    switch Travix.getInfos() {
      case None:
        Travix.die('$TESTS not found');

      case Some(info):
        run('haxelib', ['dev', info.name, '.']);

        switch info.dependencies {
        case null:
        case v:
          for (lib in v.keys())
          installLib(lib, v[lib]);
        }
        run('haxelib', ['install', TESTS, '--always']);

        exec('haxelib', ['list']);
    }
  }

  /**
   * Show this help
   */
  @:command
  public function help()
    Sys.println(tink.Cli.getDoc(this, new tink.cli.doc.DefaultFormatter('travix install')));

  /**
   * Install dependencies for the cs target
   */
  @:command
  public function cs()
    new CsCommand().install();

  /**
   * Install dependencies for the node target
   */
  @:command
  public function node()
    new NodeCommand().install();

  /**
   * Install dependencies for the cpp target
   */
  @:command
  public function cpp()
    new CppCommand().install();

  #if !nodejs
  /**
   * Install dependencies for the flash target
   */
  @:command
  public function flash()
    new FlashCommand().install();
  #end

  /**
   * Install dependencies for the interp target
   */
  @:command
  public function interp()
    new InterpCommand().install();

  /**
   * Install dependencies for the java target
   */
  @:command
  public function java()
    new JavaCommand().install();

  /**
   * Install dependencies for the js target
   */
  @:command
  public function js()
    new JsCommand().install();

  /**
   * Install dependencies for the lua target
   */
  @:command
  public function lua()
    new LuaCommand().install();

  /**
   * Install dependencies for the neko target
   */
  @:command
  public function neko()
    new NekoCommand().install();

  /**
   * Install dependencies for the php target
   */
  @:command
  public function php()
    new PhpCommand(false).install();

  /**
   * Install dependencies for the php7 target
   */
  @:command
  public function php7()
    new PhpCommand(true).install();

  /**
   * Install dependencies for the python target
   */
  @:command
  public function python()
    new PythonCommand().install();

  /**
   * Install dependencies for the hl target
   */
  @:command
  public function hl()
    new HashLinkCommand().install();
}