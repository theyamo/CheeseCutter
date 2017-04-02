/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/
module ct.base;
import com.cpu;
import com.util;
import ct.purge;
import std.string;
import std.file;
import std.zlib;

enum Offsets
{
	Features, Volume, Editorflag, 
	Songsets, PlaySpeed, Subnoteplay, Submplayplay, InstrumentDescriptionsHeader,
	PulseDescriptionsHeader, FilterDescriptionsHeader, WaveDescriptionsHeader,
	CmdDescriptionsHeader, FREQTABLE, FINETUNE, Arp1, Arp2,
	FILTTAB, PULSTAB, Inst, Track1, Track2, Track3, SeqLO, SeqHI,
	CMD1, S00, SPEED, TRACKLO, VOICE, GATE, ChordTable, TRANS, ChordIndexTable, 
	SHTRANS, FOO3, NEXT, CURINST, GEED, NEWSEQ
}

immutable string[] NOTES =
	[ "C-0", "C#0", "D-0", "D#0", "E-0", "F-0",
	  "F#0", "G-0", "G#0", "A-0", "A#0", "B-0",
	  "C-1", "C#1", "D-1", "D#1", "E-1", "F-1",
	  "F#1", "G-1", "G#1", "A-1", "A#1", "B-1",
	  "C-2", "C#2", "D-2", "D#2", "E-2", "F-2",
	  "F#2", "G-2", "G#2", "A-2", "A#2", "B-2",
	  "C-3", "C#3", "D-3", "D#3", "E-3", "F-3",
	  "F#3", "G-3", "G#3", "A-3", "A#3", "B-3",
	  "C-4", "C#4", "D-4", "D#4", "E-4", "F-4",
	  "F#4", "G-4", "G#4", "A-4", "A#4", "B-4",
	  "C-5", "C#5", "D-5", "D#5", "E-5", "F-5",
	  "F#5", "G-5", "G#5", "A-5", "A#5", "B-5",
	  "C-6", "C#6", "D-6", "D#6", "E-6", "F-6",
	  "F#6", "G-6", "G#6", "A-6", "A#6", "B-6",
	  "C-7", "C#7", "D-7", "D#7", "E-7", "F-7",
	  "F#7", "G-7", "G#7", "A-7", "A#7", "B-7" ];

enum {
	MAX_SEQ_ROWS = 0x40,
	MAX_SEQ_NUM = 0x80,
	TRACK_LIST_LENGTH = 0x200,
	OFFSETTAB_LENGTH = 16 * 6,
	SEQ_END_MARK = 0xbf,
	SONG_REVISION = 12,
	NOTE_KEYOFF = 1,
	NOTE_KEYON = 2,
	SUBTUNE_MAX = 32
}

immutable ubyte[] CLEAR = [0xf0, 0xf0, 0x60, 0x00];
immutable ubyte[] INITIAL_SEQ = [0xf0, 0xf0, 0x60, 0x00, 0xbf];

alias char*[] ByteDescription;

struct Cmd {
	private ubyte[] data;
	static Cmd opCall() {
		static Cmd cmd;
		return cmd;
	}

	static Cmd opCall(ubyte[] d) {
		static Cmd cmd;
		cmd.data = d;
		return cmd;
	}
	
	void opAssign(ubyte cmd) {
		data[3] = cmd;
		if(cmd >= 0 && data[2] < 0x60) data[2] += 0x60;
	}

	void opAssign(Cmd cmd) {
		data = cmd.data;
	}

	@property ubyte value() { return data[3]; }
	alias value rawValue;

	string toString() {
		return toString(true);
	}

	string toString(bool colors) {
		ubyte v = data[3];
		if(v > 0) 
			return format("`+f%02X", v);
		else return "`+b--";
	}

	string toPlainString() {
		ubyte v = data[3];
		if(v > 0) 
			return format("%02X", v);
		else return "--"; 
	}
}

struct Ins {
	private ubyte[] data;
	static Ins opCall() {
		static Ins ins;
		return ins;
	}
	static Ins opCall(ubyte[] d) {
		static Ins ins;
		ins.data = d;
		return ins;
	}

	void opAssign(ubyte newins) {
		if(newins < 0x30)
			data[0] = cast(ubyte) (newins + 0xc0);
		else data[0] = cast(ubyte)0xf0;
	}

	void opAssign(Ins ins) {
		data = ins.data;
	}


	@property ubyte rawValue() { return data[0]; }
	@property ubyte value() { return cast(ubyte)(data[0] - 0xc0); }
	private alias value v;

	@property bool hasValue() { return value() < 0x30; }
	
	string toString() {
		if(v >= 0 && v < 0x30) 
			return format("`+f%02X", v);
		else return "`+b--";
	}

	string toPlainString() {
		alias value v;
		if(v >= 0 && v < 0x30) 
			return format("%02X", v);
		else return "--";
	}
}

struct Note {
	private ubyte[] data;
	static Note opCall(ubyte[] d) {
		static Note no;
		no.data = d;
		return no;
	}

	void opAssign(ubyte newnote) {
		if(newnote > 0x5e) newnote = 0x5e;
		data[2] = cast(ubyte)(newnote + 0x60);
	}
	
	void opAssign(Note note) {
		data = note.data;
	}

	@property ubyte rawValue() {
		return data[2];
	}
	
	@property ubyte value() {
		return data[2] % 0x60;
	}
	private alias value v;

	@property bool isTied() { return data[1] == 0x5f;	}
	
	void setTied(bool t) {
		data[1] = t ? 0x5f : 0xf0;
	}

	string toString(int trns) {
		string col, colh;
		if(isTied()) {
			col = "`4f";
			colh = "`4b";
		}
		else {
			col = "`0f";
			colh = "`0b";
		}
		switch(v) {
		case 0:
			return format("%s---", colh );
		case 1:
			return format("%s===", col );
		case 2:
			return format("%s+++", col );
		default:
			if((v + trns) > 0x5e || (v + trns) < 0)
				return format("%s???", col);
			else return format("%s%s", col, 
							   NOTES[v + trns]);
		}
	}

	string toPlainString(int trns) {
		switch(v) {
		case 0:
			return "---"; 
		case 1:
			return "==="; 
		case 2:
			return "+++"; 
		default:
			if((v + trns) > 0x5e || (v + trns) < 0)
				return "???";
			else return NOTES[v + trns];
		}
	}
}

struct Element {
	Ins instr;
	alias instr instrument;
	Cmd cmd;
	Note note;
	int transpose;
	ubyte[] data;

	static Element opCall(ubyte[] chunk) {
		static Element e;
		e.cmd = Cmd.opCall(chunk);
		e.instr = Ins(chunk);
		e.note = Note(chunk);
		e.data = chunk;
		return e;
	}

	string toString() {
		return toString(transpose);
	}
	
	string toString(int trans) {
		return format("%s`+0 %s %s", note.toString(trans), 
					  instr.toString(), cmd.toString());
	}
	
	string toPlainString() {
		return format("%s %s %s", note.toPlainString(transpose), 
					  instr.toPlainString(), cmd.toPlainString());
	}
}

struct Tracklist {
	private Track[] list; 

	Track opIndex(int i) {
		if(i >= 0x400) i = 0;
		assert(i >= 0 && i < length);
		return list[i];
	}

