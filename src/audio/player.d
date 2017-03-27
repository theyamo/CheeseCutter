/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module audio.player;
import com.cpu;
import com.session;
private import ct.base;
import audio.timer;
import audio.callback;
import audio.audio;
import audio.resid.filter;
import seq.sequencer;
import ui.ui;
import derelict.sdl.sdl;
import std.stdio;

enum Status { Stop, Play, Keyjam };
shared private int playstatus;
__gshared int[6] muted;

// resid params. should really be in audio.d
const int usefp = 1;
int interpolate = 1, badline, ntsc;
ushort[2] sidtype;
int[2] curfp6581 = 0, curfp8580 = 0;
__gshared auto curfp = new const(Filterparams)*[2];

int getPlaystatus() {
	return playstatus;
}

@property bool isPlaying() { 
	return playstatus == Status.Play || playstatus == Status.Keyjam;
}

@property bool keyjamEnabled() {
	return playstatus == Status.Keyjam;
}

void init() {
	if(audio_init(ntsc ? 60 : 50, &audio_frame) < 0) {
		throw new Error("Could not init audio.");
	}
	SDL_LockAudio();
	curfp[0] = sidtype[0] > 0 ? &FP8580[curfp8580[0]] : &FP6581[curfp6581[0]];
	curfp[1] = sidtype[1] > 0 ? &FP8580[curfp8580[1]] : &FP6581[curfp6581[1]];
	sid_init(curfp.ptr, freq, sidtype.ptr, ntsc, interpolate, 0, stereo);
	/+
	if(!audioinited) {
		writefln("audio init: engine=%s, freq=%d, buf=%d, sid=%d, clock=%s, interpolation=%s%s",
				 usefp ? "resid-fp" : "resid", 
				 audio.audio.audiospec.freq, audio.audio.bufferSize,
				 sidtype ? 8580 : 6581,
				 ntsc ? "ntsc" : "pal",
				 interpolate ? "on" : "off" ,
				 badline ? ", badlines=on" : "");
	}
	if(badline) {
		audio.audio.residdelay = 48;  // 4
	}
	else audio.audio.residdelay = 0;
	+/
	SDL_UnlockAudio();
}

void setSidModel(int model1, int model2) {
	if(sidtype[0] == model1
	   && sidtype[1] == model2)
		return;

	sidtype[0] = cast(ushort)model1;
	sidtype[1] = cast(ushort)model2;
	init();
}

void toggleSIDModel(int sid) {
	setSidModel(sid, sidtype[sid] ^ 1);
}

void playNote(Element emt) {
	if(playstatus == Status.Play) return;
	int v = seq.sequencer.activeVoiceNum;

	// no audio reset if already inited
	if(playstatus != Status.Keyjam) {
		audio.callback.reset();
		audio.audio.reset();
	}

	playstatus = Status.Stop;
	audio.callback.reset();
	audio.audio.reset();
	song.setVoicon([v != 0, v != 1, v != 2, v != 3, v != 4, v != 5]);
	muteSID([1,1,1,1,1,1]);
	song.cpu.reset();
	song.cpu.regs.a = emt.note.value;
	song.cpu.regs.x = cast(ubyte)v;
	song.cpu.regs.y = emt.instr.value;
	if(song.ver > 8) 
		song.memspace[song.offsets[Offsets.SHTRANS] + v] = 0;
	ushort call = 0x1009;
	if(song.ver > 7) {
		call = song.offsets[Offsets.Subnoteplay];
	}
	cpuCall(call,true);
	playstatus = Status.Keyjam;
}

void playRow(Voice[] voices) {
	if(playstatus == Status.Play) return;
	int[] trk, seq;
	foreach(v; voices) {
		auto r = v.activeRow;
		trk ~= r.trkOffset;
		seq ~= r.seqOffset;
	}
	SDL_PauseAudio(1);
	if(SDL_GetAudioStatus() == SDL_AUDIO_PLAYING)
		std.stdio.writefln("Audio thread not finished!");
	SDL_Delay(20);
	stop();

	initPlayOffset(trk, seq);

	song.cpu.reset();

	cpuCall(0x1003,true);
	cpuCall(0x1003,true);
	cpuCall(0x1003,true);

	playstatus = Status.Keyjam;

	SDL_PauseAudio(0);
}

void start(int[] trk, int[] seq) {
	SDL_PauseAudio(1);
	if(SDL_GetAudioStatus() == SDL_AUDIO_PLAYING)
		std.stdio.writefln("Audio thread not finished!");
	SDL_Delay(20);
	stop();
	initPlayOffset(trk,seq);

	audio.timer.start();
	audio.callback.reset();
	audio.audio.reset();
	playstatus = Status.Play;
	SDL_PauseAudio(0);
}

void start() {
	start([0, 0, 0, 0, 0, 0],
		  [0, 0, 0, 0, 0, 0]);
}

void stop() {
	playstatus = Status.Stop;
	muteSID([1,1,1,1,1,1]);
}

void toggleVoice(int v) {
	if(v > 5 || v < 0) return;
	muted[v] = muted[v] ^ 1;
	setVoicon(muted);
}

