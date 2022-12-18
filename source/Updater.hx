#if !html5
package;

import lime.app.Application;
import sys.io.File;
import haxe.Http;

class Updater {
    static var version:String;
    public static function initVersionFile(){
        version = Application.current.meta.get('version');
		trace('version: ' + version);
		File.saveContent('version.txt', version);
    }
    public static function checkForUpdates(user:String,repo:String){
        // blah blah
    }
}
#end