/*
CheeseCutter v2 (C) Abaddon. Licensed under GNU GPL.
*/

module com.cpu;

import std.stdio;
import std.string;

alias ushort address;

ubyte highbyte(ushort value) { return value >> 8; }
ubyte lowbyte(ushort value) { return value & 255; }
address toAddress(ubyte[] arr) { return arr[0] | (arr[1] << 8); }
ubyte[] toArr(address addr) { return [lowbyte(addr), highbyte(addr)]; }
alias toArr addr2arr;

class CPU {
protected:
	enum St { C = 1, Z = 2, I = 4, D = 8, B = 16, V = 64, N = 128 };
	enum Am { IMPLIED, IMMEDIATE, INDIRECT_X, INDIRECT_Y, IND, Z,
			RELATIVE, ACC, ABSOLUTE, ABSOLUTE_X, ABSOLUTE_Y, ZEROPAGE_X, ZY };
	static immutable int[] OPSIZE = [ 0, 1, 1, 1, 2, 1, 1,  0, 2, 2, 2, 1, 1 ];
	static string[] AMSTR = [
		"    \t", "    \t#$", "(,x)\t$", "(),y\t$", "()  \t$", "<z> \t$", "    \t+-", "    \ta", 
		"    \t$", ",x  \t$", ",y  \t$", ",xZ   \t$", ",yZ   \t$" ];
	enum Op { BRK = 0, ADC, AND, ASL, EOR, ORA, LSR, JSR, JMP, BIT, ROL, PHP, 
			PLP, PHA, RTI, BVC, CLI, RTS, ROR, PLA, BVS, SEI, STA, STY, STX, DEY, 
			TXA, BCC, TYA, TXS, LDY, LDA, LDX, TAY, TAX, BCS, CLV, TSX, CPY, CMP, 
			DEC, INY, DEX, BNE, CLD, CPX, SBC, INC, INX, NOP, BEQ, SED, BPL, BMI, 
			SEC, CLC };
	static string[] OPSTR = [
		"BRK", "ADC", "AND", "ASL", "EOR", "ORA", "LSR", "JSR", "JMP", "BIT", "ROL",
		"PHP", "PLP", "PHA", "RTI", "BVC", "CLI", "RTS", "ROR", "PLA", "BVS", "SEI",
		"STA", "STY", "STX", "DEY", "TXA", "BCC", "TYA", "TXS", "LDY", "LDA", "LDX",
		"TAY", "TAX", "BCS", "CLV", "TSX", "CPY", "CMP", "DEC", "INY", "DEX", "BNE",
		"CLD", "CPX", "SBC", "INC", "INX", "NOP", "BEQ", "SED", "BPL", "BMI", "SEC",
		"CLC" ];
	struct Opcode {
		Op op;
		Am am;
		int cyc;
	}
	static immutable Opcode[256] OPTAB = [
		{ Op.BRK, Am.IMPLIED, 8 }, { Op.ORA, Am.INDIRECT_X, 6 },  
		{ Op.BRK, Am.IMPLIED, 0 }, { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.ORA, Am.Z  , 3 },  
		{ Op.ASL, Am.Z  , 5 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.PHP, Am.IMPLIED, 3 },  { Op.ORA, Am.IMMEDIATE, 2 },  
		{ Op.ASL, Am.ACC, 2 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.ORA, Am.ABSOLUTE , 4 },  
		{ Op.ASL, Am.ABSOLUTE  , 6 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BPL, Am.RELATIVE, 2 },  { Op.ORA, Am.INDIRECT_Y, 5 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.ORA, Am.ZEROPAGE_X , 4 },  
		{ Op.ASL, Am.ZEROPAGE_X , 6 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.CLC, Am.IMPLIED, 2 },  { Op.ORA, Am.ABSOLUTE_Y , 4 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.ORA, Am.ABSOLUTE_X , 4 },  
		{ Op.ASL, Am.ABSOLUTE_X , 7 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.JSR, Am.ABSOLUTE , 6 },  { Op.AND, Am.INDIRECT_X, 6 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BIT, Am.Z  , 3 },  { Op.AND, Am.Z  , 3 },  
		{ Op.ROL, Am.Z  , 3 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.PLP, Am.IMPLIED, 4 },  { Op.AND, Am.IMMEDIATE, 2 },  
		{ Op.ROL, Am.ACC, 2 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BIT, Am.ABSOLUTE , 4 },  { Op.AND, Am.ABSOLUTE , 4 },  
		{ Op.ROL, Am.ABSOLUTE , 4 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BMI, Am.RELATIVE, 2 },  { Op.AND, Am.INDIRECT_Y, 5 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.AND, Am.ZEROPAGE_X , 4 }, 
		{ Op.ROL, Am.ZEROPAGE_X , 6 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.SEC, Am.IMPLIED, 2 },  { Op.AND, Am.ABSOLUTE_Y , 4 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.AND, Am.ABSOLUTE_X , 4 }, 
		{ Op.ROL, Am.ABSOLUTE_X , 7 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.RTI, Am.IMPLIED, 7 },  { Op.EOR, Am.INDIRECT_X, 6 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.EOR, Am.Z  , 3 },  
		{ Op.LSR, Am.Z  , 5 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.PHA, Am.IMPLIED, 3 },  { Op.EOR, Am.IMMEDIATE, 2 },  
		{ Op.LSR, Am.ACC, 2 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.JMP, Am.ABSOLUTE , 3 },  { Op.EOR, Am.ABSOLUTE , 4 },  
		{ Op.LSR, Am.ABSOLUTE , 6 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BVC, Am.RELATIVE, 2 },  { Op.EOR, Am.INDIRECT_Y, 5 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.EOR, Am.ZEROPAGE_X , 4 },  
		{ Op.LSR, Am.ZEROPAGE_X , 6 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.CLI, Am.IMPLIED, 2 },  { Op.EOR, Am.ABSOLUTE_Y , 4 },  
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.EOR, Am.ABSOLUTE_X , 4 },  
		{ Op.LSR, Am.ABSOLUTE_X , 7 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.RTS, Am.IMPLIED, 6 },  { Op.ADC, Am.ZEROPAGE_X , 6 },  
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.ADC, Am.Z  , 3 },  
		{ Op.ROR, Am.Z  , 5 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.PLA, Am.IMPLIED, 4 },  { Op.ADC, Am.IMMEDIATE, 2 },  
		{ Op.ROR, Am.ACC, 2 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.JMP, Am.IND, 5 },  { Op.ADC, Am.ABSOLUTE , 4 },  
		{ Op.ROR, Am.ABSOLUTE , 6 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BVS, Am.RELATIVE, 2 },  { Op.ADC, Am.ZY , 5 },  
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.ADC, Am.ZEROPAGE_X , 4 },  
		{ Op.ROR, Am.ZEROPAGE_X , 6 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.SEI, Am.IMPLIED, 2 },  { Op.ADC, Am.ABSOLUTE_Y , 4 },  
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.ADC, Am.ABSOLUTE_X , 4 },  
		{ Op.ROR, Am.ABSOLUTE_X , 7 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.STA, Am.INDIRECT_X, 6 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.STY, Am.Z  , 3 },  { Op.STA, Am.Z  , 3 },  
		{ Op.STX, Am.Z  , 3 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.DEY, Am.IMPLIED, 2 },  { Op.BRK, Am.IMPLIED, 4 },  
		{ Op.TXA, Am.IMPLIED, 2 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.STY, Am.ABSOLUTE , 4 },  { Op.STA, Am.ABSOLUTE , 4 },  
		{ Op.STX, Am.ABSOLUTE , 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BCC, Am.RELATIVE, 4 },  { Op.STA, Am.INDIRECT_Y, 4 },  
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.STY, Am.ZEROPAGE_X , 4 },  { Op.STA, Am.ZEROPAGE_X , 4 },  
		{ Op.STX, Am.ZY , 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.TYA, Am.IMPLIED, 2 },  { Op.STA, Am.ABSOLUTE_Y , 5 },  
		{ Op.TXS, Am.IMPLIED, 2 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.STA, Am.ABSOLUTE_X , 5 },  
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.LDY, Am.IMMEDIATE, 2 },  { Op.LDA, Am.INDIRECT_X, 6 },  
		{ Op.LDX, Am.IMMEDIATE, 2 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.LDY, Am.Z  , 3 },  { Op.LDA, Am.Z  , 3 },  
		{ Op.LDX, Am.Z  , 3 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.TAY, Am.IMPLIED, 2 },  { Op.LDA, Am.IMMEDIATE, 2 },  
		{ Op.TAX, Am.IMPLIED, 2 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.LDY, Am.ABSOLUTE , 4 },  { Op.LDA, Am.ABSOLUTE , 4 },  
		{ Op.LDX, Am.ABSOLUTE , 4 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BCS, Am.RELATIVE, 2 },  { Op.LDA, Am.INDIRECT_Y, 5 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.LDY, Am.ZEROPAGE_X , 4 },  { Op.LDA, Am.ZEROPAGE_X , 4 },  
		{ Op.LDX, Am.ZEROPAGE_X , 4 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.CLV, Am.IMPLIED, 2 },  { Op.LDA, Am.ABSOLUTE_Y , 4 },  
		{ Op.TSX, Am.IMPLIED, 2 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.LDY, Am.ABSOLUTE_X , 4 },  { Op.LDA, Am.ABSOLUTE_X , 4 },  
		{ Op.LDX, Am.ABSOLUTE_Y , 4 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.CPY, Am.IMMEDIATE, 2 },  { Op.CMP, Am.INDIRECT_X, 6 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.CPY, Am.Z  , 3 },  { Op.CMP, Am.Z  , 3 },  
		{ Op.DEC, Am.Z  , 5 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.INY, Am.IMPLIED, 2 },  { Op.CMP, Am.IMMEDIATE, 2 },  
		{ Op.DEX, Am.IMPLIED, 2 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.CPY, Am.ABSOLUTE , 4 },  { Op.CMP, Am.ABSOLUTE , 4 },  
		{ Op.DEC, Am.ABSOLUTE , 4 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BNE, Am.RELATIVE, 2 },  { Op.CMP, Am.INDIRECT_Y, 5 },  
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.CMP, Am.ZEROPAGE_X , 4 },  
		{ Op.DEC, Am.ZEROPAGE_X , 6 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.CLD, Am.IMPLIED, 2 },  { Op.CMP, Am.ABSOLUTE_Y , 4 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.CMP, Am.ABSOLUTE_X , 4 },  
		{ Op.DEC, Am.ABSOLUTE_X , 7 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.CPX, Am.IMMEDIATE, 2 },  { Op.SBC, Am.INDIRECT_X, 6 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.CPX, Am.Z  , 3 },  { Op.SBC, Am.Z  , 3 },  
		{ Op.INC, Am.Z  , 5 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.INX, Am.IMPLIED, 2 },  { Op.SBC, Am.IMMEDIATE, 2 },  
		{ Op.NOP, Am.IMPLIED, 2 },  { Op.SBC, Am.IMMEDIATE, 2 }, 
		{ Op.CPX, Am.ABSOLUTE , 4 },  { Op.SBC, Am.ABSOLUTE , 4 },  
		{ Op.INC, Am.ABSOLUTE , 6 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BEQ, Am.RELATIVE, 2 },  { Op.SBC, Am.INDIRECT_Y, 5 },  
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.BRK, Am.IMPLIED, 0 },  { Op.SBC, Am.ZEROPAGE_X , 4 },  
		{ Op.INC, Am.ZEROPAGE_X , 6 },  { Op.BRK, Am.IMPLIED, 0 }, 
		{ Op.SED, Am.IMPLIED, 2 },  { Op.SBC, Am.ABSOLUTE_Y , 4 },  
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.BRK, Am.IMPLIED, 4 }, 
		{ Op.BRK, Am.IMPLIED, 4 },  { Op.SBC, Am.ABSOLUTE_X , 4 },  
		{ Op.INC, Am.ABSOLUTE_X , 7 },  { Op.BRK, Am.IMPLIED, 2 } ]; 
		
	struct State {
		int opcode, realop, addrmode, arg, value, cyc;
		ubyte[] chunk;
	}
	struct Regs {
		ubyte a, x, y, st, sp;
		address pc;
	}
	int counter;
	ubyte[] memory;
