/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module com.util;
import std.stdio;
import std.string;
import std.conv;
//import std.regex;

alias char* PetString;

//private auto regexFn = regex("[^a-zA-Z0-9_\\-\\.]");


string versionInfo() {
	version(DEV)
		return " (" ~__DATE__ ~ " git)";
	return " (" ~__DATE__ ~ ")";
}

struct Clip {
	int trans, no;
}

struct Queue(T) {
	enum NUM_UNDO_STAGES = 200;
	import std.container.dlist;
	auto stages = DList!T();

	void insert(T t) {
		import std.range;
		auto r = stages[];
		if(r.walkLength >= NUM_UNDO_STAGES)
			stages.removeBack();
		stages.insertFront(t);
	}

	bool empty() {
		return stages.empty;
	}

	T pop() {
		if(stages.empty) assert(0);
		auto t = stages.front;
		stages.removeFront();
		return t;
	}

	void clear() {
		stages.clear;
	}
}

class UserException : Exception {
	this(string msg) {
		super(msg);
	}

	override string toString() { return msg; }
}

int paddedStringLength(string s, char padchar) {
	int i;
	for(i = cast(int)(s.length - 1); i >= 0; i--) {
		if(s[i] != padchar) return cast(int)(i+1);
	}
	return 0;
}

void hexdump(ubyte[] buf, int rowlen) {
	hexdump(buf, rowlen, false);
}

void hexdump(ubyte[] buf, int rowlen, bool prrow) {
	int c, r;
	if(prrow)
		writef("%02x: ", 0);
	
	foreach(b; buf) {
		writef("%02X ", b);
		c++;
		if(c >= rowlen) {
			c = 0;
			writef("\n");
			if(prrow) writef("%02x: ",++r);
		}
	}
	writef("\n");
}

string petscii2D(PetString petstring) {
	char[] s;
	int idx;
	s.length = 512;
	while(*petstring != '\0') {
		char c = *(petstring++);
		if(c == '&') {
			s[idx] = '\n';
			s[idx + 1 .. idx + 6] = ' ';
			idx += 6;
		}
		else s[idx++] = c;
	}
	s.length = idx;
	return format(s);
}

deprecated string getArgumentValue(string argname, string[] text) {
	foreach(line; text) {
		string[] tokens = std.array.split(line);
		//string[] tokens = line.split();
		if(tokens.length == 0) continue;
		if(tokens[0] == argname && tokens.length > 2 && tokens[1] == "=")
			return tokens[2];
	}
	return null;
}

string setArgumentValue(string argname, string value, string text) {
	string s;
	bool found;
	//foreach(line; text.splitLines()) {
	foreach(line; text.splitLines()) {
		//string[] tokens = line.split();
		string[] tokens = std.array.split(line);
		if(tokens.length == 0) continue;
		if(tokens[0] == argname && tokens.length > 2 && tokens[1] == "=") {
			line = tokens[0] ~ tokens[1] ~ " " ~ value;
			found = true;
		}
		s ~= line ~ "\n";
	}
	if(!found) throw new Exception("argname " ~ argname ~ " not found");
	return s;
}

ubyte[] table2Array(string table) {
	static ubyte[4096] arr;
	int idx;
	foreach(strvalue; std.array.split(table)) {
		munch(strvalue, "\r\n\t");
		
		arr[idx] = cast(ubyte)str2Value(strvalue);
		idx++;
	}
	return arr[0..idx];
}

int str2Value(string s) {
	if(s[0] == 'x' || s[0] == '$') {
		return convertHex(s[1 .. $]);
	}
	return to!int(s);
}

int convertHex(string s) {
	int val, i;
	foreach_reverse(c; toUpper(s)) {
		if(c == 'x' || c == '$') break;
		if("0123456789ABCDEF".indexOf(c) < 0)
			throw new Exception("Illegal hexadecimal value in string.");
		val += ( (c >= '0' && c <= '9') ? c - '0' : c - ('A' - 10)) << (4 * i++);
	}
	return val;
}

void parseList(ref int[] array, string arg) {
	int index;
	string[] list = std.string.split(arg, ",");
	foreach(valueset; list) {
		string[] values = std.string.split(valueset, ":");
		if(values.length == 0) { // length == 0, just skip
			index++;
		}
		else if(values.length == 1) { // the sole value is the speed
			array[index] = to!int(values[0]);
		}
		else {
			index = to!int(values[0]);
			if(index > 31)
				throw new UserException("Value list index out of bounds.");
			array[index] = to!int(values[1]);
		}
		index++;
		if(index > 31)
			throw new UserException("Value list too long.");
	}
}

int str2Value2(string s) {
	int idx;
	bool hexUsed;
	if(s[0] == 'x' || s[0] == '$') {
		hexUsed = true; idx = 1;
	}
	else if(s.length > 2 && s[0..2] == "0x") {
		hexUsed = true; idx = 2;
	}
	if(hexUsed) {
		int val, i;
		foreach_reverse(char c; toUpper(s[idx..$])) {
			if("0123456789ABCDEF".indexOf(c) < 0)
				throw new UserException("Illegal hexadecimal value in argument.");
			val += ( (c >= '0' && c <= '9') ? c - '0' : c - ('A' - 10)) << (4 * i++);
		}
		return val;
	}
	foreach(char c; s) {
		if("0123456789".indexOf(c) < 0)
			throw new UserException("Illegal value in argument.");
	}
	return to!int(s);
}

string arr2str(ubyte[] arr) {
	//char[] c = new string(arr.length * 2);
	char[] c = (new string(arr.length * 2)).dup;
	foreach(idx, ubyte byt; arr) {
		c[idx * 2 .. idx * 2 + 2] = std.string.format("%02x", byt);
	}
	return to!string(c);
}
/*
string fnClean(string fn) {
	return replaceAll(fn,regexFn,"_");
}

bool fnIsSane(string fn) {
	return matchAll(fn,regexFn).empty;
}*/
string fnClean(string fn) 
{
	return tr(fn,"a-zA-Z0-9._-","_","c");
}
bool fnIsSane(string fn) 
{
	return (fn == fnClean(fn));
}


int clamp(int n, int l, int h) { return n > h ? h : n < l ? l : n; }
int umod(int n, int l, int h) { return n > h ? l : n < l ? h : n; }
// 0-terminated string to d string
string ztos(char[] str) { return to!string(&str[0]); }
