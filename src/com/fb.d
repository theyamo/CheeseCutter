/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module com.fb;
import derelict.sdl2.sdl;
import std.string : indexOf;
import com.util;

SDL_Color[] PALETTE = [
	{ 0,0,0 },       
	{ 63 << 2,63 << 2,63 << 2 },
	{ 26 << 2,13 << 2,10 << 2 },
	{ 28 << 2,41 << 2,44 << 2 },
	{ 27 << 2,15 << 2,33 << 2 },

	{ 27 << 2,23 << 2,45 << 2 },
	
	{ 13 << 2,10 << 2,30 << 2 },
	
	
	
	{ 46 << 2,49 << 2,27 << 2 },
	{ 27 << 2,19 << 2,9 << 2 },
	{ 16 << 2,14 << 2,0 << 2 },
	{ 38 << 2,25 << 2,22 << 2 },
	{ 17 << 2,17 << 2,17 << 2 },
	{ 27 << 2,27 << 2,27 << 2 },
//	{ 38 << 2,52 << 2,33 << 2 },
	{ 37 << 2,37 << 2,37 << 2 } ,	


	{ 22 << 2,35 << 2,16 << 2 },	
	{ 37 << 2,37 << 2,37 << 2 } ];

immutable FONT_X = 8, FONT_Y = 14;
__gshared ubyte[] font;
immutable int mode, border = 1;
private bool isDirty = false;

immutable CHECKX = "assert(x >= 0 && x < width);";
immutable CHECKY = "assert(y >= 0 && y < height);";
immutable CHECKS = "assert(x + y >= 0 && x + y < width*height);";

static this() {
	void[] arr;
	font.length = 256*16;
	// realign font data
	immutable rawfont = import("font.psf");
	for(int i=0;i<256;i++) {
		font[i*16..i*16+14] = cast(ubyte[])rawfont[i*FONT_Y+4..i*FONT_Y+4+FONT_Y];
	}
}

abstract class Video {
	protected {
		//SDL_Surface* surface;
    SDL_Window* window;
    SDL_Renderer* renderer;
    SDL_Texture* texture;
		bool useFullscreen;
		Screen screen;
		Visualizer vis;
		const int requestedWidth, requestedHeight;
		int height, width; // resolution of window
		//int displayHeight, displayWidth; // resolution of the monitor
		SDL_Rect rect;
	}
	
	this(int wx, int wy, Screen scr, int fs) {
		//const SDL_VideoInfo* vidinfo = SDL_GetVideoInfo();
		screen = scr;
		//displayHeight = vidinfo.current_h;
		//displayWidth = vidinfo.current_w;
		requestedHeight = wy;
		requestedWidth = wx;
    
	}

	~this() {
    if(window !is null)
      SDL_DestroyWindow(window);
	}

	abstract void drawVisualizer(int);

	abstract void clearVisualizer();

	abstract protected void enableFullscreen(bool fs);

	void resizeEvent(int nw, int nh) {
	}

	void toggleFullscreen() {
		useFullscreen ^= 1; 
		enableFullscreen(useFullscreen);
	}

	void scalePosition(ref int x, ref int y) {
		x -= rect.x;
		y -= rect.y;
    /+
		x *= cast(float)requestedWidth / width;
		y *= cast(float)requestedHeight / height;
    +/
	}
		
	abstract void updateFrame();
}

class VideoStandard : Video {
	this(int wx, int wy, Screen scr, int fs) {
		super(wx, wy, scr, fs);
		enableFullscreen(fs > 0);
	}

	override protected void enableFullscreen(bool fs) {
		width = requestedWidth;
		height = requestedHeight;
		useFullscreen = fs;
    /*
		int sdlflags = SDL_SWSURFACE;
		sdlflags |= fs ? SDL_WINDOW_FULLSCREEN : 0;
		surface = SDL_SetVideoMode(width, height, 0, sdlflags); 
		if(surface is null) {
			throw new DisplayError("Unable to initialize graphics mode.");
		}
		SDL_SetPalette(surface, SDL_PHYSPAL|SDL_LOGPAL, 
					   cast(SDL_Color *)PALETTE, 0, 16);
    */
    
      // Create an application window with the following settings:
    /*
    window = SDL_CreateWindow(
        "An SDL2 window",                  // window title
        SDL_WINDOWPOS_UNDEFINED,           // initial x position
        SDL_WINDOWPOS_UNDEFINED,           // initial y position
        800,                               // width, in pixels
        600,                               // height, in pixels
        cast(SDL_WindowFlags)0
    );
    */
    SDL_CreateWindowAndRenderer(800, 600, cast(SDL_WindowFlags)0, &window, &renderer);
		//vis = new Oscilloscope(surface, 500, 14);
		screen.refresh();
	}

