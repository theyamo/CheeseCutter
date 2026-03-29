/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module com.fb;
import derelict.sdl2.sdl;
import std.string : indexOf;
import com.util;

immutable SDL_Color[] PALETTE = [
	{ 0,0,0 },       
	{ 63 << 2,63 << 2,63 << 2 },
	{ 26 << 2,13 << 2,10 << 2 },
	{ 28 << 2,41 << 2,44 << 2 },
	{ 27 << 2,15 << 2,33 << 2 },
	{ 22 << 2,35 << 2,16 << 2 },
	{ 13 << 2,10 << 2,30 << 2 },
	{ 46 << 2,49 << 2,27 << 2 },
	{ 27 << 2,19 << 2,9 << 2 },
	{ 16 << 2,14 << 2,0 << 2 },
	{ 38 << 2,25 << 2,22 << 2 },
	{ 17 << 2,17 << 2,17 << 2 },
	{ 27 << 2,27 << 2,27 << 2 },
	{ 38 << 2,52 << 2,33 << 2 },
	{ 27 << 2,23 << 2,45 << 2 },
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


class Video {
	protected {
    SDL_Window* window;
    SDL_Renderer* renderer;
    SDL_Texture* texture;
    uint[] framebuffer;
		bool useFullscreen;
		Screen screen;
		const int requestedWidth, requestedHeight;
    int correctedHeight, correctedWidth;
		int height, width; // resolution of window
		//int displayHeight, displayWidth; // resolution of the monitor
		SDL_Rect destRect;
	}

	this(int wx, int wy, Screen scr, int fs) {
		this.screen = scr;
		this.requestedHeight = wy;
		this.requestedWidth = wx;
    this.framebuffer = new uint[wx*wy];
	}


	~this() {
		if(renderer !is null)
			SDL_DestroyRenderer(renderer);

    // if(texture !is null)
    //   SDL_DestroyTexture

    if(window !is null)
      SDL_DestroyWindow(window);

	}

	bool init() {
		width = requestedWidth;
		height = requestedHeight;
		useFullscreen = false;

    import std.string, std.stdio;

    window = SDL_CreateWindow("CheeseCutter 2.10", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 800, 600, cast(SDL_WindowFlags)
                              SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE
                              );

    if (window is null) {
      return false;
    }

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    if (renderer is null) {
      return false;
    }

    texture = SDL_CreateTexture(renderer, SDL_GetWindowPixelFormat(window),
                                SDL_TEXTUREACCESS_TARGET, 800, 600);

    if (texture is null) {
      return false;
    }

    SDL_SetRenderTarget(renderer, null);

    calcAspect();
    screen.refresh();

    return true;
	}

  void drawVisualizer(int) {}

  void clearVisualizer() {}

  protected void enableFullscreen(bool fs) {}

	void toggleFullscreen() {
		useFullscreen ^= 1;
		enableFullscreen(useFullscreen);
	}

  // TBD
	void scalePosition(ref int x, ref int y) {
		x -= destRect.x;
		y -= destRect.y;
    /+
		x *= cast(float)requestedWidth / width;
		y *= cast(float)requestedHeight / height;
    +/
	}

  void updateFrame() {
    auto surface = SDL_GetWindowSurface(window);
		int x, y;
		int a,b,c;
		ushort* bptr = &screen.data[0];
		ushort* cptr = &screen.olddata[0];
    uint* sptr = framebuffer.ptr;
		uint* sp;
		ubyte* bp;
		ubyte ubg, ufg;

		if (!isDirty) return;
		isDirty = false;

		for(y = 0;y < screen.height; y++) {
			for(x = 0; x < screen.width; x++) {
				if(*bptr != *cptr) {
					*cptr = *bptr;
					sp = sptr;
					a = *bptr & 255;
					bp = &font[a * 16];
					ufg = (*bptr >> 8) & 15;
					ubg = (*bptr >> 12);
					auto fgcolor = getColor(surface, ufg),
						bgcolor = getColor(surface, ubg);
					for(c = 4; c < 18; c++, bp++) {
						b = *bp;
						if(b & 0x80) *(sp++) = fgcolor;
						else *(sp++) = bgcolor;
						if(b & 0x40) *(sp++) = fgcolor;
						else *(sp++) = bgcolor;
						if(b & 0x20) *(sp++) = fgcolor;
						else *(sp++) = bgcolor;
						if(b & 0x10) *(sp++) = fgcolor;
						else *(sp++) = bgcolor;
						if(b & 0x08) *(sp++) = fgcolor;
						else *(sp++) = bgcolor;
						if(b & 0x04) *(sp++) = fgcolor;
						else *(sp++) = bgcolor;
						if(b & 0x02) *(sp++) = fgcolor;
						else *(sp++) = bgcolor;
						if(b & 0x01) *(sp++) = fgcolor;
						else *(sp++) = bgcolor;
						sp += width - 8;
					}
				}
				sptr += 8;
				bptr++;
				cptr++;
			}
			sptr += width*13;
		}

    // Apparently this is fairly slow: https://wiki.libsdl.org/SDL3/SDL_UpdateTexture
    SDL_UpdateTexture(texture, null, framebuffer.ptr, 800 * uint.sizeof);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, null, &destRect);
    SDL_RenderPresent(renderer);
	}

	void resizeEvent(int nw, int nh) {
    calcAspect();
		screen.refresh();
	}

	private void calcAspect() {
    int windowWidth, windowHeight;

    SDL_GetWindowSize(window, &windowWidth, &windowHeight);

		int correctedHeight = windowHeight;
		int correctedWidth = windowWidth;
		if(cast(float)windowHeight / windowWidth < 0.75) {
			correctedWidth = cast(int)(correctedHeight / 0.75);
			correctedHeight = windowHeight;
		}
		else {
			correctedWidth = windowWidth;
			correctedHeight = cast(int)(correctedWidth * 0.75);
		}
    destRect.w = correctedWidth;
    destRect.h = correctedHeight;
    if (windowWidth > correctedWidth)
      destRect.x = (windowWidth - correctedWidth) / 2;
    else destRect.x = 0;
    if (windowHeight > correctedHeight)
      destRect.y = (windowHeight - correctedHeight) / 2;
    else destRect.y = 0;
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

auto getColor(SDL_Surface* s, int c) {
  return SDL_MapRGBA(s.format, PALETTE[c].r, PALETTE[c].g, PALETTE[c].b, 255);
}