	static Tracklist opCall(Tracklist tl) {
		Tracklist t;
		t = tl;
		return t;
	}

	static Tracklist opCall(Track[] t) {
		Tracklist tl;
		tl.list = t;
		return tl;
	}

	Tracklist deepcopy() {
		auto copy = new Track[](list.length);
		foreach(idx, t; list) {
			auto tr = cast(ubyte)t.trans;
			auto number = cast(ubyte)t.number;
			
			copy[idx] = Track([tr, number]);
		}
		return Tracklist(copy);
	}

	void overwriteFrom(Tracklist tl) {
		for(int idx = 0; idx < tl.length; idx++) {
			auto tr = cast(ubyte)tl[idx].trans;
			auto number = cast(ubyte)tl[idx].number;
			list[idx].trans = tr;
			list[idx].number = number;
		}
	}
	
	void opIndexAssign(Track t, size_t il) {
		list[il] = t;
	}

	Track[] opSlice() { return list; }

	Tracklist opSlice(size_t x, size_t y) {
		return Tracklist(list[x .. y]);
	}

	int opApply(int delegate(ref Track) dg) {
		int result;
		for(int i = 0; i < trackLength; i++) {
			result = dg(list[i]);
			if(result) break;
		}
		return result;
	}

	int opApplyReverse(int delegate(ref Track) dg) {
		int result;
		for(int i = cast(int)(length - 1); i >= 0; i--) {
			result = dg(list[i]);
			if(result) break;
		}
		return result;
	}

	@property int length() {
		return cast(int) list.length;
	}
	
	@property void length(size_t il) {
		list.length = il;
	}

	@property Track lastTrack() {
		return list[trackLength];
	}
	
	@property int trackLength() {
		int i;
		for(i = 0; i < length; i++) {
			Track t = list[i];
			if(t.trans >= 0xf0) return i;
		}
		assert(0);
	}

	@property address wrapOffset() {
		return (lastTrack.smashedValue() / 2) & 0x7ff;
	}

	@property void wrapOffset(address offset) {
		if((offset & 0xff00) >= 0xf000) return; 
		assert(offset >= 0 && offset < 0x400);
		if(offset >= trackLength)
			offset = cast(ushort)(trackLength - 1);
		offset *= 2;
		offset |= 0xf000;
		lastTrack() = [(offset & 0xff00) >> 8, offset & 0x00ff];
	}

	void expand() {
		insertAt(trackLength);
	}

	void shrink() {
		deleteAt(trackLength-1);
	}

	// returns transpose value other than 0x80 above idx OR below(if idx == 0)
	ubyte getTransAt(int idx) {
		if(idx > 0) {
			do {
				if(list[idx].trans > 0x80 &&
				   list[idx].trans < 0xc0)
					return list[idx].trans;
			} while(idx-- > 0);
		}
		else if(idx == 0) {
			do {
				if(list[idx].trans > 0x80 &&
				   list[idx].trans < 0xc0)
					return list[idx].trans;
			} while(idx++ < trackLength);
		}
		return 0xa0;
	}

	void insertAt(int offset) {
		if(offset > list.length - 2) return;
		assert(offset >= 0 && offset < list.length);
		for(int i = cast(int)(list.length - 2); i >= offset; i--) {
			list[i+1] = list[i].dup;
		}
		list[offset].trans = getTransAt(offset);
		list[offset].number = 0;
		if(wrapOffset() >= offset) {
			wrapOffset = cast(address)(wrapOffset + 1);
		}
	}

	void deleteAt(int offset) {
		if(list[1].trans >= 0xf0) return;
		for(int i = offset; i < list.length - 2; i++) {
			list[i] = list[i+1].dup;
		}		
		if(wrapOffset() >= offset) {
			wrapOffset = cast(address)(wrapOffset - 1);
		}
	}

	void transposeAt(int s, int e, int t) {
		foreach(trk; list[s .. e])
			trk.transpose(t);
	}

	auto compact() {
		ubyte[] arr = new ubyte[1024];
		int p, trans = -1, wrapptr = wrapOffset * 2;

		foreach(idx, track; list) {
			if(track.trans >= 0xf0) {
				wrapptr |= 0xf000;
				arr[p .. p + 2] = [(wrapptr & 0xff00) >> 8, wrapptr & 0x00ff];
				p += 2;
				break;
			}
			if((track.trans != trans && track.trans != 0x80) || idx == wrapOffset) {
				trans = track.trans;
				arr[p++] = cast(ubyte)trans;
			} 
			else if(idx < wrapOffset) {
				wrapptr--;
			}
			arr[p++] = track.number;
		}
		return arr[0..p];
	}
}

struct Track {
	private ubyte[] data;

	static Track opCall(ubyte[] tr) {
		Track t;
		t.data = tr;
		assert(t.data.length == 2);
		return t;
	}

	void opAssign(ushort s) { 
		data[0] = s & 255;
		data[1] = s >> 8;
	}	

	void opAssign(ubyte[] d) { 
		data[] = d[];
	}

	void opAssign(Track tr) {
		data = tr.data;
	}

	@property void trans(ubyte t) {
		data[0] = t;
	}

	@property deprecated ushort dup() {
		return trans | (number << 8);
	}

	@property ushort smashedValue() { // "real" int value, trans = highbyte
		return number | (trans << 8);
	}

	@property ubyte trans() {
		return data[0];
	}
	
	@property ubyte number() {
		return data[1];
	}
	@property void number(ubyte no) {
		data[1] = no;
	}
	alias number trackNumber;
	
	void setValue(int tr, int no) {
		tr = clamp(tr, 0x80, 0xf3);
		if(no < 0) no = 0;
		if(no >= MAX_SEQ_NUM) no = MAX_SEQ_NUM-1;
		data[0] = tr & 255;
		data[1] = no & 255;
	}
	
	
	string toString() {
		string s = format("%02X%02X", trans, number);
		return s;
	}

	void transpose(int val) {
		if(trans == 0x80 || trans >= 0xf0) return;
		int t = trans + val;
		trans = (cast(ubyte)clamp(t, 0x80, 0xbf));
	}
}

class Sequence {
	ElementArray data;
	int rows;

	static struct ElementArray {
		ubyte[] raw;

		Element opIndex(int i) {
			assert(i < MAX_SEQ_ROWS * 4);
			assert(i < (raw.length * 4));
			ubyte[] chunk = raw[i * 4 .. i * 4 + 4];
			return Element(chunk);
		}

		void opIndexAssign(int value, size_t il) { 
			raw[il] = cast(ubyte)value;
		}
		
		int opApply(int delegate(Element) dg) {
			int result;
			for(int i = 0; i < length()/4; i++) {
				result = dg(opIndex(i));
				if(result) break;
			}
			return result;
		}
		
		@property int length() { return cast(int)raw.length; }
	}
	
	this(ubyte[] d) {
		data = ElementArray(d);
		refresh();
		if(rows*4+4 < 254)
			data.raw[rows*4 + 4 .. 254] = 0;
	}

	this(ubyte[] rd, int r) {
		data = ElementArray(rd);
		rows = r;
	}

