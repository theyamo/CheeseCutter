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

class ArgumentException : UserException {
	this(string msg) {
		super("Argument error: " ~ msg);
	}
}

int paddedStringLength(string s, char padchar) {
	int i;
	for(i = cast(int)(s.length - 1); i >= 0; i--) {
		if(s[i] != padchar) return cast(int)(i+1);
	}
	return 0;
}

void hexdump(ubyte[] buf, int rowlen) {
	int c;
	foreach(b; buf) {
		writef("%02X ", b);
		c++;
		if(c >= rowlen) {
			c = 0;
			writef("\n");
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

int clamp(int n, int l, int h) { return n > h ? h : n < l ? l : n; }
int umod(int n, int l, int h) { return n > h ? l : n < l ? h : n; }
// 0-terminated string to d string
string ztos(char[] str) { return to!string(&str[0]); }