void setVoicon(int[] m) {
	assert(m.length == 6);
	muted[0..$] = m[0..$].dup;
	muteSID(m); //m[0], m[1], m[2]);
	song.setVoicon(muted);
}
/+
deprecated void setVoicon(shared int[] m) {
	muted[] = cast(int[])m.dup;
	muteSID(muted); //m[0], m[1], m[2]);
	song.setVoicon(muted);
}
+/
void initFP() {
	init();
	song.fppres[0] = sidtype[0] ? curfp8580[0] : curfp6581[0];
	song.fppres[1] = sidtype[1] ? curfp8580[1] : curfp6581[1];
}

void nextFP(int sid)  {
    if (usefp) {
        if (sidtype[sid]) {
            ++curfp8580[sid];
            curfp8580[sid] %= FP8580.length;
        } else {
            ++curfp6581[sid];
            curfp6581[sid] %= FP6581.length;
        }
        initFP();
    }
}


void setFP(int fp0, int fp1) {
    if (usefp) {
        if (sidtype[0]) {
			curfp8580 = cast(int)(fp0 % FP8580.length);
        } else {
			curfp6581 = cast(int)(fp0 % FP6581.length);
        }

        if (sidtype[1]) {
			curfp8580[1] = cast(int)(fp1 % FP8580.length);
        } else {
			curfp6581[1] = cast(int)(fp1 % FP6581.length);
        }

        initFP();
    }
}


void prevFP(int sid) {
    if (usefp) {
        if (sidtype[sid]) {
            --curfp8580[sid];
            if (curfp8580[sid] < 0) curfp8580[sid] = cast(int)(FP8580.length-1);
        } else {
            --curfp6581[sid];
            if (curfp6581[sid] < 0) curfp6581[sid] = cast(int)(FP6581.length-1);
        }
        initFP();
    }
}

void fastForward(int val) {
	int step = val * 16;
	SDL_LockAudio();
	for(int i = 0 ; i < step; i++) {
		audio_frame();
	}
	SDL_UnlockAudio();
}

void dumpFrame() {
	if(playstatus == Status.Play || playstatus == Status.Keyjam)
		audio.callback.requestDump();
}

void setMultiplier(int m) {
	if(m < 1 || m > 16) return;
	
	song.multiplier = m;
	audio.audio.setCallMultiplier(m);
}

void decMultiplier() {
	setMultiplier(song.multiplier - 1);
}

void incMultiplier() {
	setMultiplier(song.multiplier + 1);
}

private void initPlayOffset(int[] t, int[] s) {
	void out16b(int offs, int value) {
		song.buffer[offs] = value & 255;
		song.buffer[offs + 1] = (value >> 8) & 255;
	}
	address[] offset = new address[6];
	address off1 = cast(ushort)(song.offsets[Offsets.Track1] + t[0] * 2);
	address off2 = cast(ushort)(song.offsets[Offsets.Track1 + 1] + t[1] * 2);
	address off3 = cast(ushort)(song.offsets[Offsets.Track1 + 2] + t[2] * 2);
	address off4 = cast(ushort)(song.offsets[Offsets.Track1] + (3 * 0x400)+ t[3] * 2);
	address off5 = cast(ushort)(song.offsets[Offsets.Track1] + (4 * 0x400)+ t[4] * 2);
	address off6 = cast(ushort)(song.offsets[Offsets.Track1] + (5 * 0x400)+ t[5] * 2);
	int tpoin2 = song.offsets[Offsets.Songsets];
	int tpoin = song.offsets[Offsets.TRACKLO];
	song.cpu.reset();
	if(song.ver >= 6) {
		{
			song.buffer[tpoin] = off1 & 255;
			song.buffer[tpoin+1] = off2 & 255;
			song.buffer[tpoin+2] = off3 & 255;
			song.buffer[tpoin+3] = off4 & 255;
			song.buffer[tpoin+4] = off5 & 255;
			song.buffer[tpoin+5] = off6 & 255;
			song.buffer[tpoin+6] = off1 >> 8;
			song.buffer[tpoin+7] = off2 >> 8;
			song.buffer[tpoin+8] = off3 >> 8;
			song.buffer[tpoin+9] = off4 >> 8;
			song.buffer[tpoin+10] = off5 >> 8;
			song.buffer[tpoin+11] = off6 >> 8;
		}	
		out16b(tpoin2, song.offsets[Offsets.Track1]);
		out16b(tpoin2+2, song.offsets[Offsets.Track1+1]);
		out16b(tpoin2+4, song.offsets[Offsets.Track1+2]);
		{
			out16b(tpoin2+8, song.offsets[Offsets.Track4]);
			out16b(tpoin2+10, song.offsets[Offsets.Track4] + 0x400);
			out16b(tpoin2+12, song.offsets[Offsets.Track4] + 0x800);
		}
	}
	cpuCall(0x1000,false);
 	int seqcnt = song.offsets[Offsets.NEWSEQ];

	for(int i = 0; i < s.length; i++) {
		song.buffer[seqcnt + i] = cast(ubyte)(s[i] * 4 + 1);
	}
	song.setVoicon(muted);

	SDL_PauseAudio(0);
}

private void muteSID(int[] m) {
	assert(m.length == 6);
	if(m[0]) song.sidbuf[4] = 0x08;
	if(m[1]) song.sidbuf[7 + 4] = 0x08;
	if(m[2]) song.sidbuf[14 + 4]= 0x08;
	if(m[3]) song.sidbuf[0x20 + 4]= 0x08;
	if(m[4]) song.sidbuf[0x20 + 7 + 4]= 0x08;
	if(m[5]) song.sidbuf[0x20 + 14 + 4]= 0x08;
}