	void refresh() {
		int p, r;
		// find seq length
		while(p < data.length) {
			ubyte b;
			b = data.raw[p+0];
			if(b == SEQ_END_MARK)
				break;
			p += 4; r++;
		}
		rows = r;
	}
	
 	override bool opEquals(Object o) const {
		auto rhs = cast(const Sequence)o;
        	return (rhs && (data.raw[] == rhs.data.raw[]));
	}

	void clear() {
		data.raw[] = 0;
		data.raw[0..5] = [0xf0,0xf0,0x60,0x00,0xbf];
		refresh();
	}

	void expand(int pos, int r) {
		expand(pos, r, true);
	}	

	void expand(int pos, int r, bool doInsert) {
		int i, len;
		int j;

		if(rows >= MAX_SEQ_ROWS) return;
		for(j=0;j<r;j++) {
			if(rows >= MAX_SEQ_ROWS) break;
			rows++;
			if(doInsert)
				insert(pos);
			else data.raw[(rows-1) * 4..(rows-1) * 4 + 4] = cast(ubyte[])CLEAR;
		}
		if(rows < 64)
			data.raw[rows*4] = SEQ_END_MARK;
	}

	void shrink(int pos, int r, bool doRemove) {
		if(rows <= 1 || pos >= rows - 1) return;
		for(int j = 0; j < r; j++) {
			if(doRemove)
				remove(pos);
			// clear endmark
			data.raw[rows * 4 .. $] = 0;
			rows--;
			data.raw[rows * 4 .. rows * 4 + 4] = cast(ubyte[])[ SEQ_END_MARK, 0, 0, 0 ];
		}
	}

	void transpose(int r, int n) {
		for(int i = r; i < rows;i++) {
			Note note = data[i].note;
			int v = note.value;
			if(v < 3) continue;
			if(n >= 0 && (v+n) < 0x60)
				v += n;
			if(n < 0 && (v+n) >= 3) v += n;
			note = cast(ubyte) v;
		}
	}	

	void insert(int pos) {
		int p1 = pos * 4;
		int p2 = rows * 4;
		if(p2 > 256) return;
		ubyte[] c = data.raw[p1 .. p2];
		ubyte[] n = c.dup;
		c[4..$] = n[0..$-4].dup;
		// clear cursor pos
		c[0..4] = cast(ubyte[])CLEAR;
	}
	
	void remove(int pos) {
		ubyte[] tmp;
		int start = pos * 4;
		int end = rows * 4;

		tmp = data.raw[start + 4 .. end].dup;
		data.raw[start .. end - 4] = tmp;
		data.raw[end - 4 .. end] = cast(ubyte[])CLEAR;
	}
	
	void copyFrom(Sequence f) {
		rows = f.rows;
		data.raw[] = f.data.raw[].dup;
	}

	// insert seq f to offset ofs
	void insertFrom(Sequence f, int ofs) {
		// make temporary copy so that seq can be appended over itself
		Sequence copy = new Sequence(f.data.raw.dup);
		expand(ofs, f.rows);

		int max = MAX_SEQ_ROWS*4;
		int st = ofs * 4;
		int len = copy.rows * 4;
		int end = st + len;
		if(end >= max) {
			end = max;
			len = end - st;
		}
		data.raw[st .. end] = copy.data.raw[0..len];
	}
	
	ubyte[] compact() {
		ubyte[] outarr = new ubyte[257];
		int i, outp, olddel, oldins = -1, 
			olddelay = -1, delay;
		for(i = 0; i < rows;) {
			Element e = data[i];
			bool cmd = false;
			int note = e.note.rawValue;

			if(note >= 0x60 && e.cmd.rawValue > 0) 
				cmd = true;
			else {
				if(note >= 0x60) note -= 0x60;
			}
			
			if(e.instr.value < 0x30 && oldins != e.instr.value) {
				oldins = e.instr.value;
				outarr[outp++] = cast(ubyte)(e.instr.value + 0xc0);
			}

			// calc delay
			delay = 0;
			for(int j = i + 1; j < rows; j++) {
				Element ee = data[j];
				if((ee.note.rawValue % 0x60) == 0 &&
				   ee.cmd.rawValue == 0 &&
				   !ee.instr.hasValue()) {
					delay++; i++;
				}
				else break;
			}

			if(olddelay != delay) {
				olddelay = delay & 15;
				outarr[outp++] = cast(ubyte)(delay | 0xf0);
				olddelay = delay & 15;
				delay -= delay & 15;
			}

			if(e.note.isTied()) outarr[outp++] = 0x5f;
			outarr[outp++] = cast(ubyte)note;
			if(cmd)
				outarr[outp++] = cast(ubyte)(e.cmd.rawValue);
			
			while(delay > 15) {
				int d = delay;
				if(d > 15) d = 15;
				if(olddelay != d) {
					outarr[outp++] = cast(ubyte)(d | 0xf0);
					olddelay = d;
				}
				outarr[outp++] = cast(ubyte)0;
				delay -= 16;
			}
			
			i++;
		}
		outarr[outp++] = cast(ubyte)SEQ_END_MARK;
		return outarr[0..outp];
	}
}

class Song {
	enum DatafileOffset {
		Binary,
		Header = 65536, 
		Title = Header + 256 + 5,
		Author = Title + 32,
		Release = Author + 32,
		Insnames = Title + 40 * 4,
		Subtunes = Insnames + 1024 * 2
	}
	
	private struct Features {
		ubyte requestedTables;
		ubyte[8] instrumentFlags;
		ubyte[16] cmdFlags;
	}

	private struct Patch {
		string name;
		ubyte[] def, wave1, wave2, filt, pulse;
	}

	static struct Chunk {
		int offset;
		ubyte[] wave1, wave2;
		bool used;
		int tokill;
		string toString() { return format("%x", offset); }
		// TODO implement .dup which copies arrasys as well
		Chunk dup() {
			assert(0);
		}
	}
	
	static class Table {
		ubyte[] data;
		this(ubyte[] data) {
			this.data = data;
		}
		int size() {
			foreach_reverse(idx, val; data) {
				if(val != 0) return cast(int)(idx + 1);
			}
			return 0;
		}
		int length() { return cast(int)data.length; }
		ubyte[] opSlice() { return data; }
		ubyte[] opSlice(size_t x, size_t y) {
			return data[x..y];
		}
	}

	class WaveTable : Table {
		struct WaveProgram {
			ubyte[] wave1, wave2;
			int offset;
		}
		// info for each waveprogram

		ubyte[] wave1, wave2;
	
		this(ubyte[] data) {
			super(data);
			wave1 = data[0 .. 256];
			wave2 = data[256 .. 512];
		}

		int seekTableEnd() {
			for(int i = 255; i >= 1; i--) {
				if(wave1[i-1] != 0) {
					return i;
				}
			}
			return 0;
		}

		Chunk[] getChunks() {
			return getChunks(data);
		}

		Chunk[] getChunks(ubyte[] wavetab) {
			/+ static +/ Chunk[] chunks = new Chunk[256];
			int counter;
			for(int i = 0, b; i < 256; i++) {
				if(wavetab[i] == 0x7f || wavetab[i] == 0x7e) {
					chunks[counter] = Chunk(b, wavetab[b .. i + 1], wavetab[b + 256 .. i + 256 + 1]);
					b = i + 1;
					counter++;
				}
			}
			return chunks[0 .. counter];
		}

