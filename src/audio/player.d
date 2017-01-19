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
shared int[3] muted;
int usefp = 1, sidtype, interpolate = 1, badline, ntsc;
__gshared Filterparams curfp;
int curfp6581 = 0, curfp8580 = 0;

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
	curfp = sidtype ? FP8580[curfp8580] : FP6581[curfp6581];
	sid_init(usefp, &curfp, freq, sidtype, ntsc, interpolate, 0);
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

void setSidModel(int v) {
	assert(v == 0 || v == 1);
	if(sidtype == v) return;
	sidtype = v;
	init();
}

void toggleSIDModel() {
	setSidModel(sidtype ^ 1);
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

	song.setVoicon([v == 0 ? 0 : 1, v == 1 ? 0 : 1, v == 2 ? 0 : 1]);
	muteSID(1,1,1);
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
	start([0, 0, 0], [0, 0, 0]);
}

void stop() {
	playstatus = Status.Stop;
	muteSID(1,1,1);
}

void toggleVoice(int v) {
	if(v > 2 || v < 0) return;
	muted[v] = muted[v] ^ 1;
	setVoicon(muted);
}

void setVoicon(int v1, int v2, int v3) {
	setVoicon([v1, v2, v3]);
}

void setVoicon(int[] m) {
	muted[0] = m[0];
	muted[1] = m[1];
	muted[2] = m[2];
	muteSID(m[0], m[1], m[2]);
	song.setVoicon(muted);
}

void setVoicon(shared int[] m) {
	muted[0] = m[0];
	muted[1] = m[1];
	muted[2] = m[2];
	muteSID(m[0], m[1], m[2]);
	song.setVoicon(muted);
}

void initFP() {
	init();
	song.fppres = sidtype ? curfp8580 : curfp6581;
}

void nextFP() {
    if (usefp) {
        if (sidtype) {
            ++curfp8580;
            curfp8580 %= FP8580.length;
        } else {
            ++curfp6581;
            curfp6581 %= FP6581.length;
        }

        initFP();
    }
}


void setFP(int fp) {
    if (usefp) {
        if (sidtype) {
			curfp8580 = cast(int)(fp % FP8580.length);
        } else {
			curfp6581 = cast(int)(fp % FP6581.length);
        }
        initFP();
    }
}


void prevFP() {
    if (usefp) {
        if (sidtype) {
            --curfp8580;
            if (curfp8580 < 0) curfp8580 = cast(int)(FP8580.length-1);
        } else {
            --curfp6581;
            if (curfp6581 < 0) curfp6581 = cast(int)(FP6581.length-1);
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
	address off1 = cast(ushort)(song.offsets[Offsets.Track1] + t[0] * 2);
	address off2 = cast(ushort)(song.offsets[Offsets.Track2] + t[1] * 2);
	address off3 = cast(ushort)(song.offsets[Offsets.Track3] + t[2] * 2);
	int tpoin2 = song.offsets[Offsets.Songsets];
	int tpoin = song.offsets[Offsets.TRACKLO];
	song.cpu.reset();
	if(song.ver >= 6) {
		song.buffer[tpoin] = off1 & 255;
		song.buffer[tpoin+1] = off2 & 255;
		song.buffer[tpoin+2] = off3 & 255;
		song.buffer[tpoin+3] = off1 >> 8;
		song.buffer[tpoin+4] = off2 >> 8;
		song.buffer[tpoin+5] = off3 >> 8;
		out16b(tpoin2, song.offsets[Offsets.Track1]);
		out16b(tpoin2+2, song.offsets[Offsets.Track2]);
		out16b(tpoin2+4, song.offsets[Offsets.Track3]);
	}
 	else {
		out16b(tpoin2, off1);
		out16b(tpoin2+2, off2);
		out16b(tpoin2+4, off3);
	}
	cpuCall(0x1000,false);
 	int seqcnt = song.offsets[Offsets.NEWSEQ];
	song.buffer[seqcnt] = cast(ubyte)(s[0] * 4 + 1);
	song.buffer[seqcnt+1] = cast(ubyte)(s[1] * 4 + 1);
	song.buffer[seqcnt+2] = cast(ubyte)(s[2] * 4 + 1);
	song.setVoicon(muted);

	SDL_PauseAudio(0);
}

private void muteSID(int v1, int v2, int v3 ) {
	if(v1) song.sidbuf[4] = 0x08;
	if(v2) song.sidbuf[7 + 4] = 0x08;
	if(v3) song.sidbuf[14 + 4]= 0x08;
}

