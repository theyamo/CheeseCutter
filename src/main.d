/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module main;
import derelict.sdl.sdl;
import com.fb;
import com.session;
import com.kbd;
import com.util;
import ui.ui;
import ui.input;
import audio.player;
import audio.resid.filter;
import audio.audio;
import std.stdio;
import std.string;
import std.conv;
import std.file;

version(linux) {
	const DIR_SEPARATOR = '/';
}

version(OSX) {
	const DIR_SEPARATOR = '/';
}

version(Win32) {
	const DIR_SEPARATOR = '\\';
}

void initVideo(bool useFullscreen, bool useyuv) {
	int mx, my;

	if( SDL_Init(SDL_INIT_VIDEO) < 0) {
		throw new DisplayError("Couldn't initialize framebuffer.");
	}
	mx = 800; my = 600;
	int width = mx / FONT_X;
	int height = my / FONT_Y;
	screen = new Screen(width, height);
	video = useyuv ? new VideoYUV(800, 600, screen, useFullscreen ? 1 : 0) :
		new VideoStandard(800, 600, screen, useFullscreen ? 1 : 0);

	SDL_EnableKeyRepeat(200, 10);
	SDL_EnableUNICODE(1);
	SDL_WM_SetCaption("CheeseCutter".toStringz(),"CheeseCutter".toStringz());
}

void mainloop() {
	int mods, key, unicode;
	bool quit = false;
	SDL_Event evt;
	while(!quit) {
		int ticks = audio.timer.readTick();
		mainui.timerEvent(ticks);
		while(SDL_PollEvent(&evt)) {
			switch(evt.type) {
			case SDL_QUIT:
				quit = true;
				break;
			case SDL_KEYDOWN:
				if(mainui.activeInput !is null) {
					Cursor cursor = mainui.activeInput.cursor;
					if(cursor !is null) cursor.reset();
				}
				mods = evt.key.keysym.mod;
				key = evt.key.keysym.sym;
				unicode = evt.key.keysym.unicode;
				mods &= 0xffffff - KMOD_NUM;
				auto keyinfo = Keyinfo(key, mods, unicode);
				com.kbd.translate(keyinfo);
				version(OSX) {
					if (key == SDLK_q && evt.key.keysym.mod & KMOD_META)
						quit=true;
				}	
				
				mainui.keypress(keyinfo);
				if(mainui.exitRequested)
					quit = true;

				mainui.update();
				break;
			case SDL_KEYUP:
				mods = evt.key.keysym.mod;
				key = evt.key.keysym.sym;
				unicode = evt.key.keysym.unicode;
				mods &= 0xffff - KMOD_NUM;
				Keyinfo keyinfo = Keyinfo(key, mods, unicode);
//				com.kbd.translate(keyinfo);
				mainui.keyrelease(keyinfo);
				break;
			case SDL_MOUSEBUTTONDOWN:
				switch(evt.button.button) {
				case 1, 3:
					int x, y;
					SDL_GetMouseState(&x, &y);
					video.scalePosition(x, y);
					int cx = (x + 4) / 8, cy = y / 14;
					mainui.clickedAt(cx, cy, evt.button.button);
					break;
				case 5:
					//rootwin.windowByCoord(cx, cy).mousewheelDown();
					mainui.keypress(Keyinfo(SDLK_DOWN, 0, 0));
					break;
				case 4:
					mainui.keypress(Keyinfo(SDLK_UP, 0, 0));
					break;
				default:
					break;
				}
				mainui.update();
				break;
			case SDL_MOUSEMOTION:
				break;
			case SDL_ACTIVEEVENT:
				break;
			case SDL_VIDEORESIZE:
				video.resizeEvent(evt.resize.w, evt.resize.h);
				break;
			case SDL_VIDEOEXPOSE:
				mainui.update();
				break;
			default:
				//writeln("Unknown SDL event ",evt.type);
				break;
			}
		}
		if(mainui.activeInput !is null) {
			mainui.activeInput.update();
			Cursor cursor = mainui.activeInput.cursor;
			if(cursor !is null) cursor.blink();
		}
		SDL_Delay(40);
		video.updateFrame();
	}
}

