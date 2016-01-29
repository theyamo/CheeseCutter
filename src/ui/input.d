/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module ui.input;
import derelict.sdl.sdl;
import com.fb;
import com.session;
import com.util;
import ct.base;
import seq.sequencer;
import audio.player;
import ui.ui;
import std.string;
import std.utf;
import std.stdio : stderr;

enum { RETURN = -1, CANCEL = -2, OK = 0, WRAP = 1, WRAPR, WRAPL, EXIT, IllegalValue }

struct Keyinfo {
	int key, mods, unicode;
	alias key raw;
}

class Cursor {
	enum BLINK_VAL = 8;
	int x = -1, y = -1;
	private {
		int counter;
		int bg2, fg2;
		int bg, fg;
	}
	
	void set() { set(x,y); }
	alias set refresh;
  
	void set(int nx, int ny) {
		if(nx < 0 || ny < 0) return;
		if(x != nx || y != ny) {
			x = nx; y = ny;
			ushort col = screen.getChar(x, y);
			counter = BLINK_VAL;
			bg = fg2 = (col >> 8) & 15;
			fg = bg2 = (col >> 12) & 15;
		}
		screen.setColor(x,y,bg2,fg2);
	}

	void reset() {
		counter = BLINK_VAL;
		bg2 = fg;
		fg2 = bg;
	}

	void blink() {
		if(--counter < 0) {
			int t;
			counter = BLINK_VAL;
			t = bg2; bg2 = fg2; fg2 = t;
		}
	}
}

class Input {
	Cursor cursor;
	const int width;
	int x, y, nibble;
	alias x pointerX;
	alias y pointerY;
	alias width inputLength;
	ubyte[] inarray, outarray; 

	this(ubyte[] p, int len) {
		this(len);
		setOutput(p);
	}
	this(int len) {
		cursor = new Cursor();
		width = len;
		inarray.length = len;
	}

	void setOutput(ubyte[] p) {
		outarray = p;
	}

	void setCoord(int nx, int ny) {
		if(nx) x = nx;
		if(ny) y = ny;
	}
	alias setCoord set;

	int keypress(Keyinfo key) { assert(0); }
	
	int setValue(int v) { assert(0); }

	int step(int st) {
        nibble += st;
        if(nibble < 0) {
			nibble = inputLength - 1;
			return WRAP; // should return WRAPL
        }
        else if(nibble >= inputLength) {
			nibble = 0;
			return WRAP; 
        }
        return OK;
	}

	void update() { assert(0); }

	void refresh() { assert(0); }
	
	int toInt() {
		return toInt(inarray);
	}

	@property int value() {
		return toInt(inarray);
	}
	
	int toInt(ubyte[] ar) {
		int v;
		for(int i = cast(int)(ar.length-1), sh; i >= 0; i--) {
			v |= ar[i] << sh;
			sh += 4;
		}
		return v;
	}
	
	int toIntRange(int b, int e) {
		return toInt(inarray[b..e]);
	}

private:

	int valueKeyReader(Keyinfo key, char[] keytab) {
        foreach(i, k; keytab) {
			if(key.raw == k)
                return cast(int)i;
        }
        return -1;
	}

	int keypressStepHandler(Keyinfo key, char[] keytab) {
		int v = valueKeyReader(key, keytab);
		if(v >= 0) {
			int r = setValue(v);
			// if 'setValue' returns > 0, don't step
			if(r) return r;
			// if shift is pressed, don't step
			if(key.mods & KMOD_SHIFT) return OK;
			return step(1);
		}
		return OK;
	}
}

class InputValue : Input {
	this(ubyte[] p, int len) {
		super(p, len);
	}

	override void setOutput(ubyte[] p) {
		super.setOutput(p);
		// initialize value
		for(int i=0; i < inputLength; i++) {
			int j = i / 2;
			int sh = (i & 1) ? 0 : 4;
			inarray[i] = (p[j] >> sh) & 15;
		}
	}
	
