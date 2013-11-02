module audio.callback;
import derelict.sdl.sdl;
import audio.player;
import ct.base;
import com.cpu;
import std.stdio;

/+ holds the state of cpu and memory for frame debug dumps. not implemented for now. +/
class SongState {
    int totalFramecallCounter, subframeCounter;
    private CPU cpu;                                                                                                                
    private ubyte[65536] data;
    CPUException exception;
	/+
    this(Song song, int tfc, int sfc) {
        data = song.data;
        cpu = new CPU(data);
        totalFramecallCounter = tfc;
        subframeCounter = sfc;
        exception = null;
    }

    void dump() {
        writefln("Frame %d(%d)", totalFrameCallCounter, subframeCounter);
        cpu.execute(pc, true);
    }+/
}

__gshared private int frameCallCounter, totalFrameCallCounter; // for multispeed
__gshared private Exception playbackStatus = null;
__gshared private bool dumpFrameRequested = false;
__gshared private bool dumpRequested = false;
__gshared int cyclesPerFrame;
__gshared int linesPerFrame;

Exception getException() {
	Exception ex = playbackStatus;
	playbackStatus = null;
	return ex;
}

void reset() {
	frameCallCounter = 0;
	totalFrameCallCounter = 0;
}

void requestDump() {
	dumpRequested = true;	
}

// called each frame from soundbuffer callback
extern(C) __gshared void audio_frame() {
	switch(audio.player.getPlaystatus()) {
	case Status.Play:
		audio.timer.tick();
		cpuCall(frameCallCounter > 0 ? 0x1006 : 0x1003, false);
		break;
	case Status.Keyjam:
		address call = 0x100c;
		song.cpu.regs.x = 0;
		if(song.ver > 7) {
			call = song.offsets[Offsets.Submplayplay];
		}
		cpuCall(call,false);
		break;
	default:
		return;
	}

	frameCallCounter++;
	totalFrameCallCounter++;
	if(frameCallCounter >= audio.audio.multiplier) {
		frameCallCounter = 0;
		frameDone();
	}

	for(int i=0; i<0x19; i++) {
		sidreg[i] = song.sidbuf[i];
	}
}

private void frameDone() {
	static int[10] avgs;
	int totalCycles;

	foreach(idx, ref avg; avgs) {
		if(idx == avgs.length - 1) {
			avg = cyclesPerFrame;
		}
		else avg = avgs[idx+1];
		totalCycles += avg;
	}
	cyclesPerFrame = 0;
	linesPerFrame = cast(int)(totalCycles / avgs.length / 63);

	if(dumpRequested) {
		dumpFrameRequested = true;
		dumpRequested = false;
	}
	else dumpFrameRequested = false;

	audio.timer.tickFullFrame();
}

void cpuCall(ushort pc, bool lockAudio) { cpuCall(pc, lockAudio, false); }
void cpuCall(ushort pc, bool lockAudio, bool forcedump) {
	if(lockAudio) SDL_LockAudio();
	try {
		if(dumpFrameRequested) {
			// state = new SongState(song, totalFrameCallCounter, frameCallCounter);
		}
		int i = song.cpu.execute(pc, false);
		cyclesPerFrame += i; 
	}
	catch(CPUException e) {
		playbackStatus = e;
		stop(); // < TODO: player.d should check if playback is in error state and stop by itself
		//UI.statusline.display(e.toString());
		//stop();
	}
	finally {
		if(lockAudio) SDL_UnlockAudio();
	}
}

extern(C) {
	__gshared extern char[0x19] sidreg;
}