		bool isValid(int waveOffset) {
			auto chunks = getChunks(data);
			return whichCell(chunks, waveOffset) >= 0;
		}

		// get program starting at waveOffset
		// mostly copied from purgeWave
		WaveProgram getProgram(int waveOffset) {
			auto chunks = getChunks(data.dup); 
			int topRow = 255;
		
			int cell = whichCell(chunks, waveOffset);
			if(cell < 0)
				throw new Error("Illegal waveprogram offset");
			markCells(chunks, cell);
			
			WaveProgram wp;

			/+ get top row in used chunks, needed to recalc arpofs NB might be necessary to calc last +/
			foreach(ref chunk; chunks) {
				if(chunk.used && chunk.offset < topRow)
					topRow = chunk.offset;
			}
			/+ generate arrays +/
			foreach(ref chunk; chunks) {
				if(!chunk.used) {
					if(waveOffset >= chunk.offset)
						waveOffset -= cast(int)chunk.wave1.length;
				
					foreach(ref chunk2; chunks) {
						if(chunk2.wave1[$ - 1] == 0x7f &&
						   chunk2.wave2[$ - 1] >= chunk.offset) {
							// check that 7f-xx is not pointing WITHIN this chunk
							//assert(chunk2.wave2[$ - 1] > chunk.offset + chunk.wave1.length);
							// calc wrap
							int t = chunk2.wave2[$ - 1] - cast(int)chunk.wave1.length;
							t = com.util.clamp(t, 0, 256);
							chunk2.wave2[$ - 1] = cast(ubyte)t;
						}
						if(chunk2.offset >=chunk.offset)
							chunk2.offset -= chunk.wave1.length;

					}
				}
			}

			foreach(ref chunk; chunks) {
				if(!chunk.used) continue;
				wp.wave1 ~= chunk.wave1;
				wp.wave2 ~= chunk.wave2;
				assert(wp.wave1[$-1] == 0x7f ||
					   wp.wave1[$-1] == 0x7e);
			}
			wp.offset = waveOffset;
			return wp;
		}
	
		static int whichCell(Chunk[] chunks, int ptr) {
			foreach(idx, chunk; chunks) {
				int b = chunk.offset,
					e = cast(int)(chunk.offset + chunk.wave1.length);
				if(ptr >= b && ptr < e) {
					return cast(int)idx;
				}
			}
			return -1;
		}

		static void markCells(Chunk[] chunks, int cell) {
			assert(cell >= 0 && cell < chunks.length);
			for(;;) {
				if(chunks[cell].used) break;
				chunks[cell].used = true;
				Chunk c = chunks[cell];
				assert(c.wave1[$-1] == 0x7e ||
					   c.wave1[$-1] == 0x7f);
				if(c.wave1[$-1] == 0x7e)
					break;
				cell = whichCell(chunks, c.wave2[$-1]);
				if(cell < 0) break;
			}
		}

		void deleteRow(Song song, int pos) {
			deleteRow(song, pos, 1);
		}

		void deleteRow(Song song, int pos, int num) {
			for(int n = 0; n < num; n++) {
				int i;
				assert(pos < 255 && pos >= 0);
				for(i = pos; i < 255; i++) {
					wave1[i] = wave1[i + 1];
					wave2[i] = wave2[i + 1];
				}
				for(i=0;i < 256;i++) {
					if((wave1[i] == 0x7f || wave1[i] == 0x7e) &&
					   wave2[i] >= pos) {
						if(wave2[i] > 0) --wave2[i];
					}
				}
				arpPointerUpdate(song, pos, -1);
			}	
		}

		void insertRow(Song song, int pos) {
			int i;
			for(i = 254; i >= pos; i--) {
				wave1[i + 1] = wave1[i];
				wave2[i + 1] = wave2[i];
			}
			for(i=0;i<256;i++) {
				if(wave1[i] == 0x7f &&
				   wave2[i] >= pos)
					wave2[i]++;
			}
			wave1[pos] = 0;
			wave2[pos] = 0;
			arpPointerUpdate(song, pos, 1);
		}

		private void arpPointerUpdate(Song song, int pos, int val) {
			for(int j = 0; j < 48; j++) {
				ubyte b7 = instrumentTable[j + 7 * 48];
				if(b7 > pos) {
					int v = b7 + val;
					if(v < 0) v = 0;
					// TODO rewrite not to access global..
					instrumentTable[j + 7 * 48] = cast(ubyte)v;
				}
			}
		}
	}

	class InstrumentTable : Table {
		this(ubyte[] data) {
			super(data);
		}

		ubyte[] getInstrument(int no) {
			ubyte[] arr = new ubyte[8];
			for(int i = 0; i < 8 ; i++) {
				arr[i] = data[no + i * 48];
			}
			return arr;
		}
	}

	class SweepTable : Table {
		this(ubyte[] data) {
			super(data);
		}

		struct SweepProgram {
			int offset;
			ubyte[] data;
		}

		bool isValid(int currentRow) {
			if(currentRow >= 0x80 && currentRow < 0x90)
				return true;
			
			bool[0x40] visited;
			for(int row = currentRow; row < 0x40;) {
				if(visited[row]) return true;
				visited[row] = true;
				int jumpValue = data[row * 4 + 3];
				if(jumpValue > 0x3f && jumpValue != 0x7f) // if illegal, break
					return false;
				if(jumpValue == 0x7f)
					return true;
				else if(jumpValue == 0) 
					row++;
				else row = jumpValue;
			}
			return false;
		}
		
		
		SweepProgram getProgram(int currentRow) {
			bool[0x40] visited;
			int topRow = currentRow;
			for(int row = currentRow; row < 0x40;) {
				if(row < topRow) topRow = row;
				if(visited[row]) break;
				visited[row] = true;
				int jumpValue = data[row * 4 + 3];
				if(jumpValue > 0x3f && jumpValue != 0x7f) // if illegal, break
					break;
				if(jumpValue == 0x7f)
					break; // if loops or ends, break
				else if(jumpValue == 0) 
					row++;
				else row = jumpValue;
			}
		
			int toremove;
			ubyte[] copy = data.dup;
			foreach(idx, vis; visited) {
				if(!vis && idx > 0) {
					for(int i = 1; i < 64; i++) {
						int jumpval =
							data[i * 4 + 3];
						if(jumpval < 0x40 &&
						   jumpval >= idx) {
							copy[i * 4 + 3]--;
						}
					}
					if(currentRow >= idx)
						++toremove;
					//--currentRow;
				}
			}

			ubyte[] arr;
		
			foreach(idx, vis; visited) {
				if(vis) {
					arr ~= copy[idx * 4 .. idx * 4 + 4];
				}
			}
		
			assert(arr[$-1] > 0);
		
			return SweepProgram(currentRow - toremove, arr);
		}

		int seekTableEnd() {
			for(int i = 0x3c; i >= 0; i -= 4) {
				if(data[i + 3] > 0) {
					return i / 4 + 1;
				}
			}
			return 0;
		}
	
	}

	
	private class Subtunes {
		ubyte[1024][3][32] subtunes;
		private int active;
		
		this() {
			initArray();
		}
		
