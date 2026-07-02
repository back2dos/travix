package travix;

using sys.FileSystem;

class PostDownload {

  static function main() 
    if (!'run.n'.exists()) 
      Sys.exit(Sys.command('lix download && haxe build-neko.hxml'));
}