	override int keypress(Keyinfo key) {
		int v;
		if(key.mods & KMOD_CTRL) return 0;
		if(key.raw == SDLK_RETURN)
			return RETURN;
		else if(key.raw == SDLK_ESCAPE)
			return CANCEL;
		return keypressStepHandler(key, cast(char[])"0123456789abcdef");
	}

	override int setValue(int v) {
		inarray[nibble] = cast(ubyte)v;
		int c = toInt();
		for(int i = cast(int)(inputLength/2-1); i >= 0; i--) {
			outarray[i] = c & 255;
			c >>= 8;
		}
		return OK;
	}
	
	override void update() {
		string fmt = std.string.format("0%dX",inputLength);
        screen.cprint(x, y, 1, -1, format("%" ~ fmt,toInt()));
		cursor.set(x + nibble, y);
	}
}

class InputByte : InputValue {
	this(ubyte[] p) {
		super(p, 2);
	}
}

class InputBoundedByte : InputValue {
	this(ubyte[] p) {
		super(p, 2);
	}

	override int keypress(Keyinfo key) {
		int v;
		if(key.mods & KMOD_CTRL) return 0;
		if(key.raw == SDLK_RETURN)
			return RETURN;
		else if(key.raw == SDLK_ESCAPE)
			return CANCEL;
		switch(key.raw)
		{
		case SDLK_LEFT:
			return step(-1);
		case SDLK_BACKSPACE:
			step(-1);
			setValue(0);
			return OK;
		case SDLK_RIGHT:
			return step(1);
		default:
			if(nibble < 2)
				return keypressStepHandler(key, cast(char[])"0123456789abcdef");
			return OK;
		}
	}
	
	override int step(int st) {
        nibble += st;
        if(nibble < 0) 
			nibble = 0;
        else if(nibble > 2) 
			nibble = 2;
        return OK;
	}

	override void update() {
		screen.cprint(x, y, 1, -1, format("%02X ", toInt()));
		cursor.set(x + nibble, y);
	}
	
}

class InputSingleChar : InputValue {
	string keys;
	int defaultKey;
	this(ubyte[] p, string keys, int defaultKey) {
		super(p, 2);
		this.keys = keys;
		setValue(0);
		this.defaultKey = defaultKey;
	}

	override int keypress(Keyinfo key) {
		auto v = keys.indexOf(key.raw);
		if(key.mods & KMOD_CTRL) return 0;
		else if(key.raw == SDLK_ESCAPE) {
			return CANCEL;
		}
		else if(key.raw == SDLK_RETURN) {
			setValue(cast(ubyte)defaultKey);
			return RETURN;
		}
		else if(v >= 0) {
			setValue(cast(ubyte)(v));
			return RETURN;
		}
		return IllegalValue;
	}
	
	override int step(int st) {
		return OK;
	}

	override void update() {
		//screen.cprint(x, y, 1, -1, format("%02X ", toInt()));
		screen.cprint(x + nibble, y, 1, -1, std.conv.to!string(keys[defaultKey]));
		cursor.set(x + nibble, y);
	}
}


class InputWord : InputValue {
	this(ubyte[] p) {
		super(p, 4);
	}
}

class InputTrack : InputWord {
	Track trk;
	ubyte[2] buf;
	this(RowData s) {
		super(buf);
		init(s);
		flush();
	}
	
	void init(RowData s) {
		trk = s.trk;
		buf[] = valueCheck(trk.trans, trk.number);
		super.setOutput(buf);
	}
	
	alias init refresh;

	void flush() {
 		trk.setValue(buf[0], buf[1]);
	}
	
	override int setValue(int v) {
		super.setValue(v);
		buf[] = valueCheckNoWrap(buf[0], buf[1]);
		super.setOutput(buf); 
		return OK;
	}

