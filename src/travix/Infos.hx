package travix;


typedef Infos = { 
  name: String, 
  ?dependencies:haxe.DynamicAccess<String>,
  ?classPath:String,
  contributors:Array<String>,
  ?url:String,
  tags:Array<String>,
  license:String,
  version:String,
  releasenote:String,
}