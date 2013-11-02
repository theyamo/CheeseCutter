module audio.timer;

import audio.audio;
import ct.base;

__gshared int sec, min;
__gshared private int clockCounter;
__gshared private int fplayTickCounter, fplayRowCounter; // how many rows done since last fplay update?
__gshared private int tickCounter;

int readRowTick() {
	int t = fplayRowCounter;
	fplayRowCounter = 0;
	return t;
}

int readTick() {
	int t = tickCounter;
	tickCounter = 0;
	return t;
}

void stop() {
	
}

/+ from player.start +/
void start() {
	sec = min = clockCounter = 0;
	fplayTickCounter = fplayRowCounter = 0;
}
/+ should be called each on update from callback +/
void tick() {
	if(++clockCounter >= audio.audio.framerate) {
		clockCounter = 0;
		if(++sec > 59) {
			sec = 0; min++;
			min %= 100;
		}
	}
}

/+ should be called once per frame cycle, updated fplay counters +/
void tickFullFrame() {
	tickCounter++;
	if(++fplayTickCounter > song.playSpeed()) {
		fplayRowCounter++;
		fplayTickCounter = 0;
	}
}
