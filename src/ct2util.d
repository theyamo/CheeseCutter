/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

import com.cpu;
import com.util;
import ct.base;
import ct.purge;
import ct.dump;
import ct.build;
import std.stdio;
import std.string;
import std.conv;

enum Command { None, ExportPRG, ExportSID, Dump, Import, Init }
const string[] exts = [ "", "prg", "sid", "s", "ct", "ct" ];

bool verbose = true;
bool noPurge;

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

bool doPurge(ref Song song) {
	if(noPurge) return true;
	explain("Purging data...");
	Purge p = new Purge(song, verbose);
	try {
		p.purgeAll();
	}
	catch(PurgeException e) {
		writeln(e);
		return false;
	}
	return true;
}

void validate(ref Song song) {
	explain("Checking validity...");
	for(int i = 0; i < song.numInstr; i++) {
		//ubyte[] instr = song.getInstrument(i);
		int waveptr = song.wavetablePointer(i);
		int pulseptr = song.pulsetablePointer(i);
		int filtptr = song.filtertablePointer(i);
		if(!song.tWave.isValid(waveptr)) {
			throw new ValidateException(format("Error: instrument %d is not valid (wavetable does not wrap).", i));
		}
		
		if(!song.tPulse.isValid(pulseptr)) {
			throw new ValidateException(format("Cannot save; pulse %d is not valid.", pulseptr));
		}
		
		if(!song.tFilter.isValid(filtptr)) {
			throw new ValidateException(format("Cannot save; filter %d is not valid.", filtptr));
		}

		song.seqIterator((int seqno, Sequence s, Element e) {
				if(e.cmd.value >= 0x80 && e.cmd.value <= 0x9f) {
					int idx = song.chordIndexTable[e.cmd.value & 0x1f];
					for(int i = idx; i < 128; i++) {
						if(song.chordTable[i] >= 0x80) return;
					}
					throw new ValidateException(format("sequence $%02x, could not find end for chord %x. The song has a 8x command pointing to nonexistant chord program.", seqno, e.cmd.value & 0x1f));
					
				}
			});
		
	}
}

class ValidateException : Exception {
	this(string msg) {
		super(msg);
	}

	override string toString() {
		return "Validation error: " ~ msg;
	}
}

int main(string[] args) {
	int relocAddress = 0x1000, zpAddress = 0;
	int[] speeds, masks;

	// these two use PSID ranges (1..32)
	int defaultTune = 1, singleSubtune = -1;
	
	bool outfnDefined = false, infnDefined = false;
	int command;
	Song insong;
	string infn, outfn;
	string[3] infns;

	speeds.length = 32;
	masks.length = 32;
	void printheader() {
		enum hdr = "CheeseCutter 2 utilities" ~ com.util.versionInfo;
		writefln(hdr);
		writefln("\nUsage: \t%s <command> <options> <infile> <-o outfile>",args[0]);
		writefln("\t%s import <infile> <infile2> <-o outfile>",args[0]);
		writefln("\t%s init <binaryfile> <-o outfile>",args[0]);
		writefln("\nCommands:");
		writefln("  prg           Export song (.ct) to PRG file");
		writefln("  sid           Export song (.ct) to SID file");
		writefln("  import        Copy data from another song without overwriting the player");
		writefln("\nGeneral options:");
		writefln("  -o <outfile>  Set output filename (by default gathered from input filename)");
		writefln("\nExport options:");
		writefln("  -r <addr>     Relocate output to address (default = $1000)");
		writefln("  -d <num>      Set the default subtune (1-" ~ to!string(ct.base.SUBTUNE_MAX) ~ ")");
//		writefln("  -s [subtune]:[speed],...    Set speeds for subtunes");
//		writefln("  -c [subtune]:[voicemask],...Set voice bitmasks for subtunes");
		writefln("  -s <num>      Export single subtune (1-" ~ to!string(ct.base.SUBTUNE_MAX) ~ ") (disables -d)");
		writefln("  -zp <num>     Relocate zero page (valid range 2-$fe)");
		writefln("  -q            Don't output information");
		writefln("\nPrefix value options with '0x' or '$' to indicate a hexadecimal value.");
	}

	if(args.length < 2) {
		printheader();
		return 0;
	}

	try {
		switch(args[1]) {
		case "prg", "buildprg":
			command = Command.ExportPRG;
			break;
		case "sid", "build":
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
					   command != Command.ExportPRG)
						throw new UserException("Option available only with exporting commands.");
					int r = str2Value2(nextArg());
					if(r < 0x200 || r > 0xf900)
						throw new UserException("-r: reloc address out of range");
					relocAddress = cast(ushort)r;
					break;
				case "-s":
					if(command != Command.ExportSID &&
					   command != Command.ExportPRG)
						throw new UserException("Option available only with exporting commands.");
					//parseList(speeds, nextArg());
					int value = str2Value2(nextArg());
					if(value < 1 || value > ct.base.SUBTUNE_MAX)
						throw new UserException(format("Valid range for subtunes is 1 - %d.", ct.base.SUBTUNE_MAX));
					singleSubtune = value;
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
					defaultTune = str2Value2(nextArg());
					if(defaultTune < 1 || defaultTune > ct.base.SUBTUNE_MAX)
						throw new UserException(format("Valid range for subtunes is 1 - %d.", ct.base.SUBTUNE_MAX));
					break;
				case "-z", "-zp":
					if(command != Command.ExportSID &&
					   command != Command.ExportPRG)
						throw new UserException("Option available only with exporting commands.");
					zpAddress = str2Value2(nextArg());
					if(zpAddress < 2 || zpAddress > 0xfe) {
						throw new UserException("Valid range for zero page is 2 - $fe");
					}
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
			if(insong.ver < 128)
				throw new UserException("Use this version for StereoSID tunes only");
			if(singleSubtune >= 0) {
				throw new UserException("-s currently works only on regular sids");
			}
			if(!doPurge(insong)) {
				writeln("Aborting");
				return -1;
			}
			try {
				validate(insong);
			}
			catch(ValidateException e) {
				writeln(e);
				writeln("Aborting");
				return -1;
			}
				
				
			ubyte[] data = doBuild(insong, relocAddress, zpAddress,
								   command == Command.ExportSID,
								   defaultTune, verbose);
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
			string dumped = dumpOptimized(insong, 0x1000, 0, true,
										  verbose);
			string header = format(";;; ACME dump for %s\n\n", infn);
			std.file.write(outfn, header ~ dumped);
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