public:
	Regs regs;

	this(ubyte[] m) { reset(); memory = m; }
	void reset() {
		regs.a = regs.x = regs.y = 0;
		regs.sp = 255;
		regs.st = 32;
	}
	// execute a 6502 subroutine, return number of cycles used
	int execute(ushort addr) {
		return execute(addr, false);
	}
	
	int execute(ushort addr, bool d) {
		stPush(0);
		stPush(0);
		regs.pc = addr;
		counter = 0;
		while(regs.pc > 0 && !(regs.st & St.B)) {
			run(d);
		}
		return counter;
	}

protected:
	
	/* execute a 6502 instruction
	 * d indicates that ML monitor output is required
	 * returns the number of cycles
	 */
	int run(bool d) {
		string s;
		address pc;
		State state;

		state = decode();
		if(regs.pc >= 0xfffd) 
			throw new CPUException(this, "program counter overflow!");
		int oldpc = regs.pc;
		executeOp(state);
		counter += state.cyc;

		if(d) {
			int addrmode, arg, value, opcode;
			opcode = state.opcode;
			addrmode = state.addrmode;
			arg = state.arg;
			value = state.value;
		
			s = dumpRegs();
			if(OPSIZE[addrmode] == 0) {
				writefln(format("$%04x\t$%02X\t%s\t\t\t\t%s c=%x C=$%04X", oldpc, 
								state.realop, OPSTR[opcode], s, state.cyc, counter));
			}
			else {
				writefln(format("$%04x\t$%02X\t%s%s%02x\t\t\t%s c=%x C=$%04X", 
								oldpc, state.realop, OPSTR[opcode], 
								AMSTR[addrmode], arg, s, state.cyc, counter));
			}
		}
		if(regs.st & St.B) return state.cyc;
		return state.cyc;
	}

	void dumpOpcode(ref State state) {
		int addrmode, arg, value, opcode;
		opcode = state.opcode;
		addrmode = state.addrmode;
		arg = state.arg;
		value = state.value;
		
		string s = dumpRegs();
		if(OPSIZE[addrmode] == 0) {
			writefln(format("$%04x\t$%02X\t%s\t\t\t\t%s c=%x C=$%04X", regs.pc, 
							state.realop, OPSTR[opcode], s, state.cyc, counter));
		}
		else {
			writefln(format("$%04x\t$%02X\t%s%s%02x\t\t\t%s c=%x C=$%04X", 
							regs.pc, state.realop, OPSTR[opcode], 
							AMSTR[addrmode], arg, s, state.cyc, counter));
		}
		
	}


	void dumpline(ref State state) {
	}

	string dumpRegs() {
		return format("PC=$%04x A=$%02x X=$%02x Y=$%02x SP=$%02x ST=$%02x" ,
					  regs.pc, regs.a, regs.x,regs.y,regs.sp,regs.st); 
	}

	void setST(ubyte value) {
		regs.st &= (255 - St.N - St.Z);
		regs.st |= value & St.N;
		if (!value) 
			regs.st |= St.Z;
	}
	
	void regWrite(ref ubyte reg, ushort value) {
		reg = cast(ubyte)value;
		setST(cast(ubyte)value);
	}

	void regWrite(ref ubyte reg, ubyte value) {
		reg = value;
		setST(value);
	}
	alias regWrite set;

	void stPush(ubyte val) {
		memory[0x100 + regs.sp] = val;
		regs.sp--;
	}

	ubyte stPull() {
		regs.sp++;
		return memory[0x100 + regs.sp];
	}

	/* prints cpu status and a message from player
	 * message format:
	 * [info byte] [data....]
	 * info byte: $00-$7f number of bytes to dump/string length
	 * 8th bit ON = output string, else output bytes
	 */
	void handleBreak() {
		/+
		fprintf(stdout, toStringz(dumpRegs() ~ " ( "));
		int info = memory[0xdf00];
		if(info) {
			for(int i=0; i < (info & 0x7f); i++) {
				if(!(info & 0x80)) {
					fprintf(stdout,"$%02x ", memory[0xdf01 + i]);
				}
			}
		}
		fprintf(stdout, ")               ");
		if(!(info & 0x80))
			fprintf(stdout,"\n");
			+/
		throw new CPUException(this, "BRK");
	}

	void executeOp(ref State stat) {
		int arg = stat.arg;
		ushort value = cast(ushort)stat.value;
		int acc;
		int am = stat.addrmode; 
		int p = regs.pc;
		regs.pc += 1 + OPSIZE[stat.addrmode];
		switch(stat.opcode)
		{
		case Op.BRK:
			 handleBreak();
			 regs.st |= St.B;
			 break;
	    case Op.SEI:
			regs.st |= St.I;
			break;
	    case Op.CLI:
			regs.st &= 255 - St.I;
			break;
	    case Op.CLC:
			regs.st &= 255 - St.C;
			break;
	    case Op.SEC:
			regs.st |= St.C;
			break;
	    case Op.CLV:
			regs.st &= 255 - St.V;
			break;
	    case Op.SED:
			regs.st |= St.D;
			throw new CPUException(this,"Decimal mode not supported");
	    case Op.CLD:
			regs.st &= 255 - St.D;
			break;
	    case Op.LDA:
			set(regs.a, value);
			break;
	    case Op.LDX:
			set(regs.x, value);
			break;
	    case Op.LDY:
			set(regs.y, value);
			break;
	    case Op.INX:
			set(regs.x, (regs.x + 1) & 255);
			break;
	    case Op.INY:
			set(regs.y, (regs.y + 1) & 255);
			break;
	    case Op.DEX:
			set(regs.x, (regs.x - 1) & 255);
			break;
	    case Op.DEY:
			set(regs.y, (regs.y - 1) & 255);
			break;
	    case Op.TAX:
			set(regs.x, regs.a);
			break;
	    case Op.TXA:
			set(regs.a, regs.x);
			break;
	    case Op.TAY:
			set(regs.y, regs.a);
			break;
	    case Op.TYA:
			set(regs.a, regs.y);
			break;
	    case Op.PHA:
			stPush(regs.a);
			break;
	    case Op.PLA:
			set(regs.a, stPull());
			break;
	    case Op.PHP:
			stPush(regs.st);
			break;
	    case Op.PLP:
			regs.st = stPull();
			break;
	    case Op.TSX:
			set(regs.x,regs.sp);
			break;
	    case Op.TXS:
			regs.sp = regs.x;
			break;
	    case Op.STA:
			write(stat, am, arg, regs.a);
			break;
	    case Op.STX:
			write(stat, am, arg, regs.x);
			break;
	    case Op.STY:
			write(stat, am, arg, regs.y);
			break;
	    case Op.BIT:
			ubyte st;
			st = regs.st;
			st &= 0xff - St.N - St.V - St.Z;
			st |= value & 0xc0;
			if (!regs.a & value) 
				st |= St.Z;
			regs.st = st;
			break;
	    case Op.BEQ:
			if (regs.st & St.Z) {
				regs.pc = value;
				stat.cyc++;
			}
			break;
	    case Op.BNE:
			if (!(regs.st & St.Z)) {
				regs.pc = value;
				stat.cyc++;
			}
			break;
	    case Op.BPL:
			if (!(regs.st & St.N)) {
				regs.pc = value;
				stat.cyc++;
			}
			break;
	    case Op.BMI:
			if (regs.st & St.N) {
				regs.pc = value;
				stat.cyc++;
			}
			break;
	    case Op.BCC:
			if (!(regs.st & St.C)) {
				regs.pc = value;
				stat.cyc++;
			}
			break;
	    case Op.BCS:
			if (regs.st & St.C) {
				regs.pc = value;
				stat.cyc++;
			}
			break;
	    case Op.BVC:
			if (!(regs.st & St.V)) {
				regs.pc = value;
				stat.cyc++;
			}
			break;
	    case Op.BVS:
			if (regs.st & St.V) {
				regs.pc = value;
				stat.cyc++;
			}
			break;
	    case Op.JMP:
			if (am == Am.IND)
				regs.pc = value;
			else
				regs.pc = cast(ushort)arg;
			break;
	    case Op.JSR:
			int pc = regs.pc;
			stPush(cast(ubyte)(pc >> 8)); // wrong byte order?
			stPush(cast(ubyte)(pc & 255));
			regs.pc = cast(ushort)arg;
			break;
	    case Op.RTS:
			regs.pc = (stPull())| (stPull() << 8);
			break;
	    case Op.RTI:
			// need to change "I" flag?
			regs.st = stPull();
			regs.pc = (stPull() << 8) | stPull();
			break;
	    case Op.ASL:
			acc = value << 1;
			regs.st &= 255 - St.C;
			regs.st |= (acc >> 8) & St.C;
			setST(acc & 255);
			write(stat, am,arg,acc &255);
			break;
	    case Op.LSR:
			acc = value;
			regs.st &= 255 - St.C;
			regs.st |= acc & St.C;
			acc = acc >> 1;
			setST(acc & 255);
			write(stat,am,arg,acc & 255);
			break;
	    case Op.ROL:
			acc = value << 1;
			acc |= regs.st & St.C;
			regs.st &= 255 - St.C;
			regs.st |= (acc >> 8) & St.C;
			setST(acc & 255);
			write(stat,am,arg,acc & 255);
			break;
	    case Op.ROR:
			ubyte st;
			acc = value;
			st = regs.st;
			regs.st &= 255 - St.C;
			regs.st |= acc & St.C;
			acc = acc >> 1;
			acc |= (st & St.C) << 7;
			setST(acc & 255);
			write(stat,am,arg,acc & 255);
			break;
	    case Op.ADC:
			int t;
			t = regs.a + (regs.st & St.C) + value;
			regs.st &= 255 - St.C;
			regs.st |= ((t >> 8) & St.C);
			set(regs.a,t & 255);
			break;
	    case Op.SBC:
			int t;
			t = regs.a - value - !(regs.st & St.C);
			regs.st &= 255 - St.C;
			//regs.st |= value > regs.a ? 0 : St.C;
			regs.st |= t < 0 ? 0 : St.C;			
			set(regs.a,t & 255);
			break;
	    case Op.CMP:
			int t;
			t = regs.a - value;
			regs.st &= 255 - St.C;
			//regs.st |= value > regs.a ? 0 : St.C;
			regs.st |= t < 0 ? 0 : St.C;
			setST(t & 255);
			break;
	    case Op.CPX:
			int t;
			t = regs.x - value;
			regs.st &= 255 - St.C;
			//regs.st |= value > regs.x ? 0 : St.C;
			regs.st |= t < 0 ? 0 : St.C;
			setST(t & 255);
			break;
	    case Op.CPY:
			int t;
			t = regs.y - value;
			regs.st &= 255 - St.C;
			regs.st |= value > regs.y ? 0 : St.C;
			//regs.st |= value > regs.y ? 0 : St.C;
			regs.st |= t < 0 ? 0 : St.C;
			setST(t & 255);			
			break;
	    case Op.INC:
			write(stat,am,arg,(value + 1) & 255);
			setST(cast(ubyte)(value+1));
			break;
	    case Op.DEC:
			write(stat,am,arg,(value - 1) & 255);
			setST(cast(ubyte)(value-1));
			break;
	    case Op.AND:
			ubyte t;
			t = regs.a & value;
			set(regs.a,t);
			break;
	    case Op.EOR:
			acc = regs.a ^ value;
			set(regs.a,acc & 255);
			break;
	    case Op.ORA:
			acc = regs.a | value;
			set(regs.a,acc & 255);
			break;
	    case Op.NOP:
			break;
	    default: 
			throw new CPUException(this,"Illegal instruction");
	    }
	}

    address fetchAddress(ref State st) {
        int am = st.addrmode;
        ushort arg = cast(ushort)st.arg;
        switch(am)
        {
        case Am.ABSOLUTE_X:
            return (arg + regs.x) & 65535;
        case Am.ZY, Am.ABSOLUTE_Y:
            return (arg + regs.y) & 65535;
        case Am.ZEROPAGE_X:
            return (arg + regs.x) & 255;
        case Am.Z:
            return arg & 255;
        case Am.ABSOLUTE:
            return arg;
        case Am.INDIRECT_Y:
            return cast(address)(toAddress(memory[(arg & 0xff) .. (arg & 0xff) + 2]) + regs.y);
        default:
            throw new CPUException(this,format("Illegal addressing mode %d", am));
        }
        assert(0);
    }

	ushort fetch(ref State st) {
		int am = st.addrmode;
        ubyte arg = cast(ubyte)st.arg;
        switch(am)
        {
        case Am.IMPLIED:
            return 0;
        case Am.IMMEDIATE:
            return arg;
        case Am.ABSOLUTE_X,
			Am.ZY, Am.ABSOLUTE_Y,
			Am.ZEROPAGE_X,
			Am.Z,
			Am.ABSOLUTE,
			Am.INDIRECT_Y:
            return memory[fetchAddress(st)];
        case Am.ACC:
            return regs.a;
        case Am.RELATIVE:
            return cast(ushort)(regs.pc + (arg >= 128 ? -256 + arg : arg) + 2);
        case Am.INDIRECT_X:
            throw new CPUException(this,"(indexed,x) not implemented");
        default:
            throw new CPUException(this,format("Illegal addressing mode %d", am));
        }                                                                                                                           
        assert(0);
    }

	State decode() {
		static State st;
		Opcode ops;

		st.chunk = memory[regs.pc .. regs.pc + 3];
		ops = OPTAB[st.chunk[0]];
		st.realop = st.chunk[0];
		st.opcode = cast(int)ops.op;
		st.addrmode = cast(int)ops.am;
		st.cyc = cast(int)ops.cyc;
		st.arg = 0;
		if(OPSIZE[st.addrmode] == 1) {
			st.arg = st.chunk[1];
		}
		else if(OPSIZE[st.addrmode] == 2) {
			st.arg = st.chunk[1] | (st.chunk[2] << 8);
		}
		st.value = fetch(st);
		return st;
	}

    void write(ref State stat, int am, int arg, ubyte val) {
        switch(am)
        {
        case Am.Z:
        case Am.ZEROPAGE_X:
        case Am.ABSOLUTE:
        case Am.ABSOLUTE_X:
        case Am.ABSOLUTE_Y:
        case Am.INDIRECT_Y:
            memory[fetchAddress(stat)] = val;
            return;
        case Am.ACC:
            regs.a = val;
            break;
        case Am.INDIRECT_X:
            throw new CPUException(this,"(indexed,x) not implemented");
        default:
            throw new CPUException(this,format("Unsupported addrmode %d",am));
        }
    }
}

class CPUException : Exception {
	CPU cpu;
	this(CPU cpu, string msg) {
		super("CPU error: " ~ msg ~ " (" ~ cpu.dumpRegs() ~ ")");
		this.cpu = cpu;
	}

	override string toString() {
		return msg;
	}
}