	override void drawVisualizer(int n) {
	}

	override void clearVisualizer() {
	}
	
	override void updateFrame() {
		int x, y;
		int a,b,c;
		Uint16* bptr = &screen.data[0];
		Uint16* cptr = &screen.olddata[0];
		// Uint32* sptr = cast(Uint32 *)surface.pixels;
		Uint32* sp;
		Uint8* bp;
		Uint8 ubg, ufg;
		int outx, outy;
    
		if (!isDirty) return;
		isDirty = false;

        SDL_Rect rect;
        rect.x = 0;
        rect.y = 0;
        rect.x = 800;
        rect.y = 600;
        //SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        //SDL_RenderDrawRect(renderer, &rect);
		//SDL_LockSurface(surface);
        SDL_RenderClear(renderer);  
		for(y = 0;y < screen.height; y++) {
			for(x = 0; x < screen.width; x++) {
				//if(*bptr != *cptr) {
                if(true) {
					*cptr = *bptr;
					//sp = sptr;
					a = *bptr & 255;
					bp = &font[a * 16];
					ufg = (*bptr >> 8) & 15;
					ubg = (*bptr >> 12);
                    /+
                     auto fgcolor = getColor(surface, ufg),
                     bgcolor = getColor(surface, ubg);
                     +/
                    rect.x = x * 8;
                    rect.y = y * 14;
                    rect.h = 14;
                    rect.w = 8;
                    SDL_SetRenderDrawColor(renderer, PALETTE[ubg].r,
                                           PALETTE[ubg].g,
                                           PALETTE[ubg].b, 255);
                    SDL_RenderFillRect(renderer, &rect);
          
                    SDL_SetRenderDrawColor(renderer, PALETTE[ufg].r,
                                           PALETTE[ufg].g,
                                           PALETTE[ufg].b, 255);
                    int yy = y * 14;
					for(c = 4; c < 18; c++, bp++) {
                        int xx = x * 8;
						b = *bp;
						if(b & 0x80) {
                            SDL_RenderDrawPoint(renderer, xx, yy);
                        }
                        xx++;
						if(b & 0x40) {
                            SDL_RenderDrawPoint(renderer, xx, yy);
                        }
                        xx++;
						if(b & 0x20) {
                            SDL_RenderDrawPoint(renderer, xx, yy);
                        } 
                        xx++;
						if(b & 0x10) {
                            SDL_RenderDrawPoint(renderer, xx, yy);
                        }
                        xx++;
						if(b & 0x08) {
                            SDL_RenderDrawPoint(renderer, xx, yy);
                        }
                        xx++;
						if(b & 0x04) {
                            SDL_RenderDrawPoint(renderer, xx, yy);
                        }
                        xx++;
						if(b & 0x02) {
                            SDL_RenderDrawPoint(renderer, xx, yy);
                        }
                        xx++;
						if(b & 0x01) {
                            SDL_RenderDrawPoint(renderer, xx, yy);
                        }
                        xx++;
						sp += width - 8;
                        yy++;
					}
          
				}
				//sptr += 8;
				bptr++;
				cptr++;
			}
			//sptr += width*13;
		}
		//SDL_UnlockSurface(surface);
		//SDL_Flip(surface);
    SDL_RenderPresent(renderer);
	}

}

class Screen {
	Uint16[] data;
	private Uint16[] olddata;
	immutable int width, height;
	alias width w;
	alias height h;
	
	this(int xchars, int ychars) {
		width = xchars;
		height = ychars;
		data.length = xchars * ychars;
		olddata.length = xchars * ychars;
		refresh();
	}
	
	Uint16 getChar(int x, int y) {
		mixin(CHECKS);
		return data[x + y * width];
	}

	void setChar(int x, int y, Uint16 c) {
		mixin(CHECKS);
		data[x + y * width] = c;
		isDirty = true;
	}

	void setColor(int x, int y, int fg, int bg) {
		mixin(CHECKS);
		Uint16* s = &data[x + y * width];
		*s &= 0xff;
		*s |= (fg << 8) | (bg << 12);
		isDirty = true;
	}

	int getbg(int x, int y) {
		return getChar(x, y) >> 12;
	}
	
	void setbg(int x, int y, int bg) {
		Uint16* s = &data[x + y * width];
		*s &= 0xfff;
		*s |= (bg << 12);
		isDirty = true;
	}

	void clrtoeol(int y, int bg) {
		clrtoeol(0, y, bg);
	}

	void clrtoeol(int x, int y, int bg) {
		mixin(CHECKY);
		Uint16* s = &data[x + y * width];
		Uint16 v = cast(Uint16)(0x20 | (bg << 12));
		while(x++ < width) *s++ = v;
		isDirty = true;
	}