		this(ubyte[] arr) {
			ubyte[] subts;
			this();
			subts = cast(ubyte[])(&subtunes)[0..1];
			subts[] = arr;
		}

		@property int numOf() {
			foreach_reverse(idx, ref tune; subtunes) {
				foreach(ref voice; tune) {
					if(voice[1 .. 4] != cast(ubyte[])[0x00, 0xf0, 0x00]) {
						return cast(int)(idx + 1);
					}
				}
			}
			return 0;
		}

		private void initArray() {
			foreach(ref tune; subtunes) {
				foreach(ref voice; tune) {
					voice[0 .. 2] = cast(ubyte[])[0xa0, 0x00];
					for(int i = 2; i < voice.length; i += 2) {
						voice[i .. i+2] = cast(ubyte[])[0xf0, 0x00];
					}
				}
			}
		}

		void clearAll() {
			initArray();
			syncFromBuffer();
		}

		void clear(int no) {
			foreach(ref voice; subtunes[no]) {
				voice[0 .. 2] = cast(ubyte[])[0xa0, 0x00];
				for(int i = 2; i < voice.length; i += 2) {
					voice[i .. i+2] = cast(ubyte[])[0xf0, 0x00];
				}
			}
			if(no == active)
				syncFromBuffer();
		}

		void swap(int targetNo, int sourceNo) {
			if(targetNo == sourceNo) return;
			if(targetNo == active || sourceNo == active)
				sync();
			ubyte[1024][3] sourcebuf, targetbuf;
			for(int i = 0; i < 3; i++) {
				targetbuf[i][] = subtunes[targetNo][i][];
				subtunes[targetNo][i][] = subtunes[sourceNo][i][];
				subtunes[sourceNo][i][] = targetbuf[i][];
			}
			ubyte spdtemp = songspeeds[targetNo];
			songspeeds[targetNo] = songspeeds[sourceNo];
			songspeeds[sourceNo] = spdtemp;
			if(active == targetNo || active == sourceNo)
				syncFromBuffer();
		}
		
		private void syncFromBuffer() {
			for(int i = 0; i < 3; i++) {
				data[offsets[Offsets.Track1 + i] .. offsets[Offsets.Track1 + i] + 0x400] =
					subtunes[active][i][0..0x400];
			}
		}

		Tracklist[] opIndex(int n) {
			static Tracklist[3] tr;

			for(int i=0;i<3;i++) { 
				tr[i].length = TRACK_LIST_LENGTH;
			}
			for(int i = 0; i < 3 ; i++) {
				
				ubyte[] b;
				// use array from c64 memory if getting current subtune
				if(n == active)
					b = buffer[offsets[Offsets.Track1 + i] .. offsets[Offsets.Track1 + i] + 0x400];
				else b = subtunes[n][i][0..0x400];
				for(int j = 0; j < b.length / 2; j++) {
					tr[i][j] = Track(b[j * 2 .. j * 2 + 2]);
				}
			}
			return tr;
		}

		void activate(int n) { activate(n, true); }
		void activate(int n, bool dosync) {
			if(n > 0x1f || n < 0) return;
			if(dosync)
				sync();
			active = n;
			for(int i = 0; i < 3; i++) {
				buffer[offsets[Offsets.Track1 + i] .. offsets[Offsets.Track1 + i] + 0x400] =
					subtunes[active][i][0..0x400];
			}
			if(ver >= 6)
				speed = songspeeds[active];
		}	

		/* sync "external" subtune array to active one (stored in c64s mem)
		 * the correct way would be to let trackinput also update the external array */
		private void sync() {
			for(int i = 0; i < 3; i++) {
				subtunes[active][i][0..0x400] =
					buffer[offsets[Offsets.Track1 + i] .. offsets[Offsets.Track1 + i] + 0x400];
			}
		}

		// highly dubious coding here (actually, like in most of this class..)
		ubyte[][][] compact() {
			ubyte[][][] arr;
			arr.length = numOf();
			foreach(ref subarr; arr) {
				subarr.length = 3;
			}

			for(int i = 0; i < numOf(); i++) {
				ubyte[][] subarr = arr[i];
				for(int j = 0; j < 3; j++) {
					buffer[offsets[Offsets.Track1 + j] .. offsets[Offsets.Track1 + j] + 0x400] =
						subtunes[i][j][0..0x400];
				}
								
				foreach(idx, ref voice; subarr) {
					voice = tracks[idx].compact().dup;
				}
			}
	
			return arr;
		}
	}

	int ver = SONG_REVISION, clock, multiplier = 1, sidModel, fppres;
	char[32] title = ' ', author = ' ', release = ' ', message = ' ';
	char[32][48] insLabels;
	private Features features;
	CPU cpu;
	ubyte[] sidbuf;
	ubyte[65536] data;
	alias data buffer;
	alias data memspace;
	Tracklist[] tracks;
	Sequence[] seqs;
	alias seqs sequences;
	address[] offsets;
	ubyte[32] songspeeds;
	ubyte[] songsets,
		wave1Table,
		wave2Table,
		waveTable,
		instrumentTable,
		pulseTable,
		filterTable,
		superTable,
		chordTable,
		chordIndexTable,
		seqlo,
		seqhi;
	ByteDescription instrumentByteDescriptions,
		pulseDescriptions,
		filterDescriptions,
		waveDescriptions,
		cmdDescriptions;

	// dupes of raw tables above, will eventually update all code to use these 
	Table tSongsets,
		tSuper,
		tChord,
		tChordIndex,
		tSeqlo,
		tSeqhi;
	InstrumentTable tInstr;
	WaveTable tWave;
	SweepTable tPulse, tFilter;
	Table tTrack1, tTrack2, tTrack3;
	Table[string] tables;
	char[] playerID;
	int subtune;
	Subtunes subtunes;
	// these used to be sequencer vars but they're here now since they get saved with the tune
	int highlight = 4,
		highlightOffset = 0;
		
		
  private auto playerBinary = cast(ubyte[])import("player.bin");

	this() {
		this(playerBinary);
	}

	this(ubyte[] player) {
		cpu = new CPU(buffer);
		subtunes = new Subtunes();
		foreach(ref desc; insLabels) {
			desc[] = 0x20;
		}
		ver = SONG_REVISION;
		ubyte[] bin;
		bin.length = 65536;
		bin[0xdfe .. 0xdfe + player.length] = player;
		if(bin[0xdfe .. 0xe00] != cast(ubyte[])[ 0x00, 0x0e ])
			throw new UserException("Illegal loading address.");
		songspeeds[] = 5;
		initialize(bin);
		sidbuf = memspace[0xd400 .. 0xd419];
	}


	@property int numOfSeqs() {
		int upto;
		foreach(int i, s; seqs) {
			if(s.data.raw[0 .. 5] != INITIAL_SEQ) upto = i;
		}
		return upto + 1;
	}
	
	@property int speed() {
		return memspace[offsets[Offsets.SPEED]];
	}

	@property void speed(int spd) {
		memspace[offsets[Offsets.Songsets] + 6] = cast(ubyte)spd;
		memspace[offsets[Offsets.SPEED]] = cast(ubyte)spd;
		songspeeds[subtune] = cast(ubyte)spd;
		if(ver >= 5 && spd >= 2)
			memspace[offsets[Offsets.PlaySpeed]] = cast(ubyte)spd;
	}

