/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

import com.cpu;
import com.util;
import ct.base;
import ct.purge;
import ct.pack;
import ct.dump;
import ct.build;
import std.stdio;
import std.string;
import std.conv;
import std.stdio;

enum Command { None, ExportPRG, ExportSID, Dump, Import, Init, ExportAsmSid, ExportAsmPrg }
const string[] exts = [ "", "prg", "sid", "s", "ct", "ct", "sid", "prg" ];

bool verbose = true;
bool noPurge;

int str2Value2(string s) {
	int idx;
	bool hexUsed;
	if(s[0] == 'x' || s[0] == '$') {
		hexUsed = true; idx = 1;
	}
	else if(s[0..2] == "0x") {
		hexUsed = true; idx = 2;
	}
	if(hexUsed) {
		int val, i;
		foreach_reverse(c; toUpper(s[idx..$])) {
			if("0123456789ABCDEF".indexOf(c) < 0)
				throw new UserException("Illegal hexadecimal value in string.");
			val += ( (c >= '0' && c <= '9') ? c - '0' : c - ('A' - 10)) << (4 * i++);
		}
		return val;
	}
	return to!int(s);
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

void explain(string str) {
	if(verbose)
		writefln(str);
}

string defineOutfn(int cmd, string infn) {
	string name;
	int r = cast(int)(infn.lastIndexOf('.'));
	if(r <= 0) name = infn;
	else name = infn[0 .. infn.lastIndexOf('.')];
	return name ~ "." ~ exts[cmd];
}

void doPurge(ref Song sng) {
	if(noPurge) return;
	explain("Purging data...");
	Purge p = new Purge(sng, verbose);
	p.purgeAll();
}


int main(string[] args) {
	address relocAddress = 0x1000;
	int[] speeds, masks;
	int defaultTune;
	bool outfnDefined = false, infnDefined = false;
	int command;
	Song insong;
	string infn, outfn;
	string[3] infns;

	speeds.length = 32;
	masks.length = 32;
	void printheader() {
		writefln("CheeseCutter 2 utilities (BETA)");
		writefln("\nUsage: \t%s <command> <options> <infile> <-o outfile>",args[0]);
		writefln("\t%s import <infile> <infile2> <-o outfile>",args[0]);
		writefln("\t%s init <binaryfile> <-o outfile>",args[0]);
		writefln("\nCommands:");
		writefln("  prg           Export song (.ct) to PRG file");
		writefln("  sid           Export song (.ct) to SID file");
		writefln("  build         Export song (.ct) to SID file while optimizing the player to leave out unused effect code (BETA)");
		writefln("  buildprg      Export song (.ct) to PRG file while optimizing the player (BETA)");
		writefln("  dump          Dump song data to assembler source (BETA)");
		writefln("  import        Copy data from another song without overwriting the player");
		writefln("  init          Create a fresh .ct from player binary");
		writefln("\nGeneral options:");
		writefln("  -o <outfile>  Set output filename (by default gathered from input filename)");
		writefln("\nExport options:");
		writefln("  -n            Do not purge before exporting/dumping (leaves unused data)");
		writefln("  -r <addr>     Relocate output to address (default = $1000)");
		writefln("  -d <num>      Set the default subtune (1-32)");
		writefln("  -s [subtune]:[speed],...    Set speeds for subtunes");
		writefln("  -c [subtune]:[voicemask],...Set voice bitmasks for subtunes");
		writefln("  -q            Don't output information");
		writefln("\nPrefix value options with '0x' or '$' to indicate a hexadecimal value.");
	}

	if(args.length < 2) {
		printheader();
		return 0;
	}

	try {
		switch(args[1]) {
		case "prg":
			command = Command.ExportPRG;
			break;
		case "sid":
			command = Command.ExportSID;
			break;
		case "dump":
			command = Command.Dump;
			break;
		case "import":
			command = Command.Import;
			break;
		case "init":
			command = Command.Init;
			break;
		case "build":
			command = Command.ExportAsmSid;
			break;
		case "buildprg":
			command = Command.ExportAsmPrg;
			break;
		default:
			throw new UserException(format("command '%s' not recognized.",args[1]));
		}
		int infncounter = 0;

		if(args.length >= 2) {
			for(int argp = 2; argp < args.length; argp++) {
				string nextArg() {
					if(argp+1 >= args.length || args[argp+1][0] == '-')
						throw new UserException("Missing value for option '" ~ args[argp] ~"'");
					argp++;
					return args[argp];
				}
				switch(args[argp]) {
				case "-n":
					noPurge = true;
					break;
				case "-r":
					if(command != Command.ExportSID &&
					   command != Command.ExportPRG &&
					   command != Command.ExportAsmSid &&
					   command != Command.ExportAsmPrg)
						throw new UserException("Option available only with exporting commands.");
					int r = str2Value2(nextArg());
					if(r > 0xffff)
						throw new UserException("-r: Address value too big.");
					relocAddress = cast(ushort)r;
					break;
				case "-s":
					if(command != Command.ExportSID &&
					   command != Command.ExportPRG)
						throw new UserException("Option available only with exporting commands.");
					parseList(speeds, nextArg());
					break;
				case "-c":
					if(command != Command.ExportSID &&
					   command != Command.ExportPRG)
						throw new UserException("Option available only with exporting commands.");
					parseList(masks, nextArg());
					break;
				case "-d":
					if(command != Command.ExportSID)
						throw new UserException("Option available only when exporting to SID.");
					defaultTune = to!int(nextArg());
					if(defaultTune <= 0)
						throw new UserException("Valid range for subtunes is 1 - 32.");
					break;
				case "-o":
					if(outfnDefined)
						throw new UserException("Output file already defined.");
					outfn = args[argp+1];
					outfnDefined = true;
					argp++;
					break;
				case "-q":
					verbose = false;
					break;
				default:
					if(args[argp][0] == '-')
						throw new UserException("Unrecognized option '" ~ args[argp] ~ "'");
					if(infnDefined && command != Command.Import)
						throw new UserException("Input filename already defined. Use -o to define output file.");
					if(command == Command.Import) {
						if(infncounter > 1)
							throw new UserException("Infile & import filename already defined.");
						infns[infncounter++] = args[argp];
						infn = infns[0];
					}
					else infn = args[argp];
					infnDefined = true;
					break;
				}
			}
		}
		assert(command != Command.None);
		if(!infnDefined)
			throw new UserException("Input filename not defined.");
		if(command == Command.Init && !outfnDefined) {
			throw new UserException("Command 'init' requires output filename to be defined (option -o).");
		}
		else if(command == Command.Import && !outfnDefined) {
			throw new UserException("Command 'import' requires output filename to be defined (option -o).");
		}

		if(!outfnDefined) {
			outfn = defineOutfn(command, infn);
		}

		if(!std.file.exists(infn))
			throw new UserException(format("File %s does not exist", infn));

		explain("Input file: " ~ infn);
		explain("Output file: " ~ outfn);
		if(command == Command.ExportSID || command == Command.ExportPRG) {
			explain(format("Relocating data to $%x", relocAddress));
		}

		switch(command) {
		case Command.ExportPRG, Command.ExportSID:
			insong = new Song;
			insong.open(infn);
			doPurge(insong);
			ubyte[] data = (command == Command.ExportSID) ?
				packToSid(insong, relocAddress, defaultTune, verbose)
				: pack(insong, relocAddress, verbose);
			std.file.write(outfn, data);
			break;
		case Command.ExportAsmSid, Command.ExportAsmPrg:
			insong = new Song;
			insong.open(infn);
			doPurge(insong);
			ubyte[] data = doBuild(insong, relocAddress,
								   command == Command.ExportAsmSid,
								   verbose);
			std.file.write(outfn, data);
			break;
		case Command.Import:
			if(infncounter < 2)
				throw new UserException("Import song not defined.");
			explain("Importing data from " ~ infns[1]);
			insong = new Song;
			insong.open(infns[0]);
			Song importsong = new Song();
			importsong.open(infns[1]);
			insong.importData(importsong);
			insong.save(outfn);
			break;
		case Command.Dump:
			insong = new Song;
			insong.open(infn);
			doPurge(insong);
			std.file.write(outfn, dumpData(insong, infn));
			break;
		case Command.Init:
			insong = new Song(cast(ubyte[])std.file.read(infn));
			insong.save(outfn);
			break;
		default:
			assert(0);
		}
	}
	catch(UserException e) {
		writeln("error: ", e);
		return -1;
	}
	catch(Exception e) {
		writeln(e);
		return -1;
	}
	scope(failure) {
		writeln("Aborted.");
	}
	scope(success) {
		explain("Done.");
	}
	return 0;
}
