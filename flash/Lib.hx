package flash;


import flash.display.BitmapData;
import flash.display.MovieClip;
import flash.display.Stage;
import flash.net.URLRequest;
import flash.Lib;
import haxe.Timer;
import openfl.display.ManagedStage;
import sys.io.Process;


class Lib {
	
	
	static public var FULLSCREEN = 0x0001;
	static public var BORDERLESS = 0x0002;
	static public var RESIZABLE = 0x0004;
	static public var HARDWARE = 0x0008;
	static public var VSYNC = 0x0010;
	static public var HW_AA = 0x0020;
	static public var HW_AA_HIRES = 0x0060;
	static public var ALLOW_SHADERS = 0x0080;
	static public var REQUIRE_SHADERS = 0x0100;
	static public var DEPTH_BUFFER = 0x0200;
	static public var STENCIL_BUFFER = 0x0400;
	
	static public var company (default, null):String;
	public static var current (get, null):MovieClip;
	static public var file (default, null):String;
	public static var initHeight (default, null):Int;
	public static var initWidth (default, null):Int;
	static public var packageName (default, null):String;
	static public var silentRecreate:Bool = false;
	public static var stage (get, null):Stage;
	static public var version (default, null):String;
	
	@:noCompletion private static var __current:MovieClip = null;
	@:noCompletion private static var __isInit = false;
	@:noCompletion private static var __mainFrame:Dynamic = null;
	@:noCompletion private static var __moduleNames:Map<String, String> = null;
	@:noCompletion private static var __stage:Stage = null;
	
	
	public inline static function as<T> (v:Dynamic, c:Class<T>):Null<T> {
		
		return cast v;
		
	}
	
	
	public static function attach (name:String):MovieClip {
		
		return new MovieClip ();
		
	}
	
	
	public static function close ():Void {
		
		var close = Lib.load ("nme", "nme_close", 0);
		close ();
		
	}
	
	
	public static function create (onLoaded:Void->Void, width:Int, height:Int, frameRate:Float = 60.0, color:Int = 0xffffff, flags:Int = 0x0f, title:String = "OpenFL", icon:BitmapData = null, stageClass:Class<Stage> = null):Void {
		
		if (__isInit) {
			
			if (silentRecreate) {
				
				onLoaded ();
				return;
				
			}
			
			throw ("flash.Lib.create called multiple times. This function is automatically called by the project code.");
			
		}
		
		__isInit = true;
		initWidth = width;
		initHeight = height;
		
		var create_main_frame = Lib.load ("nme", "nme_create_main_frame", -1);
		
		create_main_frame (function (frameHandle:Dynamic) {
			
			#if android try { #end
			__mainFrame = frameHandle;
			var stage_handle = nme_get_frame_stage (__mainFrame);
			
			Lib.__stage = (stageClass == null ? new Stage (stage_handle, width, height) : Type.createInstance (stageClass, [ stage_handle, width, height]));
			Lib.__stage.frameRate = frameRate;
			Lib.__stage.opaqueBackground = color;
			Lib.__stage.onQuit = close;
			
			if (__current != null) {
				
				Lib.__stage.addChild (__current);
				
			}
			
			onLoaded ();
			#if android } catch(e:Dynamic) { trace("ERROR: " +  e); } #end
			
		}, width, height, flags, title, icon == null ? null : icon.__handle);
		
	}
	
	
	public static function createManagedStage (width:Int, height:Int, flags:Int = 0):ManagedStage {
		
		initWidth = width;
		initHeight = height;
		
		var result = new ManagedStage (width, height, flags);
		__stage = result;
		
		return result;
		
	}
	
	
	static private function findHaxeLib (library:String):String {
		
		try {
			
			var proc = new Process ("haxelib", [ "path", library ]);
			
			if (proc != null) {
				
				var stream = proc.stdout;
				
				try {
					
					while (true) {
						
						var s = stream.readLine ();
						
						if (s.substr (0, 1) != "-") {
							
							stream.close ();
							proc.close ();
							loaderTrace ("Found haxelib " + s);
							return s;
							
						}
						
					}
					
				} catch(e:Dynamic) { }
				
				stream.close ();
				proc.close ();
				
			}
			
		} catch (e:Dynamic) { }
		
		return "";
		
	}
	
	
	public static function load (library:String, method:String, args:Int = 0):Dynamic {
		
		if (__moduleNames == null) __moduleNames = new Map<String, String> ();
		
		if (__moduleNames.exists (library) #if (iphone || emscripten || android) || library == "nme" #end) {
			
			#if cpp
			return cpp.Lib.load (__moduleNames.get (library), method, args);
			#elseif neko
			return neko.Lib.load (__moduleNames.get (library), method, args);
			#end
			
		}
		
		#if waxe
		if (library == "nme") {
			
			wx.Lib.load ("nme", "wx_boot", 1);
			
		}
		#end
		
		__moduleNames.set (library, library);
		
		var result:Dynamic = tryLoad ("./" + library, library, method, args);
		
		if (result == null) {
			
			result = tryLoad (".\\" + library, library, method, args);
			
		}
		
		if (result == null) {
			
			result = tryLoad (library, library, method, args);
			
		}
		
		if (result == null) {
			
			var slash = (sysName ().substr (7).toLowerCase () == "windows") ? "\\" : "/";
			var haxelib = findHaxeLib ("openfl-native");
			
			if (haxelib != "") {
				
				result = tryLoad (haxelib + slash + "ndll" + slash + sysName () + slash + library, library, method, args);
				
				if (result == null) {
					
					result = tryLoad (haxelib + slash + "ndll" + slash + sysName() + "64" + slash + library, library, method, args);
					
				}
				
			}
			
		}
		
		loaderTrace ("Result : " + result );
		
		#if neko
		if (library == "nme") {
			
			loadNekoAPI ();
			
		}
		#end
		
		return result;
		
	}
	
	
	private static function loaderTrace (message:String) {
		
		#if cpp
		var get_env = cpp.Lib.load ("std", "get_env", 1);
		var debug = (get_env ("OPENFL_LOAD_DEBUG") != null);
		#else
		var debug = (Sys.getEnv ("OPENFL_LOAD_DEBUG") !=null);
		#end
		
		if (debug) {
			
			Sys.println (message);
			
		}
		
	}
	
	
	private static function sysName ():String {
		
		#if cpp
		var sys_string = cpp.Lib.load ("std", "sys_string", 0);
		return sys_string ();
		#else
		return Sys.systemName ();
		#end
		
	}
	
	
	private static function tryLoad (name:String, library:String, func:String, args:Int):Dynamic {
		
		try {
			
			#if cpp
			var result =  cpp.Lib.load (name, func, args);
			#elseif (neko)
			var result = neko.Lib.load (name, func, args);
			#else
			return null;
			#end
			
			if (result != null) {
				
				loaderTrace ("Got result " + name);
				__moduleNames.set (library, name);
				return result;
				
			}
			
		} catch (e:Dynamic) {
			
			loaderTrace ("Failed to load : " + name);
			
		}
		
		return null;
		
	}
	
	
	#if neko
	