	@property int playSpeed() {
		return memspace[offsets[Offsets.PlaySpeed]];
	}

	@property int numInstr() {
		int maxInsno;
		seqIterator((Sequence s, Element e) { 
				int insval = e.instr.value;
				if(insval > 0x2f) return;
				if(insval > maxInsno) maxInsno = insval; });
		return maxInsno;
	}
	
	void open(string fn) {
		ubyte[] inbuf = cast(ubyte[])read(fn);
		if(inbuf[0..3] != cast(ubyte[])"CC2"[0..3]) {
			throw new UserException(format("%s: Incorrect filetype.", fn));
		}

		ubyte[] debuf = cast(ubyte[])std.zlib.uncompress(inbuf[3..$],167832);
		int offset = 65536;
		ver = debuf[offset++];
		if(ver < 6) 
			throw new UserException("The song is incompatible (too old) for this version of the editor.");
		if(ver >= 128)
			throw new UserException("The song appears to be a stereo SID file and doesn't work with this editor.");
			
		clock = debuf[offset++];
		multiplier = debuf[offset++];
		sidModel = debuf[offset++];
		fppres = debuf[offset++];
		if(ver >= 6) {
			songspeeds[0..32] = debuf[offset .. offset+32];
			offset += 32;
		}
		if(ver > 10) {
			highlight = debuf[offset++];
			highlightOffset = debuf[offset++];
		}
		offset = DatafileOffset.Title;
		title[0..32] = cast(char[])debuf[offset .. offset + 32];
		author[0..32] = cast(char[])debuf[offset + 32 .. offset + 64];
		release[0..32] = cast(char[])debuf[offset + 64 .. offset + 96];
		offset += 40 * 4;
		assert(DatafileOffset.Insnames == offset);
		offset = DatafileOffset.Insnames;

		ubyte[] insnames = 
			cast(ubyte[])(&insLabels)[0..1];
		insnames[] = debuf[offset .. offset + 48*32];

		assert(DatafileOffset.Subtunes == offset + 1024 * 2);
		offset += 1024 * 2;
		int len = 1024*3*32;
		subtunes = new Subtunes(debuf[offset .. offset + len]);
		offset += len;
		initialize(debuf[0..65536]);
	}

	void setMultiplier(int m) {
		assert(m > 0 && m < 16);
		multiplier = m;
		memspace[Offsets.Volume + 1] = cast(ubyte)m;
	}

	protected void initialize(ubyte[] buf) {
		int voi, ofs;
		data[] = buf;

		offsets.length = 0x60;
		seqs.length = MAX_SEQ_NUM;
		tracks.length = 3;
		for(int i = 0; i < 3; i++) { 
			tracks[i].length = TRACK_LIST_LENGTH;
		}

		for(int i = 0; i < OFFSETTAB_LENGTH; i++) {
			offsets[i] = data[0xfa0+i*2] | (data[0xfa1+i*2] << 8);
		}

		for(int no = 0; no < MAX_SEQ_NUM; no++) {
			int p, lo, hi;
			int lobyt = offsets[Offsets.SeqLO] + no, hibyt = offsets[Offsets.SeqHI] + no;
			p = data[lobyt] + (data[hibyt] << 8);

			ubyte[] raw_seq_data = data[p .. p+256];
			seqs[no] = new Sequence(raw_seq_data);
		}

		for(voi = 0; voi < 3; voi++) {
			ubyte[] b; 
			int t;
			int offset = offsets[Offsets.Track1 + voi];
			b = data[offset .. offset + 0x400];
			for(int i = 0; i < b.length/2; i++) {
				tracks[voi][i] = Track(memspace[offset + i * 2 .. offset + i * 2 + 2]);
			}
		}
		
		ofs = offsets[Offsets.Songsets];
		songsets = data[ofs .. ofs + 256];
		tSongsets = new Table(songsets);

		ofs = offsets[Offsets.Arp1];
		wave1Table = data[ofs .. ofs + 256];
		wave2Table = data[ofs + 256 .. ofs + 512];
		waveTable = data[ofs .. ofs + 512];
//		tWave1 = new Table(wave1Table);
//		tWave2 = new Table(wave2Table, ofs + 256);
		tWave = new WaveTable(waveTable);

		ofs = offsets[Offsets.Inst];
		instrumentTable = data[ofs .. ofs + 512];
		tInstr = new InstrumentTable(instrumentTable);

		ofs = offsets[Offsets.CMD1];
		superTable = data[ofs .. ofs + 256];
		tSuper = new Table(superTable);

		ofs = offsets[Offsets.PULSTAB];
		pulseTable = data[ofs .. ofs + 256];
		tPulse = new SweepTable(pulseTable);

		ofs = offsets[Offsets.FILTTAB];
		filterTable = data[ofs .. ofs + 256];
		tFilter = new SweepTable(filterTable);

		ofs = offsets[Offsets.SeqLO];
		seqlo = data[ofs .. ofs + 256];
		tSeqlo = new Table(seqlo);

		ofs = offsets[Offsets.SeqHI];
		seqhi = data[ofs ..ofs + 256];
		tSeqhi = new Table(seqhi);

		ofs = offsets[Offsets.ChordTable];
		chordTable = data[ofs .. ofs + 128];
		tChord = new Table(chordTable);

		ofs = offsets[Offsets.ChordIndexTable];
		chordIndexTable = data[ofs .. ofs + 32];
		tChordIndex = new Table(chordIndexTable);

		generateChordIndex();

		ofs = offsets[Offsets.Track1];
		tTrack1 = new Table(data[ofs .. ofs + 0x400]);
		ofs = offsets[Offsets.Track2];
		tTrack2 = new Table(data[ofs .. ofs + 0x400]);
		ofs = offsets[Offsets.Track3];
		tTrack3 = new Table(data[ofs .. ofs + 0x400]);
		
		playerID = cast(char[])data[0xfee .. 0xff5];
   		subtune = 0;

		ofs = offsets[Offsets.Features];
		ubyte[] b = memspace[ofs .. ofs + 64];
		features.requestedTables = b[0];
		features.instrumentFlags[] = b[1..9];

		/*
		ubyte* b = cast(ubyte*)&features;
		b[0..features.sizeof] = memspace[ofs .. ofs + features.sizeof];
		*/

		if(ver > 7) {
			instrumentByteDescriptions.length = 8;
			ofs = offsets[Offsets.InstrumentDescriptionsHeader];
			for(int j = 0; j < 8; j++) {
				int iofs = memspace[ofs] | (memspace[ofs+1] << 8);
				instrumentByteDescriptions[j] = cast(char*)&memspace[iofs];
				ofs += 2;
			}
		}

		if(ver > 8) {
			int offset;
			filterDescriptions.length = 4;
			offset = offsets[Offsets.FilterDescriptionsHeader];
			foreach(idx, ref descr; filterDescriptions) {
				int soffset = memspace[offset + idx * 2] | (memspace[offset + idx * 2 + 1] << 8);
				descr = cast(char*)&memspace[soffset];
			}
			pulseDescriptions.length = 4;
			offset = offsets[Offsets.PulseDescriptionsHeader];
			foreach(idx, ref descr; pulseDescriptions) {
				int soffset = memspace[offset + idx * 2] | (memspace[offset + idx * 2 + 1] << 8);
				descr = cast(char*)&memspace[soffset];
			}
			waveDescriptions.length = 2;
			offset = offsets[Offsets.WaveDescriptionsHeader];
			foreach(idx, ref descr; waveDescriptions) {
				int soffset = memspace[offset + idx * 2] | (memspace[offset + idx * 2 + 1] << 8);
				descr = cast(char*)&memspace[soffset];
			}

			cmdDescriptions.length = 2;
			offset = offsets[Offsets.CmdDescriptionsHeader];
			foreach(idx, ref descr; cmdDescriptions) {
				int soffset = memspace[offset + idx * 2] | (memspace[offset + idx * 2 + 1] << 8);
				descr = cast(char*)&memspace[soffset];
			}

		}
		
		subtunes.syncFromBuffer();
		speed = songspeeds[0];
		cpu.reset();
		cpu.execute(0x1000);
		tables = [ cast(string)"songsets":tSongsets, "wave":tWave,
				   "instr":tInstr, "pulse":tPulse, "filter":tFilter, "cmd":tSuper,
				   "chord":tChord, "chordidx":tChordIndex, "seqlo":tSeqlo, "seqhi":tSeqhi ];
	}
	
