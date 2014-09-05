/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/
import std.stdio;
import std.string;
import std.file;
import std.conv;
import std.c.string;
import std.c.stdlib;

extern(C) {
	extern char* acme_assemble(const char*,int*,char*);
}

char[] assemble(string source) {
	int length;
	char error_message[1024];
	memset(&error_message, '\0', 1024);
	char* input = acme_assemble(toStringz(source), &length, &error_message[0]);
	
	if(input is null) {
		string msg = to!string(&error_message[0]);
		throw new Error(format("Could not assemble player. Message:\n%s", msg));
	}
	char[] output = new char[length];
	memcpy(output.ptr, input, length);
	free(input);
	return output;
}
