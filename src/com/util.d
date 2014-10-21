/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module com.util;
import std.stdio;
import std.string;
import std.conv;

alias char* PetString;

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
		string[] tokens = line.split();
		if(tokens.length == 0) continue;
		if(tokens[0] == argname && tokens.length > 2 && tokens[1] == "=")
			return tokens[2];
	}
	return null;
}

string setArgumentValue(string argname, string value, string text) {
	string s;
	bool found;
	foreach(line; text.splitLines()) {
		string[] tokens = line.split();
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
	writeln(table);
	
	foreach(strvalue; std.array.split(table)) {
		munch(strvalue, "\r\n\t");
		
		arr[idx] = cast(ubyte)str2Value(strvalue);
		writeln(arr[idx]);
		idx++;
	}
	return arr[0..idx];
}

int str2Value(string s) {
	if(s[0] == 'x' || s[0] == '$') {
		int val, i;
		foreach_reverse(c; toUpper(s[1..$])) {
			if(c == 'x' || c == '$') break;
			if("0123456789ABCDEF".indexOf(c) < 0)
				throw new Error("Illegal hexadecimal value in string.");
			val += ( (c >= '0' && c <= '9') ? c - '0' : c - ('A' - 10)) << (4 * i++);
		}
		return val;
	}
	return to!int(s);
}

int clamp(int n, int l, int h) { return n > h ? h : n < l ? l : n; }
int umod(int n, int l, int h) { return n > h ? l : n < l ? h : n; }
// 0-terminated string to d string
string ztos(char[] str) { return to!string(&str[0]); }