	void save(string fn) {
		// get tracks from the c64 memory to subtunes-array
		subtunes.sync();
		ubyte[] b;
		int offset;
		b.length = 300000;

		b[0..65536] = memspace;
		offset += 65536;

		foreach(val; [ver, clock, multiplier, sidModel, fppres]) {
			b[offset++] = val & 255;
		}
		
		b[offset .. offset+32] = songspeeds[];
		offset += 32;
		b[offset++] = cast(ubyte)highlight;
		b[offset++] = cast(ubyte)highlightOffset;

		offset = DatafileOffset.Title;

		foreach(str; [title, author, release, message]) {
			b[offset .. offset + 32] = cast(ubyte[])str[];
			offset += 32;
		}

		offset = DatafileOffset.Insnames;
		ubyte[] arr;
		arr = cast(ubyte[])(&insLabels)[0..1]; 
		b[offset .. offset + arr.length] = arr[];
		offset += arr.length;

		offset += 32 * 32 - 0x200;
		arr = cast(ubyte[])(&subtunes.subtunes)[0..1]; 
		b[offset .. offset + arr.length] = arr[];
		offset += arr.length;
		std.file.write(fn, "CC2");
		append(fn, std.zlib.compress(b));
	}

	void splitSequence(int seqnumber, int seqofs) {
		if(seqnumber == 0 || seqofs == 0) return;
		int suborig = subtune;
		int newseqnumber = getFreeSequence(0);
		Sequence s = seqs[seqnumber];
		if(seqofs == s.rows - 1) return;
		Sequence copy = new Sequence(s.data.raw.dup);
		Sequence ns = seqs[newseqnumber];
		ns.copyFrom(s);
		ns.shrink(0, seqofs, true);
		s.shrink(seqofs, s.rows - seqofs, true);
		subtunes.sync();
		foreach(sIdx, st; subtunes.subtunes) {
			subtunes.activate(cast(int)sIdx);
			foreach(vIdx, voice; tracks) {
				for(int tIdx = voice.length - 1; tIdx >= 0; tIdx--) {
					Track t = voice[tIdx];
					if(t.number == seqnumber) {
						tracks[vIdx].insertAt(tIdx+1);
						Track t2 = tracks[vIdx][tIdx+1];
						t2.trans = 0x80;
						t2.number = (cast(ubyte)newseqnumber);
					}
					
				}
			}
		}
		subtunes.activate(suborig);
	}

	private int getTablepointer(ubyte[] table, ubyte[] flags, int requestedFlag, int insno) {
		foreach(i, flag; flags) {
			if(flag != requestedFlag) continue;
			return table[insno + i * 48];
		}
		throw new UserException(std.string.format("Missing tablepointer %d", requestedFlag));
	}
	
	int wavetablePointer(int insno) {
		return getTablepointer(instrumentTable, features.instrumentFlags, 1, insno);
	}

	int pulsetablePointer(int insno) {
		int ptr = getTablepointer(instrumentTable, features.instrumentFlags, 3, insno);
		if(ptr >= 0x80) return 0;
		return ptr;
	}
	
	int filtertablePointer(int insno) {
		return getTablepointer(instrumentTable, features.instrumentFlags, 4, insno);
	}
	
	void seqIterator(void delegate(Sequence s, Element e) dg) {
		foreach(i, s; seqs) {
			for(int j = 0; j < s.rows; j++) {
				Element e = s.data[j];
				dg(s, e);
			}
		}
	}

	void seqIterator(void delegate(int seqno, Sequence s, Element e) dg) {
		foreach(int i, s; seqs) {
			for(int j = 0; j < s.rows; j++) {
				Element e = s.data[j];
				dg(i, s, e);
			}
		}
	}

	void trackIterator(void delegate(Track t) dg) {
		for(int sidx = 0; sidx < 32; sidx++) {
			Tracklist[] subtune = subtunes[sidx];
			foreach(voice; subtune) {
				foreach(track; voice) {
					dg(track);
				}
			}
		}
	}

	void tableIterator(void delegate(Table t) dg) {
		foreach(idx, table; [ "wave", "cmd", "instr", "chord",
							  "pulse", "filter"]) {
			dg(tables[table]);
		}
		
	}
	
	void setVoicon(shared int[] m) {
		//setVoicon(m[0], m[1], m[2]);
		buffer[offsets[Offsets.VOICE]+0] = m[0] ? 0x19 : 0x00;
		buffer[offsets[Offsets.VOICE]+1] = m[1] ? 0x19 : 0x07;
		buffer[offsets[Offsets.VOICE]+2] = m[2] ? 0x19 : 0x0e;
	}
	
	int getFreeSequence(int start) {
  		bool seqUsed;
		subtunes.sync();
		for(int seqnum = start; seqnum < MAX_SEQ_NUM; seqnum++) {
			seqUsed = false;
			foreach(ist, st; subtunes.subtunes) {
				foreach(voice; st) {
					foreach(t; voice) {
						if(t == seqnum)
							seqUsed = true;
					}
				}
			}
			if(!seqUsed) return seqnum;
		}
		return -1;
	}

	void clearSeqs() {
		for(int i = 1; i < MAX_SEQ_NUM; i++) {
			seqs[i].clear();
		}
		subtunes.clearAll();
	}
	
	void incSubtune() { 
		if(subtune < 31)
			subtunes.activate(++subtune); 
	}

	void decSubtune() { 
		if(subtune > 0)
			subtunes.activate(--subtune); 
	}

	void generateChordIndex() {
		int crd, p;
		for(int i = 0; i < 128; i++) {
			if(chordTable[i] >= 0x80) {
				chordIndexTable[crd] = cast(ubyte)p;
				if(++crd >= 31) throw new Error("Chord index overflow");
				p = i + 1;
			}
		}
		chordIndexTable[crd++] = cast(ubyte)(p);
	}