	private static function loadNekoAPI ():Void {
		
		var init = load ("nme", "neko_init", 5);
		
		if (init != null) {
			
			loaderTrace ("Found nekoapi @ " + __moduleNames.get ("nme"));
			init (function(s) return new String (s), function (len:Int) { var r = []; if (len > 0) r[len - 1] = null; return r; }, null, true, false);
			
		} else {
			
			throw ("Could not find NekoAPI interface.");
			
		}
		
	}
	
	#end
	
	
	public static function exit ():Void {
		
		var quit = stage.onQuit;
		
		if (quit != null) {
			
			#if android
			if (quit == close) {
				
				Sys.exit (0);
				
			}
			#end
			
			quit ();
			
		}
		
	}
	
	
	public static function forceClose ():Void {
		
		var terminate = Lib.load ("nme", "nme_terminate", 0);
		terminate ();
		
	}
	
	
	static public function getTimer ():Int {
		
		return Std.int (Timer.stamp() * 1000.0);
		
	}
	
	
	public static function getURL (url:URLRequest, target:String = null):Void {
		
		nme_get_url (url.url);
		
	}
	
	
	public static function pause ():Void {
		
		nme_pause_animation ();
		
	}
	
	
	public static function postUICallback (inCallback:Void->Void):Void {
		
		#if android
		nme_post_ui_callback (inCallback);
		#else
		inCallback ();
		#end
		
	}
	
	
	public static function resume ():Void {
		
		nme_resume_animation ();
		
	}
	
	
	public static function setIcon (path:String):Void {
		
		var set_icon = Lib.load ("nme", "nme_set_icon", 1);
		set_icon (path);
		
	}
	
	
	public static function setPackage (company:String, file:String, packageName:String, version:String):Void {
		
		Lib.company = company;
		Lib.file = file;
		Lib.packageName = packageName;
		Lib.version = version;
		
		nme_set_package (company, file, packageName, version);
		
	}
	
	
	@:noCompletion public static function __setCurrentStage (stage:Stage):Void {
		
		__stage = stage;
		
	}
	
	
	
	
	// Getters & Setters
	
	
	
	
	static function get_current ():MovieClip {
		
		if (__current == null) {
			
			__current = new MovieClip ();
			
			if (__stage != null) {
				
				__stage.addChild (__current);
				
			}
			
		}
		
		return __current;
		
	}
	
	
	private static function get_stage ():Stage {
		
		if (__stage == null) {
			
			throw ("Error : stage can't be accessed until init is called");
			
		}
		
		return __stage;
		
	}
	
	
	
	
	// Native Methods
	
	
	
	
	#if android
	private static var nme_post_ui_callback = Lib.load ("nme", "nme_post_ui_callback", 1);
	#end
	private static var nme_set_package = Lib.load ("nme", "nme_set_package", 4);
	private static var nme_get_frame_stage = Lib.load ("nme", "nme_get_frame_stage", 1);
	private static var nme_get_url = Lib.load ("nme", "nme_get_url", 1);
	private static var nme_pause_animation = Lib.load ("nme", "nme_pause_animation", 0);
	private static var nme_resume_animation = Lib.load ("nme", "nme_resume_animation", 0);
	
	
}