	override int keypress(Keyinfo key) {
		if(key.mods & KMOD_ALT) return OK;
		switch(key.unicode)
		{
		case 6: // ctrl-f
			int s = song.getFreeSequence(buf[1] + 1);
			if(s > 0)
				buf[] = valueCheck(buf[0], s);
			setOutput(buf);
			flush();
			break;
		case SDLK_LESS:
			int i = buf[1] - 1;
			buf[] = valueCheck(buf[0], i);
			setOutput(buf);
			flush();
			break;
		case SDLK_GREATER:
			int i = buf[1] + 1;
			buf[] = valueCheck(buf[0], i);
			setOutput(buf);
			flush();
			break;
		default:
			break;
		}
		switch(key.raw)
		{
		case SDLK_LEFT:
			if(--nibble < 0) {
				nibble = inputLength - 1;
				return WRAPL;
			}
			return OK;
		case SDLK_RIGHT:
			if(++nibble >= inputLength) {
				nibble = 0;
				return WRAPR;
			}
			return OK;
		case SDLK_SPACE:
			flush();
			return OK;
		default:
			break;
		}
		if(buf[0] < 0xc0)
			return super.keypress(key);
		return OK;
	}

private:
	
	ubyte[] valueCheck(int tr, int no) {
		if(tr < 0x80) tr = 0x80;
		if(no < 0) no = 0;
		if(no > 0x80) no = 0x00; 
		if(no >= MAX_SEQ_NUM) no = MAX_SEQ_NUM-1;
		return cast(ubyte[])[tr,no];
	}

	// don't allow wrapmark
	ubyte[] valueCheckNoWrap(int tr, int no) {
		ubyte[] b = valueCheck(tr, no);
		if(b[0] > 0xbf) b[0] = 0xbf;
		return b;
	}
}

class InputString : Input {
	char[] instring;
	this(string s) { this(s, 80); }
	this(string s, int len) {
		super(len);
		setOutput(s);
	}

	override void setOutput(ubyte[] p) {
		assert(0);
	}
	
	void setOutput(string s) {
		int tl = cast(int)s.length;
		char[] str2 = std.utf.toUTF8(s.dup).dup;
		str2.length = inputLength;
		if(tl >= inputLength) tl = inputLength;
		str2[tl .. $] = ' ';
		instring = str2;
		nibble = stringLength;
		if(nibble >= inputLength)
			nibble = inputLength - 1;
	}
	
	override string toString() {
		return toString(false);
	}

	string toString(bool pad) {
		if(!pad)
			return cast(string)(instring[0..stringLength].dup);
		return cast(string)(instring);
	}

	override void update() {
		screen.cprint(x, y, 1, 0, toString(true));
		cursor.set(x + nibble, y);
	}

	void setChar(dchar value) {
		instring[nibble] = cast(char)value;
	}

	override int keypress(Keyinfo key) {
		int i;

		switch(key.raw)
		{
		case SDLK_LEFT:
			if(step(-1))
				nibble = 0;
			break;
		case SDLK_RIGHT:
			if(step(1))
				nibble = inputLength-1;
			break;
		case SDLK_BACKSPACE:
			if(step(-1)) {
				nibble = 0;
				break;
			}
			goto case SDLK_DELETE;
		case SDLK_DELETE:
			instring[nibble .. $-1] = instring[nibble+1 .. $].dup;
			instring[$-1] = ' ';
			break;
		// slightly bugs when str.length == inputLength
		case SDLK_HOME:
			nibble = 0;
			break;
		case SDLK_END:
			nibble = stringLength;
			if(nibble >= inputLength)
				nibble = inputLength - 1;
			break;
		case SDLK_RETURN:
			return RETURN;
		case SDLK_ESCAPE:
			return CANCEL;
		default:
			void insert() {
				instring[nibble+1 .. $] = instring[nibble .. $-1].dup;
			}
			if(key.raw == SDLK_INSERT) {
				insert();
				setChar(' ');
			}
			else if(key.unicode && key.unicode != '`') {
				string old = cast(string)(instring.dup);
				insert();
				setChar(key.unicode);
				try {
					validate(instring);
				}
				catch(UTFException e) {
					stderr.writeln(e.toString);
					instring = old.dup;
					break;
				}
				if(step(1) == WRAP) nibble = inputLength - 1;
			}
			break;
		}
		return OK;
	}