	void importData(Song insong) {
	  buffer[0xdfe .. 0xdfe + playerBinary.length] = playerBinary[];
	  ver = SONG_REVISION;
	  initialize(buffer.dup);
	  // copy tables
	  foreach(idx, table; [ "wave", "cmd", "instr", "chord",
							"pulse", "filter"]) {
		  tables[table].data[] = insong.tables[table].data;
	  }
	  // sequences
	  foreach(idx, ref seq; insong.seqs) {
		  seqs[idx].data.raw[] = seq.data.raw;
		  seqs[idx].refresh();
			
	  }
	  // subtunes
	  subtunes.subtunes[][][] = insong.subtunes.subtunes[][][];
	  subtunes.syncFromBuffer();
	  // labels
	  insLabels[] = insong.insLabels[];
	  title[] = insong.title[];
	  author[] = insong.author[];
	  release[] = insong.release[];
	  // vars
	  clock = insong.clock;
	  multiplier = insong.multiplier;
	  sidModel = insong.sidModel;
	  fppres = insong.fppres;
	  songspeeds = insong.songspeeds[];
	  speed = songspeeds[0];
	  // TODO highlight, highlightoffset
	  generateChordIndex();
	}

	// hack to help sequencer rowcounting 
	Sequence sequence(Track t) {
		return seqs[t.number];
	}

	void savePatch(string filename, int no) {
		import std.conv;
		string insname = std.string.stripRight
			(to!string(insLabels[no]));
		int waveptr = wavetablePointer(no);
		int pulseptr = pulsetablePointer(no);
		int filtptr = filtertablePointer(no);

		if(!tWave.isValid(waveptr)) {
			throw new UserException("Cannot save; instrument is not valid (wavetable does not wrap).");
		}

		if(!tPulse.isValid(pulseptr)) {
			throw new UserException("Cannot save; pulse is not valid.");
		}

		if(!tFilter.isValid(filtptr)) {
			throw new UserException("Cannot save; filter is not valid.");
		}

		auto wp = tWave.getProgram(waveptr);
		auto pp = tPulse.getProgram(pulseptr);
		auto fp = tFilter.getProgram(filtptr);
		// rewrite pointers. TODO: move elsewhere

		auto instr = tInstr.getInstrument(no);
		instr[7] = cast(ubyte)wp.offset;
		// skipping 0-rows since it implies inactive sweep
		if(pp.offset > 0)
			instr[5] = cast(ubyte)pp.offset;
		if(fp.offset > 0)
			instr[4] = cast(ubyte)fp.offset;

		string csv =
			to!string(playerID[0..6]) ~ "`" ~
			insname ~
			"`" ~ com.util.arr2str(instr) ~
			"`" ~ com.util.arr2str(wp.wave1) ~
			"`" ~ com.util.arr2str(wp.wave2) ~
			"`" ~ (pulseptr > 0 ?
				   com.util.arr2str(pp.data) : "") ~
			"`" ~ (filtptr > 0 ?
				   com.util.arr2str(fp.data) : "");

		if(filename is null) {
			filename = com.util.fnClean(insname ~ ".cti");
		}
		std.file.write(filename, csv);
	}

	void insertPatch(string filename, int insno) {
		import std.csv : csvReader;
		auto conv(string s) {
			ubyte[] arr = new ubyte[s.length / 2];
			for(int i = 0, j = 0; i < s.length; i += 2, j++) {
				arr[j] = cast(ubyte)com.util.convertHex(s[i .. i + 2]);
			}
			return arr;
		}
		struct Rec {
			string playerid, name, def, wave1, wave2, pulse, filt;
		}
		string patch = cast(string)std.file.read(filename);
		auto recs = csvReader!Rec(patch,'`');
		foreach(rec; recs) {
			auto p = new Purge(this);
			p.deleteInstrument(insno);
			insertInstrument(Patch(rec.name, conv(rec.def), conv(rec.wave1),
									 conv(rec.wave2), conv(rec.filt),
									 conv(rec.pulse)), insno);

			if(rec.name.length > 31) rec.name.length = 31;
			insLabels[insno][] = ' ';
			insLabels[insno][0..rec.name.length] = rec.name;
			
			// break because only 1st row needed (though there should never be more)
			break;
		}
	}

	private void insertInstrument(Patch patch, int insno) {
		assert(patch.wave1.length == patch.wave2.length);
		// check for free space in tables
		int waveptr = tWave.seekTableEnd();
		int pulseptr = tPulse.seekTableEnd() * 4;
		int filterptr = tFilter.seekTableEnd() * 4;
		if(patch.wave1.length + waveptr > tWave.wave1.length - 1)
			throw new UserException("Not enough free rows in wavetable");
		if(patch.pulse.length + pulseptr > tPulse.data.length - 4)
			throw new UserException("Not enough free rows in pulse table");
		if(patch.filt.length + filterptr > tFilter.data.length - 4)
			throw new UserException("Not enough free rows in filter table");
		
		// cram loaded data into tables
		ubyte[] wave1 = tWave.wave1[waveptr .. waveptr + patch.wave1.length];
		ubyte[] wave2 = tWave.wave2[waveptr .. waveptr + patch.wave2.length];
		for(int i = 0; i < wave1.length; i++) {
			if(wave1[i] == 0x7f)
				wave2[i] += waveptr;
		}
		wave1[0..$] = patch.wave1[];
		wave2[0..$] = patch.wave2[];

		// ----------------------------------------
		void fixSweepOffsets(ubyte[] table, int offset) {
			for(int i = 0; i < table.length; i += 4) {
				if(table[i + 3] > 0 && table[i + 3] < 0x40) {
					table[i + 3] += offset;
					assert(table[i + 3] < 0x40);
				}
			}
		}

		// insert pulse program if defined
		if(patch.def[5] > 0) {
			ubyte[] pulse = tPulse.data[pulseptr .. $];
			fixSweepOffsets(pulse, pulseptr + patch.def[5]);
			
			tPulse.data[pulseptr .. pulseptr + patch.pulse.length] =
				patch.pulse[];

			for(int i = 0; i < pulse.length - 4; i += 4) {
				if(pulse[i + 3] > 0 && pulse[i + 3] < 0x40) {
					pulse[i + 3] += pulseptr / 4 - 1;
				}
			}
			patch.def[5] += pulseptr / 4 - 1;
		}

		// insert filter if defined
		if(patch.def[4] > 0) {
			ubyte[] filt = tFilter.data[filterptr .. $];
			fixSweepOffsets(filt, filterptr + patch.def[4]);
			
			tFilter.data[filterptr .. filterptr + patch.filt.length] =
				patch.filt[];

			for(int i = 0; i < filt.length; i += 4) {
				if(filt[i + 3] > 0 && filt[i + 3] < 0x40) {
					filt[i + 3] += filterptr / 4 - 1;
				}
			}
			patch.def[4] += filterptr / 4 - 1;
		}
		
		// recalc wrap points for inserted data
		for(int i = 0; i < wave1.length; i++) {
			if(wave1[i] == 0x7f)
				wave2[i] += waveptr;
		}

		patch.def[7] += waveptr;
		
		for(int i = 0; i < 8; i++) {
			instrumentTable[i * 48 + insno] = patch.def[i];
		}
	}
}
