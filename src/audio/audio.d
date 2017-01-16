/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module audio.audio;
import derelict.sdl.sdl;
import audio.resid.filter;
import audio.player;
import audio.callback;
import audio.timer;
import std.stdio;
import core.stdc.stdlib; 
import core.stdc.string;
import std.conv;

enum MIXBUF_MUL = 2;
__gshared SDL_AudioSpec audiospec;
__gshared bool audioInited = false;
__gshared int framerate = 50;
__gshared int multiplier;
__gshared int freq = 48000, bufferSize = 2048;
__gshared private int callbackCounter = 0;
__gshared private int bufferUsed; // in samples
__gshared private int callbackInterval;
__gshared short* mixbuf = null;


extern(C) {
	extern __gshared char[0x19] sidreg;
	extern __gshared int residdelay;
	extern __gshared int sid_init(int, Filterparams*, int, int, int, int, int);
	extern __gshared int sid_fillbuffer(short *, int, int);
	extern __gshared int sid_close();
	__gshared void function() callback;


	int audio_init(int fr, void function() cb) {
		SDL_AudioSpec requested;

		if(audioInited) return 0;

		audioInited = true;

		framerate = fr;

		if(bufferSize < freq / framerate) {
		//	fprintf(stderr,"Minimum buffer size is %d bytes.\n", freq / framerate);
			return -1;
		}

		requested.freq = freq;
		requested.format = AUDIO_S16LSB;
		requested.channels = 1;
		requested.samples = cast(ushort) bufferSize;

		requested.callback = &audio_callback_2;
		
		requested.userdata = null;
		callback = cb;
		if(SDL_OpenAudio(&requested, &audiospec) < 0) {
			writeln("Could not open audio: ", to!string(SDL_GetError()));
			return -1;
		}
		if(audiospec.format != AUDIO_S16LSB) {
			writeln("Incorrect audio format obtained.");
			return -1;
		}
		bufferSize = audiospec.samples;
		mixbuf = cast(short *)malloc(bufferSize * short.sizeof * MIXBUF_MUL);
		setCallMultiplier(1);
		return 0;
	}

	int getbufsize() {
		return cast(int)(bufferSize * MIXBUF_MUL);
	}

	void audio_close() {
		SDL_CloseAudio();
		if(mixbuf) free(mixbuf);
		sid_close();
	}
	
	void reset() {
		bufferUsed = callbackCounter = 0;
	}

	void setCallMultiplier(int m) {
		if(m < 1 || m > 16) return;
		if(m == multiplier) return;
		SDL_LockAudio();
		multiplier = m;
		framerate = 50 * m;
		callbackInterval = audiospec.freq / framerate;
		reset();
		SDL_UnlockAudio();
	}

	void audio_callback(void *data, ubyte* stream, int len) {
		int samplesRequested = cast(int) (len / short.sizeof);
		int total = 0,todo = 0,t = 0;
		int steps;
		if(!audio.player.isPlaying()) return;
		while(total < samplesRequested) {
			todo = samplesRequested - total;
			assert(todo >= 0);
			if(callbackCounter + todo >= callbackInterval) {
				int c = callbackInterval - callbackCounter;
				assert(c > 0);
				t = sid_fillbuffer(cast(short*)stream + total,
								   c, 0);
				(*callback)();
				callbackCounter -= callbackInterval;
				assert(callbackCounter + todo >= 0);
			}
			else {
				assert(total + todo <= samplesRequested);
				t = sid_fillbuffer(cast(short*)stream + total,
								   todo, 0);
				
			}
			total += t;
			callbackCounter += t;
			steps++;
		}
		assert(total == samplesRequested);
	}

	__gshared void audio_callback_2(void *data, ubyte* stream, int len) {
		int samplesRequested = cast(int) (len / short.sizeof);
		int i,t;
		if(!audio.player.isPlaying()) return;
		while((bufferUsed + callbackInterval) <= bufferSize * MIXBUF_MUL) {
			t = sid_fillbuffer(mixbuf+bufferUsed, callbackInterval, cyclesPerFrame);
			bufferUsed += t;
			(*callback)();
		}

		memcpy(stream, cast(ubyte*)mixbuf, len);
		bufferUsed -= samplesRequested;
		if(bufferUsed < 0) {
			writeln("Audio buffer underrun ", bufferUsed);
			bufferUsed = 0;
		}

		short* pi, po;
		for(i = 0, pi = mixbuf, po = mixbuf + samplesRequested;
			i < bufferSize * MIXBUF_MUL - samplesRequested; i++) {
			*(pi++) = *(po++);
		}
	}
}