	@property int stringLength() {
		for(int i = inputLength - 1; i >= 0; i--) {
			if(instring[i] != ' ') 
				return i+1;
		}
		return 0;
	}
}

abstract class ExtendedInput : Input {
	protected {
		int nibble, memvalue;
		Element element;
		Voice[] voices;
		int voice;
	}
	int invalue;

	protected this() {
		super(1);
	}
	
	protected this(int w) {
		super(w);
	}

	override int step(int st) {
		nibble += st;
		if(nibble >= width) {
			nibble = width - 1;
			return WRAPR;
		}
		else if(nibble < 0) {
			nibble = 0;
			return WRAPL;
		}
		return OK;
	}

	override int keypress(Keyinfo key) {
		return keypress(key, "0123456789abcdef");
	}

	int keypress(Keyinfo key, string keytab) {
		if(key.mods & KMOD_CTRL || key.mods & KMOD_ALT)
			return OK;
		switch(key.unicode) {
		case ' ':
			if(memvalue >= 0) {
				invalue = memvalue;
				setRowValue(memvalue);
				return WRAP;
			}
			goto case '.';
		case '.':
			clearRow();
			return WRAP;
		default: 
			if(keytab == null) return WRAP;
			int value = valueKeyReader(key, keytab);
			if(value < 0) return OK;
			return valuekeyHandler(value);
		}
		//not reached
	}

protected:
	
	int valuekeyHandler(int value) {
		if(width == 1) invalue = value;
		else {
			if(nibble == 0) {
				invalue &= 0x0f;
				invalue |= value << 4;
			}
			else {
				invalue &= 0xf0;
				invalue |= value & 255;
			}
		}
		setRowValue(invalue);
		memvalue = invalue;
		if(++nibble >= width) {
			nibble = 0;
			invalue = 0;
			return WRAP;
		}

		return OK;
	}

	void clearRow() {
		memvalue = -1;
	}

	void setRowValue(int value) {
	}

	void setElement(Element e) {
		element = e;
	}

	override void update() {
		assert(0);
	}
	
	static int valueKeyReader(Keyinfo key,  const char[] keytab) {
        foreach(int i, k; keytab) {
			if(key.raw == k) {
				if(key.mods & KMOD_SHIFT)
					return cast(int)(i | 0x80);
				return i;
			}
        }
        return -1;
	}
}

class InputOctave : ExtendedInput {
	override int keypress(Keyinfo key) {
		return super.keypress(key,"012345678");
	}	

	override void setRowValue(int value) {
		if(element.note.value >= 3) {
			int note = ((element.note.value + element.transpose) % 12) 
				+ value * 12 - element.transpose;
			if(note >= 3 && note < 0x5f)
				element.note = cast(ubyte)note;
		}
	}
}

class InputInstrument : ExtendedInput {
	this() { super(2); }
	override void clearRow() {
		super.clearRow();
		element.instr = 0xc0;
		invalue = 0x30;
	}

	override void setElement(Element e) {
		super.setElement(e);
		if(e.instr.value < 0x30)
			invalue = e.instr.value;
		else invalue = 0;
	}

	override int keypress(Keyinfo key) {
		switch(key.unicode) {
		case SDLK_RETURN:
			if(element.instr.value < 0x30)
				mainui.activateInstrumentTable(element.instr.value);
			break;
		default:
			break;
		}
		return super.keypress(key);
	}

	override void setRowValue(int v) {
		element.instr = cast(ubyte)v;
		UI.activateInstrument(v);
	}
}

class InputCmd : ExtendedInput {
	this() { super(2); }

	override void clearRow() {
		super.clearRow();
		element.cmd = 0;
	}

	override void setElement(Element e) {
		super.setElement(e);
		invalue = e.cmd.rawValue;
	}

