package;

#if !html5
import lime.app.Application;
import sys.io.File;
import sys.FileSystem;
import haxe.Http;
import openfl.net.URLLoader as UrlLoader;
import openfl.net.URLLoaderDataFormat;
import openfl.net.URLStream as UrlStream;
import openfl.net.URLRequest as UrlRequest;
import openfl.utils.ByteArray;
import openfl.events.*;
import sys.io.FileOutput;
#end

using StringTools;

class FileType {
	public static var REMOVE(default, never):Int = 0;
	public static var ADD(default, never):Int = 1;
	public static var CHANGE(default, never):Int = 2;
}

typedef FileMetadata = {
	var type:Int;
	var path:String;
}

#if !html5
class Updater {
	static var version:String;
	public static var githubVersion:String;
	public static var githubRequest:String;

	public static function initVersionFile() {
		version = Application.current.meta.get('version');
		trace('version: ' + version);
		File.saveContent('version.txt', version);
		Sys.command('del tmp.bat');
	}

	public static function checkForUpdates(user:String, repo:String, branch:String = 'main', ?callback:Dynamic) {
		githubRequest = 'https://raw.githubusercontent.com/$user/$repo/$branch';
		var toRequest:String = '$githubRequest/version.txt';
		trace(toRequest);
		githubVersion = Http.requestUrl(toRequest).split('\n')[0];
		trace('githubVersion: ' + githubVersion);
		if (version != githubVersion) {
			trace('update available!!');
			if (callback != null)
				callback();
		}
	}

	public static function update() {
		var files:Array<String> = Http.requestUrl('$githubRequest/_latest/changes').split('\n');
		files.splice(files.length - 1, 1); // to remove the blanks at the end
		var exeFile:String = Application.current.meta.get('file') + '.exe';
		trace('exeFile: ' + exeFile);
		trace(files);
		for (f in files) {
			var file:FileMetadata = ChangeParser.parse(f);
			trace(file);
			var fileData:String = null;
			switch (file.type) {
				case FileType.ADD:
					if (!FileSystem.exists(file.path)) {
						if (StringTools.contains(file.path, '.')) {
							saveFile(file);
						} else {
							trace('creating folder: ' + file.path);
							FileSystem.createDirectory(file.path);
						}
					}

				case FileType.REMOVE:
					if (FileSystem.exists(file.path)) {
						if (StringTools.contains(file.path, '.')) {
							trace('removing file: ' + file.path);
							FileSystem.deleteFile(file.path);
						} else {
							trace('removing folder: ' + file.path);
							recursivelyDelete(file.path);
						}
					}

				case FileType.CHANGE:
					if (file.path != exeFile) {
						saveFile(file);
					} else {
						trace('updating exe');
						File.saveContent('tmp.bat', '
                        @echo off
						taskkill /f /im $exeFile
						timeout 1
                        del $exeFile
						timeout 1
                        ren tmp.exe $exeFile
                        start $exeFile');
						saveFile(file, 'tmp.exe', function(data) {
							Sys.command('start tmp.bat');
						});
					}
			}
		}
	}

	private static function recursivelyDelete(path:String) {
		var files:Array<String> = FileSystem.readDirectory(path);
		for (f in files) {
			var filePath:String = path + '/' + f;
			if (FileSystem.isDirectory(filePath)) {
				recursivelyDelete(filePath);
			} else {
				trace('removing file: ' + filePath);
				FileSystem.deleteFile(filePath);
			}
		}
		FileSystem.deleteDirectory(path);
	}

	private static function saveFile(file:FileMetadata, ?forcePath:String, ?callback:Dynamic) {
		var downloadStream:UrlLoader = new UrlLoader();
		downloadStream.dataFormat = BINARY;
		var request = new UrlRequest('$githubRequest/${file.path}'.replace(' ', '%20'));
		downloadStream.addEventListener(Event.COMPLETE, function(e) {
			trace('alright we fetched it');

			var fileFolderArray:Array<String> = file.path.split('/');
			fileFolderArray.pop();
			var fileFolder:String = fileFolderArray.join('/');
			trace('fileFolder: ' + fileFolder);
			if (!FileSystem.exists(fileFolder)) {
				trace('creating folder: ' + fileFolder);
				FileSystem.createDirectory(fileFolder);
			}
			if (forcePath != null) {
				file.path = forcePath;
			}
			trace('saving file: ' + file.path);
			var fileOutput:FileOutput = File.write(file.path, true);

			var data:ByteArray = new ByteArray();
			downloadStream.data.readBytes(data, 0, downloadStream.data.length - downloadStream.data.position);
			fileOutput.writeBytes(data, 0, data.length);
			fileOutput.flush();

			fileOutput.close();

			if (callback != null) {
				callback(downloadStream.data);
			}
		});
		downloadStream.load(request);
	}
}
#else
class Updater {
	public static function initVersionFile() {}

	public static function checkForUpdates(user:String, repo:String, branch:String = 'main', ?callback:Dynamic) {}

	public static function update() {}

	private static function recursivelyDelete(path:String) {}

	private static function saveFile(file:FileMetadata) {}
}
#end

private class ChangeParser {
	public static function parse(file:String):FileMetadata {
		var queue:String = '';
		var toReturn:FileMetadata = {type: FileType.REMOVE, path: ''};
		var hasAddedType:Bool = false;
		for (i in 0...file.length) {
			queue += file.charAt(i);
			switch (queue.split(' ')[0]) {
				case 'CHANGE':
					toReturn.type = FileType.CHANGE;
					hasAddedType = true;
					toReturn.path = file.replace('CHANGE ', '');

				case 'ADD':
					toReturn.type = FileType.ADD;
					hasAddedType = true;
					toReturn.path = file.replace('ADD ', '');

				case 'REMOVE':
					hasAddedType = true;
					toReturn.path = file.replace('REMOVE ', '');
			}
		}
		return toReturn;
	}
}