void printheader() {
	stderr.writefln("CheeseCutter (C) 2009-15 Abaddon");
	stderr.writefln("Released under GNU GPL.");
	stderr.writef("\n");
	stderr.writefln("Usage: ccutter [OPTION]... [FILE]");
	stderr.writef("\n");
	stderr.writefln("Options:");
	stderr.writefln("  -b [value]       Set playback buffer size (def=%d)", audio.audio.bufferSize);
	stderr.writefln("  -f               Start in fullscreen mode");
	stderr.writefln("  -nofp            Do not use resid-fp emulation");
	stderr.writefln("  -fpr [x]         Specify filter preset. x = 0..16 for 6581 and 0..1 for 8580");
	stderr.writefln("  -i               Disable resid interpolation (use fast mode instead)");
	stderr.writefln("  -m [0|1]         Specify SID model for reSID (6581/8580) (def=0)");
	stderr.writefln("  -n               Enable NTSC mode");
	stderr.writefln("  -r [value]       Set playback frequency (def=48000)");
	stderr.writefln("  -y               Use YUV video overlay");
	stderr.writef("\n");
}

int main(char[][] args) {
	int i;
	bool fs = false;
	bool yuvOverlay;
	string filename;
	bool fnDefined = false;

	DerelictSDL.load();
	
	scope(exit) {
		delete mainui;
		delete video;
		SDL_Quit();
	}
	
	scope(failure) {
		if(song !is null) {
			stderr.writefln("Crashed! Saving backup...");
			song.save("_backup.ct");
		}
	}

	try {
		i = 1;
		while(i < args.length) {
			switch(args[i])
			{
			case "-h", "-help", "--help", "-?":
				printheader();
				return 0;
			case "-m":
				sidtype = to!int(args[i+1]);
				if(sidtype != 0 && sidtype != 1 && sidtype != 6581 && sidtype != 8580)
					throw new UserException("Incorrect SID type; specify 0 for 6581 or 1 for 8580");
				i++;
				break;
        	case "-fpr":
				int fprarg = to!int(args[i+1]);

				sidtype ? (audio.player.curfp8580 = cast(int)(fprarg % FP8580.length)) :
					(audio.player.curfp6581 = cast(int)(fprarg % FP6581.length));
				i++;
				break;
			case "-i":
				audio.player.interpolate = 0;
				break;
			case "-l":
				audio.player.badline = 1;
				break;
			case "-n":
				audio.player.ntsc = 1;
				break;
			case "-r":
				audio.audio.freq = to!int(args[i+1]);
				i++;
				break;
			case "-b":
				audio.audio.bufferSize = to!int(args[i+1]);
				i++;
				break;
			case "-f","--full":
				fs = true;
				break;
			case "-nofp":
				audio.player.usefp = 0;
				break;
			case "-y", "-ya", "-yuv":	
				yuvOverlay = true;
				break;
			default:
				version (OSX) {
					if (args[i].length > 3 && args[i][0..4] == "-psn"){
						break;
					}
				}
				if(args[i][0] == '-')
					throw new UserException(format("Unrecognized option %s", args[i]));
				if(fnDefined)
					throw new UserException("Filename already defined.");
				filename = cast(string)args[i].dup;
				if(std.file.exists(filename) == 0 || std.file.isDir(filename)) {
					throw new UserException("File not found!");
				}		
				fnDefined = true;
		
				break;
			}
			i++;
		}
	}
	catch(UserException e) {
		std.stdio.stderr.writeln(e);
		return -1;
	}
	
	audio.player.init();
	initVideo(fs, yuvOverlay);
	initSession();
	mainui = new UI();
	loadFile(filename);
	video.updateFrame();
		
	SDL_PauseAudio(0);
	mainloop();
	audio.audio.audio_close();
	return 0;   
}

void openFile(char* filename){
	string str = to!(string)(filename);
	loadFile(str);

}

void loadFile(string filename){
	if(filename && mainui) {
		string dir, fn;
		int sep = cast(int) filename.lastIndexOf(DIR_SEPARATOR); 
		fn = filename[sep + 1..$];
		if(sep >= 0)
			dir = filename[0 .. sep];
		else dir = ".";
		chdir(dir);
		mainui.loadCallback(fn);
		mainui.update();
	}
}