	override void setRowValue(int v) {
		element.cmd = cast(ubyte)v;
	}
}

class InputNote : ExtendedInput {
	InputKeyjam keyjam;
	
	this() {
		super();
		keyjam = new InputKeyjam();
	}

	override int keypress(Keyinfo key) {
		if(key.mods & KMOD_CTRL || key.mods & KMOD_ALT) {
			switch(key.raw) {
			case SDLK_g:
				if(element.instr.value < 0x30)
					UI.activateInstrument(element.instr.value);
				break;
			default:
				break;
			}
			return OK;
		}

		switch(key.unicode) {
		case SDLK_RETURN:
			if(element.instr.value < 0x30) {
				UI.activateInstrument(element.instr.value);
			}
			if(element.note.value >= 3 && element.note.value < 0x5f) {
				state.octave = clamp((element.note.value + element.transpose) / 12, 0, 6);
			}
			break;
		case SDLK_COMMA:
			if(element.note.value >= 3 && element.note.value < 0x5f) {
				element.note.setTied(element.note.isTied() ?
									 false : true);
			}
			return WRAP;
			/+
		case SDLK_SEMICOLON:
			if(element.note.rawValue >= 3 && element.note.rawValue < 0x5f)
				element.note.setTied(false);
			return WRAP;
			+/
		default:
			break;
		}
		
		if(song.ver >= 7) {
			keyjam.element.transpose = element.transpose;
			keyjam.keypress(key); 
		}
		int r = super.keypress(key,"1!azsxdcvgbhnjmq2w3er5t6y7ui9o0p"); 
		// no cache for notecolumn
		memvalue = -1;
		return r;
	}

	override void clearRow() {
		super.clearRow();
		element.note = 0;
		element.note.setTied(false);
		element.instr = 0x80;
	}

	override void setRowValue(int value) {
		if(value < 0) return;
		switch(value) {
		case 0:
			element.note = NOTE_KEYOFF;
			element.note.setTied(false);
			element.instr = 0x80;
			break;
		case 2:
		case 0x80:
			element.note = NOTE_KEYON;
			element.note.setTied(false);
			element.instr = 0x80;
			break;
		default:
			int note = ((value - 3) & 0x7f) + 12 * state.octave - element.transpose;
			if(note > 0x5e) break;
			element.note = cast(ubyte)note;
			if(state.autoinsertInstrument && value < 0x80) {
				if(state.activeInstrument >= 0)
					element.instr = cast(ubyte)(state.activeInstrument);
				else element.instr = 0x80;
			}
			if(value >= 0x80) {
				element.note.setTied(true);
			}
			else element.note.setTied(false);
			break;
		}
	}
	
	override int step(int st) {
		if(st >= 0) return WRAPR;
		return WRAPL;
	}
}

class InputKeyjam : ExtendedInput {
	ubyte[4] dummy;
	this() {
		element = Element(dummy);
		super();
	}

	override void setRowValue(int value) {
		if(value < 0) return;
		switch(value) {
		case 0:
			element.note = NOTE_KEYOFF;
			element.note.setTied(false);
//			element.instr = 0x80;
			break;
		case 2:
		case 0x80:
			element.note = NOTE_KEYON;
			break;
		default:
			int note = ((value - 3) & 0x7f) + 12 * state.octave;
			if(note > 0x5e) return;
			element.note = cast(ubyte)note;
			if(value >= 0x80) {
				element.note.setTied(true);
			}
			else element.note.setTied(false);

			break;
		}
		if(state.activeInstrument >= 0)
			element.instr = cast(ubyte)(state.activeInstrument);
		audio.player.playNote(element);
	}
	
	override int keypress(Keyinfo key) {
		return super.keypress(key,"1!azsxdcvgbhnjmq2w3er5t6y7ui9o0p");
	}

	int keyrelease(Keyinfo key) {
		return OK;
	}
}