	void clrscr() {
		data[] = 0x20;
		isDirty = true;
	}

	void refresh() {
		olddata[] = 255;
		isDirty = true;
	}

	void cprint(int x, int y, int fg, int bg, string txt) {
		mixin(CHECKS);
		bool skipbg, skipfg;
		if(bg < 0) { skipbg = true; bg = 0; }
		if(fg < 0) { skipfg = true; fg = 0; }
		Uint16[] s = data[x + y * width .. x + y * width + txt.length];
		Uint16 col = cast(Uint16)((fg << 8) | (bg << 12));
		foreach(i, char c; txt) {
			if(skipbg)
				col = cast(Uint16)((fg << 8) | (s[i] & 0xf000));
			if(skipfg)
				col = cast(Uint16)((bg << 12) | (s[i] & 0x0f00));
	
			s[i] = cast(Uint16)(c | col);
		}
		isDirty = true;
	}

	void fprint(int x, int y, string str) {
		mixin(CHECKS);
		assert(str.length < 256);
		Uint16[] outb = data[x + y * width .. $];
		int bg = 0, fg = 0;
		int idx;
		while(idx < str.length) {
			int getcol(char c) {
				return cast(int)(c == '+' ? -1 : "0123456789abcdef".indexOf(c));
			}
			if(str[idx] == '`') {
				bg = getcol(str[idx + 1]);
				fg = getcol(str[idx + 2]);
				idx += 3;
				continue;
			}
			if(bg >= 0) {
				outb[0] &= 0x0fff;
				outb[0] |= bg << 12;
			}
			if(fg >= 0) {
				outb[0] &= 0xf0ff;
				outb[0] |= fg << 8;
			}
			outb[0] &= 0xff00;
			outb[0] |= str[idx] & 255;
			outb = outb[1 .. $];
			idx++;
		}
	}
}

interface Visualizer {
	void clear();
	void draw(int);
}

private class Oscilloscope : Visualizer {
	private SDL_Surface* surface;
	private short* samples;
	private const short xconst, yconst;
	enum width = 960/4, height = 3*14;

	this(SDL_Surface* surface, short xpos, short ypos) {
		this.surface = surface;
		this.xconst = xpos;
		this.yconst = ypos;
		import audio.audio;
		samples = audio.audio.mixbuf;
		assert(samples !is null);
	}

	void clear() {
		SDL_FillRect(surface, new SDL_Rect(xconst, yconst,
                                           width, height), 0);
	}
	
	void draw(int frames) {
		float smpofs;
		float n = frames * 50.0f;
		int count = cast(int)(48000 / n);

		auto colh = getColor(surface, 13),
			coll = getColor(surface, 5);

		clear();
		
		smpofs = 0.0f;
		import audio.audio;
		int oldposition = height / 2 + samples[cast(int)smpofs]  / 768;

		for(int i = 0; i < width; i++) {
			int sample = samples[cast(int)smpofs] / 768;
			int position = height / 2 + sample;
			position = com.util.umod(position, 0, height-1);
			int a = oldposition, b = position;

			if(a > b) {
				int temp = b;
				b = a;
				a = temp;
			}
			assert(a <= b);
			Uint32* pos = cast(Uint32 *)surface.pixels + xconst + i + (a + yconst) * surface.w;
			*pos = (i > 12 && i < width - 12) ? colh : coll;
			for(int k = a; k < b; k++) {
				*pos = (i > 12 && i < width - 12) ? colh : coll;
				pos += surface.w;
			}
			smpofs++;
			if(smpofs >= audio.audio.getbufsize())
				smpofs -= cast(int)audio.audio.getbufsize();
			oldposition = position;
		}
	}
}

class DisplayError : Error {
	this(string msg) {
		super("SDL Error: " ~ msg);
	}
}

void enableKeyRepeat() {
  //	SDL_EnableKeyRepeat(200, 10);
}

void disableKeyRepeat() {
	//SDL_EnableKeyRepeat(0, 0);
}

Uint16 readkey() {
	SDL_Event evt;
	bool loop = true;
	
	while(loop) {
		while(SDL_PollEvent(&evt)) {
			if(evt.type == SDL_QUIT) {
				SDL_Quit();
				return 0;
			}
			if(evt.type == SDL_KEYDOWN) {
				loop = false;
				break;
			}
		}
		SDL_Delay(50);
	}
	return cast(Uint16)evt.key.keysym.unicode;
}

private int getColor(SDL_Surface* s, int c) {
	return PALETTE[c].b << s.format.Bshift | 
		(PALETTE[c].g << s.format.Gshift) |
		(PALETTE[c].r << s.format.Rshift);
}