final class InputSeq : ExtendedInput {
	Element element;
	private {
		ExtendedInput inputNote, inputInstrument, inputCmd, inputOctave;
	}
	ExtendedInput[] inputters;
	ExtendedInput activeInput;
	int activeInputNo;
	alias activeInputNo activeColumn;
	enum columns = 3;
	
	this() {
		super();
		inputNote = new InputNote();
		inputInstrument = new InputInstrument();
		inputCmd = new InputCmd();
		inputOctave = new InputOctave();
		activeInput = inputNote;
		inputters = [inputNote, inputOctave, inputInstrument, inputCmd];
	}

	void setPointer(int x, int y) {
		if(x >0)
			pointerX = x;
		if(y > 0)
			pointerY = y;
	}

	override void setCoord(int x, int y) {
		setPointer(x, y);
	}

	override void setElement(Element e) {
		element = e;
		activeInput.setElement(e);
	}

	override int keypress(Keyinfo key) {
		switch(key.unicode) {
		case SDLK_SEMICOLON:
			state.autoinsertInstrument ^= 1;
			UI.statusline.display(format("Instrument autoinsert mode %s",
										  state.autoinsertInstrument ? "enabled." : "disabled."));
			return OK;
		case SDLK_LESS:
			state.octave = clamp(--state.octave, 0, 6);
			break;
		case SDLK_GREATER:
			state.octave = clamp(++state.octave, 0, 6);
			break;
		default:
			break;
		}
		
		return activeInput.keypress(key);
	}

	void columnReset(int foo) {
		if(foo == 0) {
			inputInstrument.nibble = 0;
			inputCmd.nibble = 0;
			activeInputNo = 0;
			activeInput = inputNote;
		}
		else {
			inputInstrument.nibble = 1;
			inputCmd.nibble = 1;
			activeInputNo = 3;
			activeInput = inputCmd;
		}
	}

	// nibble arg is for END key
	void columnReset(int foo, int nibble) {
		if(foo == 0) {
			inputInstrument.nibble = 0;
			inputCmd.nibble = 0;
			activeInputNo = 0;
			activeInput = inputNote;
		}
		else {
			inputInstrument.nibble = 1;
			inputCmd.nibble = nibble;
			activeInputNo = 3;
			activeInput = inputCmd;
		}
	}

	override int step(int st) {
		int r = activeInput.step(st);
		if(r == WRAPR) {
			//activeInput.nibble = 0;
			foreach(inp; inputters) {
				inp.nibble = 0;
			}
			
			activeInputNo++;
			if(activeInputNo >= inputters.length) {
				activeInputNo = 0;
				activeInput = inputters[activeInputNo];
				return WRAPR;
			}
			activeInput = inputters[activeInputNo];
			activeInput.nibble = 0;
			
		}
		else if(r == WRAPL) {
			foreach(inp; inputters) {
				inp.nibble = inp.width - 1;
			}
			activeInputNo--;
			if(activeInputNo < 0) {
				activeInputNo = cast(int)(inputters.length - 1);
				activeInput = inputters[activeInputNo];
				
				return WRAPL;
			}
			activeInput.nibble = activeInput.width - 1;
			activeInput = inputters[activeInputNo];
		}
		return OK;
	}

	override void update() {
		screen.cprint(pointerX, pointerY, 1, -1, element.toPlainString());
		
		assert(activeInput == inputters[activeInputNo]);
		int xofs = [0, 2, 4, 7][activeInputNo];
		cursor.set(pointerX + xofs + activeInput.nibble, pointerY);
	}	
}

class InputSpecial : InputValue {
	this(ubyte[] p) {
		super(p, 5);
	}

	override void setOutput(ubyte[] p) {
	}
	
	override int setValue(int v) {
		inarray[nibble] = v & 15;
		return OK;
	}
	
	override void update() {
		static immutable offsets = [0, 2, 3, 5, 6];
        screen.cprint(x, y, 1, -1, format("%01X-%02X %02X",inarray[0],toInt(inarray[1..3]),toInt(inarray[3..5])));
		cursor.set(pointerX + offsets[nibble], pointerY);
	}
}
