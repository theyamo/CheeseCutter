//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Mnemonics stuff

#include "config.h"
#include "alu.h"
#include "cpu.h"
#include "dynabuf.h"
#include "global.h"
#include "input.h"
#include "output.h"
#include "tree.h"


// Constants
#define s_ror	(s_error+2)	// Yes, I know I'm sick
#define MNEMO_DYNABUF_INITIALSIZE	8	// 4+terminator should suffice

// These values are needed to recognize addressing modes.
// Bits:
// 7....... "Implied"		no value given
// .6...... "Immediate"		"#" at start
// ..5..... "IndirectLong"	"[" at start and "]" after value
// ...4.... "Indirect"		Value has at least one unnecessary pair of "()"
// ....32.. "Indexed-Int"	Index given inside of "()"
// ......10 "Indexed-Ext"	Index given outside of (or without any) "()"
//
// Index bits:
//	00 = no index
//	01 = ",s"	(Stack-indexed)
//	10 = ",x"	(X-indexed)
//	11 = ",y"	(Y-indexed)

// Components (Values for indices)
#define HAM__	(0u << 0)	// No index
#define HAM_S	(1u << 0)	// Stack-indexed
#define HAM_X	(2u << 0)	// X-indexed
#define HAM_Y	(3u << 0)	// Y-indexed

// End values		base value	internal index	external index
#define HAM_IMP		(1u << 7)
#define HAM_IMM		(1u << 6)
#define HAM_ABS		0
#define HAM_ABSS					(1u << 0)
#define HAM_ABSX					(2u << 0)
#define HAM_ABSY					(3u << 0)
#define HAM_IND		(1u << 4)
#define HAM_XIND	((1u << 4)|	(2u << 2))
#define HAM_INDY	((1u << 4)|			(3u << 0))
#define HAM_SINDY	((1u << 4)|	(1u << 2)|	(3u << 0))
#define HAM_LIND	(1u << 5)
#define HAM_LINDY	((1u << 5)|			(3u << 0))
// Values of internal indices equal values of external indices, shifted left
// by two bits. The program relies on this !

// Constant values, used to mark the possible parameter lengths of commands.
// Not all of the eight values are actually used, however (because of the
// supported CPUs).
#define MAYBE______	(0)
#define MAYBE_1____	(MVALUE_FORCE08)
#define MAYBE___2__	(MVALUE_FORCE16)
#define MAYBE_1_2__	(MVALUE_FORCE08 | MVALUE_FORCE16)
#define MAYBE_____3	(MVALUE_FORCE24)
#define MAYBE_1___3	(MVALUE_FORCE08 | MVALUE_FORCE24)
#define MAYBE___2_3	(MVALUE_FORCE16 | MVALUE_FORCE24)
#define MAYBE_1_2_3	(MVALUE_FORCE08 | MVALUE_FORCE16 | MVALUE_FORCE24)

// The mnemonics are split up into groups, each group has its own function to
// be dealt with:
// G_IMPLIED	Mnemonics using only implied addressing.    Byte value = opcode
// G_MAIN	The main accumulator stuff (plus PEI)  Byte value = table index
// G_MISC	Most of the other opcodes	       Byte value = table index
// G_REL_SHORT	The short branch instructions.              Byte value = opcode
// G_REL_LONG	Mnemonics with 16bit relative addressing.   Byte value = opcode
// G_JUMP	The jump instructions		       Byte value = table index
// G_MOVE	The "move" commands.			    Byte value = opcode
enum mnemogroup_t {
	G_IMPLIED,	// only implied addressing
	G_MAIN,		// main accumulator stuff (plus PEI)
	G_MISC,		// misc
	G_REL_SHORT,	// short relative
	G_REL_LONG,	// long relative
	G_JUMP,		// jump
	G_MOVE		// MVP, MVN
};

// save some space
#define SCB	static const unsigned char
#define SCS	static const unsigned short
#define SCL	static const unsigned long

// Code tables for group G_MAIN:
// These tables are used for the main accumulator-related mnemonics. By reading
// the mnemonic's byte value (from the mnemotable), the assembler finds out the
// column to use here. The row depends on the used addressing mode. A zero
// entry in these tables means that the combination of mnemonic and addressing
// mode is illegal.
enum {	IDX_ORA,  IDX_AND,  IDX_EOR,  IDX_ADC,  IDX_STA,  IDX_LDA,  IDX_CMP,  IDX_SBC,
	IDXC_ORA, IDXC_AND, IDXC_EOR, IDXC_ADC, IDXC_STA, IDXC_LDA, IDXC_CMP, IDXC_SBC,
	IDX8_ORA, IDX8_AND, IDX8_EOR, IDX8_ADC, IDX8_STA, IDX8_LDA, IDX8_CMP, IDX8_SBC, IDX8_PEI,
	IDXI_SLO, IDXI_RLA, IDXI_SRE, IDXI_RRA, IDXI_SAX, IDXI_LAX, IDXI_DCP, IDXI_ISC};
//		    |                         6502                          |                         65c02                         |                                    65816                                   |                          6510                         |
//		    |   ora    and    eor    adc    sta    lda    cmp    sbc|   ora    and    eor    adc    sta    lda    cmp    sbc|     ora      and      eor      adc      sta      lda      cmp      sbc  pei|   slo    rla    sre    rra    sax    lax    dcp    isc|
SCB accu_imm[]    = {  0x09,  0x29,  0x49,  0x69,     0,  0xa9,  0xc9,  0xe9,  0x09,  0x29,  0x49,  0x69,     0,  0xa9,  0xc9,  0xe9,    0x09,    0x29,    0x49,    0x69,       0,    0xa9,    0xc9,    0xe9,   0,     0,     0,     0,     0,     0,     0,     0,     0};// #$ff/#$ffff
SCB accu_sabs8[]  = {     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,    0x03,    0x23,    0x43,    0x63,    0x83,    0xa3,    0xc3,    0xe3,   0,     0,     0,     0,     0,     0,     0,     0,     0};// $ff,s
SCB accu_xind8[]  = {  0x01,  0x21,  0x41,  0x61,  0x81,  0xa1,  0xc1,  0xe1,  0x01,  0x21,  0x41,  0x61,  0x81,  0xa1,  0xc1,  0xe1,    0x01,    0x21,    0x41,    0x61,    0x81,    0xa1,    0xc1,    0xe1,   0,  0x03,  0x23,  0x43,  0x63,  0x83,  0xa3,  0xc3,  0xe3};// ($ff,x)
SCB accu_sindy8[] = {     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,    0x13,    0x33,    0x53,    0x73,    0x93,    0xb3,    0xd3,    0xf3,   0,     0,     0,     0,     0,     0,     0,     0,     0};// ($ff,s),y
SCB accu_ind8[]   = {     0,     0,     0,     0,     0,     0,     0,     0,  0x12,  0x32,  0x52,  0x72,  0x92,  0xb2,  0xd2,  0xf2,    0x12,    0x32,    0x52,    0x72,    0x92,    0xb2,    0xd2,    0xf2,0xd4,     0,     0,     0,     0,     0,     0,     0,     0};// ($ff)
SCB accu_indy8[]  = {  0x11,  0x31,  0x51,  0x71,  0x91,  0xb1,  0xd1,  0xf1,  0x11,  0x31,  0x51,  0x71,  0x91,  0xb1,  0xd1,  0xf1,    0x11,    0x31,    0x51,    0x71,    0x91,    0xb1,    0xd1,    0xf1,   0,  0x13,  0x33,  0x53,  0x73,     0,  0xb3,  0xd3,  0xf3};// ($ff),y
SCB accu_lind8[]  = {     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,    0x07,    0x27,    0x47,    0x67,    0x87,    0xa7,    0xc7,    0xe7,   0,     0,     0,     0,     0,     0,     0,     0,     0};// [$ff]
SCB accu_lindy8[] = {     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,    0x17,    0x37,    0x57,    0x77,    0x97,    0xb7,    0xd7,    0xf7,   0,     0,     0,     0,     0,     0,     0,     0,     0};// [$ff],y
SCL accu_abs[]    = {0x0d05,0x2d25,0x4d45,0x6d65,0x8d85,0xada5,0xcdc5,0xede5,0x0d05,0x2d25,0x4d45,0x6d65,0x8d85,0xada5,0xcdc5,0xede5,0x0f0d05,0x2f2d25,0x4f4d45,0x6f6d65,0x8f8d85,0xafada5,0xcfcdc5,0xefede5,   0,0x0f07,0x2f27,0x4f47,0x6f67,0x8f87,0xafa7,0xcfc7,0xefe7};// $ff  /$ffff  /$ffffff
SCL accu_xabs[]   = {0x1d15,0x3d35,0x5d55,0x7d75,0x9d95,0xbdb5,0xddd5,0xfdf5,0x1d15,0x3d35,0x5d55,0x7d75,0x9d95,0xbdb5,0xddd5,0xfdf5,0x1f1d15,0x3f3d35,0x5f5d55,0x7f7d75,0x9f9d95,0xbfbdb5,0xdfddd5,0xfffdf5,   0,0x1f17,0x3f37,0x5f57,0x7f77,     0,     0,0xdfd7,0xfff7};// $ff,x/$ffff,x/$ffffff,x
SCS accu_yabs[]   = {0x1900,0x3900,0x5900,0x7900,0x9900,0xb900,0xd900,0xf900,0x1900,0x3900,0x5900,0x7900,0x9900,0xb900,0xd900,0xf900,  0x1900,  0x3900,  0x5900,  0x7900,  0x9900,  0xb900,  0xd900,  0xf900,   0,0x1b00,0x3b00,0x5b00,0x7b00,  0x97,0xbfb7,0xdb00,0xfb00};// $ff,y/$ffff,y

// Code tables for group G_MISC:
// These tables are needed for finding out the correct code in cases when
// there are no general rules. By reading the mnemonic's byte value (from the
// mnemotable), the assembler finds out the column to use here. The row
// depends on the used addressing mode. A zero entry in these tables means
// that the combination of mnemonic and addressing mode is illegal.
enum {	IDX_BIT,  IDX_ASL,  IDX_ROL,  IDX_LSR,  IDX_ROR,  IDX_STY,  IDX_STX,
	IDX_LDY,  IDX_LDX,  IDX_CPY,  IDX_CPX,  IDX_DEC,  IDX_INC,
	IDXC_TSB, IDXC_TRB, IDXC_BIT, IDXC_DEC, IDXC_INC, IDXC_STZ,
	IDX8_COP, IDX8_REP, IDX8_SEP, IDX8_PEA,
	IDXI_ANC, IDXI_ASR, IDXI_ARR, IDXI_SBX, IDXI_DOP, IDXI_TOP, IDXI_JAM};
//		  |                                           6502                                           |                  65c02                  |        65816        |                6510                |
//		  |   bit    asl    rol    lsr    ror    sty    stx    ldy    ldx   cpy    cpx     dec    inc|   tsb    trb    bit    dec    inc    stz| cop  rep  sep    pea| anc  asr  arr  sbx  dop    top  jam|
SCB misc_impl[] = {     0,  0x0a,  0x2a,  0x4a,  0x6a,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,  0x3a,  0x1a,     0,   0,   0,   0,     0,   0,   0,   0,   0,0x80,  0x0c,0x02};// implied/accu
SCB misc_imm[]  = {     0,     0,     0,     0,     0,     0,     0,  0xa0,  0xa2,  0xc0,  0xe0,     0,     0,     0,     0,  0x89,     0,     0,     0,   0,0xc2,0xe2,     0,0x2b,0x4b,0x6b,0xcb,0x80,     0,   0};// #$ff
SCS misc_abs[]  = {0x2c24,0x0e06,0x2e26,0x4e46,0x6e66,0x8c84,0x8e86,0xaca4,0xaea6,0xccc4,0xece4,0xcec6,0xeee6,0x0c04,0x1c14,0x2c24,0xcec6,0xeee6,0x9c64,0x02,   0,   0,0xf400,   0,   0,   0,   0,0x04,0x0c00,   0};// $ff/$ffff
SCS misc_xabs[] = {     0,0x1e16,0x3e36,0x5e56,0x7e76,  0x94,     0,0xbcb4,     0,     0,     0,0xded6,0xfef6,     0,     0,0x3c34,0xded6,0xfef6,0x9e74,   0,   0,   0,     0,   0,   0,   0,   0,0x14,0x1c00,   0};// $ff,x/$ffff,x
SCS misc_yabs[] = {     0,     0,     0,     0,     0,     0,  0x96,     0,0xbeb6,     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,   0,   0,   0,     0,   0,   0,   0,   0,   0,     0,   0};// $ff,y/$ffff,y

// Code tables for group G_JUMP:
//
// These tables are needed for finding out the correct code when the mnemonic
// is "jmp" or "jsr" (or the long versions "jml" and "jsl").
// By reading the mnemonic's byte value (from the mnemotable), the assembler
// finds out the column to use here. The row depends on the used addressing
// mode. A zero entry in these tables means that the combination of mnemonic
// and addressing mode is illegal.
enum {	IDX_JMP, IDX_JSR, IDXC_JMP, IDX8_JMP, IDX8_JML, IDX8_JSR, IDX8_JSL};
//			|     6502    | 65c02|               65816               |
//			|  jmp    jsr |  jmp |    jmp      jml      jsr      jsl |
SCL jump_abs[]   = {0x4c00,0x2000,0x4c00,0x5c4c00,0x5c0000,0x222000,0x220000};// $ffff/$ffffff
SCS jump_ind[]   = {0x6c00,     0,0x6c00,  0x6c00,       0,       0,       0};// ($ffff)
SCS jump_xind[]  = {     0,     0,0x7c00,  0x7c00,       0,  0xfc00,       0};// ($ffff,x)
SCS jump_lind[]  = {     0,     0,     0,  0xdc00,  0xdc00,       0,       0};// [$ffff]

#undef SCB
#undef SCS
#undef SCL

// error message strings
static const char	exception_illegal_combination[]	= "Illegal combination of command and addressing mode.";
static const char	exception_highbyte_zero[]= "Using oversized addressing mode.";
static const char	exception_too_far[]	= "Target out of range.";


// Variables

static dynabuf_t*	mnemo_dyna_buf;	// dynamic buffer for mnemonics
// predefined stuff
static node_t*	mnemo_6502_tree	= NULL;// holds 6502 mnemonics
static node_t*	mnemo_6510_tree	= NULL;// holds 6510 extensions
static node_t*	mnemo_65c02_tree= NULL;// holds 65c02 extensions
//static node_t*	mnemo_Rockwell65c02_tree	= NULL;// Rockwell
static node_t*	mnemo_WDC65c02_tree	= NULL;// WDC's "stp"/"wai"
static node_t*	mnemo_65816_tree	= NULL;// holds 65816 extensions

// Command's code and group values are stored together in a single integer.
// To extract the code, use "& CODEMASK".
// To extract the group, use ">> GROUPSHIFT"
#define CODEMASK	0xff	// opcode or table index
#define FLAGSMASK	0x300	// flags concerning immediate addressing:
#define IMM_ACCU	0x100	//	...depends on accumulator length
#define IMM_IDX		0x200	//	...depends on index register length
#define GROUPSHIFT	10	// shift right by this to extract group
#define MERGE(g, v)	((g << GROUPSHIFT) | v)

static node_t	mnemos_6502[]	= {
	PREDEFNODE("ora", MERGE(G_MAIN		, IDX_ORA | IMM_ACCU)),
	PREDEFNODE(s_and, MERGE(G_MAIN		, IDX_AND | IMM_ACCU)),
	PREDEFNODE(s_eor, MERGE(G_MAIN		, IDX_EOR | IMM_ACCU)),
	PREDEFNODE("adc", MERGE(G_MAIN		, IDX_ADC | IMM_ACCU)),
	PREDEFNODE("sta", MERGE(G_MAIN		, IDX_STA)),
	PREDEFNODE("lda", MERGE(G_MAIN		, IDX_LDA | IMM_ACCU)),
	PREDEFNODE("cmp", MERGE(G_MAIN		, IDX_CMP | IMM_ACCU)),
	PREDEFNODE("sbc", MERGE(G_MAIN		, IDX_SBC | IMM_ACCU)),
	PREDEFNODE("bit", MERGE(G_MISC		, IDX_BIT | IMM_ACCU)),
	PREDEFNODE(s_asl, MERGE(G_MISC		, IDX_ASL)),
	PREDEFNODE("rol", MERGE(G_MISC		, IDX_ROL)),
	PREDEFNODE(s_lsr, MERGE(G_MISC		, IDX_LSR)),
	PREDEFNODE(s_ror, MERGE(G_MISC		, IDX_ROR)),
	PREDEFNODE("sty", MERGE(G_MISC		, IDX_STY)),
	PREDEFNODE("stx", MERGE(G_MISC		, IDX_STX)),
	PREDEFNODE("ldy", MERGE(G_MISC		, IDX_LDY | IMM_IDX)),
	PREDEFNODE("ldx", MERGE(G_MISC		, IDX_LDX | IMM_IDX)),
	PREDEFNODE("cpy", MERGE(G_MISC		, IDX_CPY | IMM_IDX)),
	PREDEFNODE("cpx", MERGE(G_MISC		, IDX_CPX | IMM_IDX)),
	PREDEFNODE("dec", MERGE(G_MISC		, IDX_DEC)),
	PREDEFNODE("inc", MERGE(G_MISC		, IDX_INC)),
	PREDEFNODE("bpl", MERGE(G_REL_SHORT	,  16)),
	PREDEFNODE("bmi", MERGE(G_REL_SHORT	,  48)),
	PREDEFNODE("bvc", MERGE(G_REL_SHORT	,  80)),
	PREDEFNODE("bvs", MERGE(G_REL_SHORT	, 112)),
	PREDEFNODE("bcc", MERGE(G_REL_SHORT	, 144)),
	PREDEFNODE("bcs", MERGE(G_REL_SHORT	, 176)),
	PREDEFNODE("bne", MERGE(G_REL_SHORT	, 208)),
	PREDEFNODE("beq", MERGE(G_REL_SHORT	, 240)),
	PREDEFNODE("jmp", MERGE(G_JUMP		, IDX_JMP)),
	PREDEFNODE("jsr", MERGE(G_JUMP		, IDX_JSR)),
	PREDEFNODE("brk", MERGE(G_IMPLIED	,   0)),
	PREDEFNODE("php", MERGE(G_IMPLIED	,   8)),
	PREDEFNODE("clc", MERGE(G_IMPLIED	,  24)),
	PREDEFNODE("plp", MERGE(G_IMPLIED	,  40)),
	PREDEFNODE("sec", MERGE(G_IMPLIED	,  56)),
	PREDEFNODE("rti", MERGE(G_IMPLIED	,  64)),
	PREDEFNODE("pha", MERGE(G_IMPLIED	,  72)),
	PREDEFNODE("cli", MERGE(G_IMPLIED	,  88)),
	PREDEFNODE("rts", MERGE(G_IMPLIED	,  96)),
	PREDEFNODE("pla", MERGE(G_IMPLIED	, 104)),
	PREDEFNODE("sei", MERGE(G_IMPLIED	, 120)),
	PREDEFNODE("dey", MERGE(G_IMPLIED	, 136)),
	PREDEFNODE("txa", MERGE(G_IMPLIED	, 138)),
	PREDEFNODE("tya", MERGE(G_IMPLIED	, 152)),
	PREDEFNODE("txs", MERGE(G_IMPLIED	, 154)),
	PREDEFNODE("tay", MERGE(G_IMPLIED	, 168)),
	PREDEFNODE("tax", MERGE(G_IMPLIED	, 170)),
	PREDEFNODE("clv", MERGE(G_IMPLIED	, 184)),
	PREDEFNODE("tsx", MERGE(G_IMPLIED	, 186)),
	PREDEFNODE("iny", MERGE(G_IMPLIED	, 200)),
	PREDEFNODE("dex", MERGE(G_IMPLIED	, 202)),
	PREDEFNODE("cld", MERGE(G_IMPLIED	, 216)),
	PREDEFNODE("inx", MERGE(G_IMPLIED	, 232)),
	PREDEFNODE("nop", MERGE(G_IMPLIED	, 234)),
	PREDEFLAST("sed", MERGE(G_IMPLIED	, 248)),
	//    ^^^^ this marks the last element
};

static node_t	mnemos_6510[]	= {
	PREDEFNODE("slo", MERGE(G_MAIN, IDXI_SLO)),// ASL+ORA, ASO
	PREDEFNODE("rla", MERGE(G_MAIN, IDXI_RLA)),// ROL+AND
	PREDEFNODE("sre", MERGE(G_MAIN, IDXI_SRE)),// LSR+EOR, LSE
	PREDEFNODE("rra", MERGE(G_MAIN, IDXI_RRA)),// ROR+ADC
	PREDEFNODE("sax", MERGE(G_MAIN, IDXI_SAX)),// STX+STA, AAX, AXS
	PREDEFNODE("lax", MERGE(G_MAIN, IDXI_LAX)),// LDX+LDA
	PREDEFNODE("dcp", MERGE(G_MAIN, IDXI_DCP)),// DEC+CMP, DCM
	PREDEFNODE("isc", MERGE(G_MAIN, IDXI_ISC)),// INC+SBC, ISB, INS
	PREDEFNODE("anc", MERGE(G_MISC, IDXI_ANC)),// ROL+AND, ASL+ORA, AAC
	PREDEFNODE(s_asr, MERGE(G_MISC, IDXI_ASR)),// LSR+EOR, ALR
	PREDEFNODE("arr", MERGE(G_MISC, IDXI_ARR)),// ROR+ADC
	PREDEFNODE("sbx", MERGE(G_MISC, IDXI_SBX)),// DEX+CMP, AXS, SAX
	PREDEFNODE("dop", MERGE(G_MISC, IDXI_DOP)),// skip next byte
	PREDEFNODE("top", MERGE(G_MISC, IDXI_TOP)),// skip next two bytes
	PREDEFLAST("jam", MERGE(G_MISC, IDXI_JAM)),// jam/crash/halt/kill
	//    ^^^^ this marks the last element
};

static node_t	mnemos_65c02[]	= {
	PREDEFNODE("ora", MERGE(G_MAIN		, IDXC_ORA | IMM_ACCU)),
	PREDEFNODE(s_and, MERGE(G_MAIN		, IDXC_AND | IMM_ACCU)),
	PREDEFNODE(s_eor, MERGE(G_MAIN		, IDXC_EOR | IMM_ACCU)),
	PREDEFNODE("adc", MERGE(G_MAIN		, IDXC_ADC | IMM_ACCU)),
	PREDEFNODE("sta", MERGE(G_MAIN		, IDXC_STA)),
	PREDEFNODE("lda", MERGE(G_MAIN		, IDXC_LDA | IMM_ACCU)),
	PREDEFNODE("cmp", MERGE(G_MAIN		, IDXC_CMP | IMM_ACCU)),
	PREDEFNODE("sbc", MERGE(G_MAIN		, IDXC_SBC | IMM_ACCU)),
	PREDEFNODE("jmp", MERGE(G_JUMP		, IDXC_JMP)),
	PREDEFNODE("bit", MERGE(G_MISC		, IDXC_BIT | IMM_ACCU)),
	PREDEFNODE("dec", MERGE(G_MISC		, IDXC_DEC)),
	PREDEFNODE("inc", MERGE(G_MISC		, IDXC_INC)),
	PREDEFNODE("bra", MERGE(G_REL_SHORT	, 128)),
	PREDEFNODE("phy", MERGE(G_IMPLIED	,  90)),
	PREDEFNODE("ply", MERGE(G_IMPLIED	, 122)),
	PREDEFNODE("phx", MERGE(G_IMPLIED	, 218)),
	PREDEFNODE("plx", MERGE(G_IMPLIED	, 250)),
	PREDEFNODE("tsb", MERGE(G_MISC		, IDXC_TSB)),
	PREDEFNODE("trb", MERGE(G_MISC		, IDXC_TRB)),
	PREDEFLAST("stz", MERGE(G_MISC		, IDXC_STZ)),
	//    ^^^^ this marks the last element
};

//static node_t	mnemos_Rockwell65c02[]	= {
//	PREDEFNODE("rmb0", MERGE(G_	, 0x07)),
//	PREDEFNODE("rmb1", MERGE(G_	, 0x17)),
//	PREDEFNODE("rmb2", MERGE(G_	, 0x27)),
//	PREDEFNODE("rmb3", MERGE(G_	, 0x37)),
//	PREDEFNODE("rmb4", MERGE(G_	, 0x47)),
//	PREDEFNODE("rmb5", MERGE(G_	, 0x57)),
//	PREDEFNODE("rmb6", MERGE(G_	, 0x67)),
//	PREDEFNODE("rmb7", MERGE(G_	, 0x77)),
//	PREDEFNODE("smb0", MERGE(G_	, 0x87)),
//	PREDEFNODE("smb1", MERGE(G_	, 0x97)),
//	PREDEFNODE("smb2", MERGE(G_	, 0xa7)),
//	PREDEFNODE("smb3", MERGE(G_	, 0xb7)),
//	PREDEFNODE("smb4", MERGE(G_	, 0xc7)),
//	PREDEFNODE("smb5", MERGE(G_	, 0xd7)),
//	PREDEFNODE("smb6", MERGE(G_	, 0xe7)),
//	PREDEFNODE("smb7", MERGE(G_	, 0xf7)),
//	PREDEFNODE("bbr0", MERGE(G_	, 0x0f)),
//	PREDEFNODE("bbr1", MERGE(G_	, 0x1f)),
//	PREDEFNODE("bbr2", MERGE(G_	, 0x2f)),
//	PREDEFNODE("bbr3", MERGE(G_	, 0x3f)),
//	PREDEFNODE("bbr4", MERGE(G_	, 0x4f)),
//	PREDEFNODE("bbr5", MERGE(G_	, 0x5f)),
//	PREDEFNODE("bbr6", MERGE(G_	, 0x6f)),
//	PREDEFNODE("bbr7", MERGE(G_	, 0x7f)),
//	PREDEFNODE("bbs0", MERGE(G_	, 0x8f)),
//	PREDEFNODE("bbs1", MERGE(G_	, 0x9f)),
//	PREDEFNODE("bbs2", MERGE(G_	, 0xaf)),
//	PREDEFNODE("bbs3", MERGE(G_	, 0xbf)),
//	PREDEFNODE("bbs4", MERGE(G_	, 0xcf)),
//	PREDEFNODE("bbs5", MERGE(G_	, 0xdf)),
//	PREDEFNODE("bbs6", MERGE(G_	, 0xef)),
//	PREDEFLAST("bbs7", MERGE(G_	, 0xff)),
//	//    ^^^^ this marks the last element
//};

static node_t	mnemos_WDC65c02[]	= {
	PREDEFNODE("stp", MERGE(G_IMPLIED	, 219)),
	PREDEFLAST("wai", MERGE(G_IMPLIED	, 203)),
	//    ^^^^ this marks the last element
};

static node_t	mnemos_65816[]	= {
	PREDEFNODE("ora", MERGE(G_MAIN		, IDX8_ORA | IMM_ACCU)),
	PREDEFNODE(s_and, MERGE(G_MAIN		, IDX8_AND | IMM_ACCU)),
	PREDEFNODE(s_eor, MERGE(G_MAIN		, IDX8_EOR | IMM_ACCU)),
	PREDEFNODE("adc", MERGE(G_MAIN		, IDX8_ADC | IMM_ACCU)),
	PREDEFNODE("sta", MERGE(G_MAIN		, IDX8_STA)),
	PREDEFNODE("lda", MERGE(G_MAIN		, IDX8_LDA | IMM_ACCU)),
	PREDEFNODE("cmp", MERGE(G_MAIN		, IDX8_CMP | IMM_ACCU)),
	PREDEFNODE("sbc", MERGE(G_MAIN		, IDX8_SBC | IMM_ACCU)),
	PREDEFNODE("pei", MERGE(G_MAIN		, IDX8_PEI)),
	PREDEFNODE("jmp", MERGE(G_JUMP		, IDX8_JMP)),
	PREDEFNODE("jsr", MERGE(G_JUMP		, IDX8_JSR)),
	PREDEFNODE("jml", MERGE(G_JUMP		, IDX8_JML)),
	PREDEFNODE("jsl", MERGE(G_JUMP		, IDX8_JSL)),
	PREDEFNODE("mvp", MERGE(G_MOVE		, 0x44)),
	PREDEFNODE("mvn", MERGE(G_MOVE		, 0x54)),
	PREDEFNODE("per", MERGE(G_REL_LONG	,  98)),
	PREDEFNODE(s_brl, MERGE(G_REL_LONG	, 130)),
	PREDEFNODE("cop", MERGE(G_MISC		, IDX8_COP)),
	PREDEFNODE("rep", MERGE(G_MISC		, IDX8_REP)),
	PREDEFNODE("sep", MERGE(G_MISC		, IDX8_SEP)),
	PREDEFNODE("pea", MERGE(G_MISC		, IDX8_PEA)),
	PREDEFNODE("phd", MERGE(G_IMPLIED	,  11)),
	PREDEFNODE("tcs", MERGE(G_IMPLIED	,  27)),
	PREDEFNODE("pld", MERGE(G_IMPLIED	,  43)),
	PREDEFNODE("tsc", MERGE(G_IMPLIED	,  59)),
	PREDEFNODE("wdm", MERGE(G_IMPLIED	,  66)),
	PREDEFNODE("phk", MERGE(G_IMPLIED	,  75)),
	PREDEFNODE("tcd", MERGE(G_IMPLIED	,  91)),
	PREDEFNODE("rtl", MERGE(G_IMPLIED	, 107)),
	PREDEFNODE("tdc", MERGE(G_IMPLIED	, 123)),
	PREDEFNODE("phb", MERGE(G_IMPLIED	, 139)),
	PREDEFNODE("txy", MERGE(G_IMPLIED	, 155)),
	PREDEFNODE("plb", MERGE(G_IMPLIED	, 171)),
	PREDEFNODE("tyx", MERGE(G_IMPLIED	, 187)),
	PREDEFNODE("xba", MERGE(G_IMPLIED	, 235)),
	PREDEFLAST("xce", MERGE(G_IMPLIED	, 251)),
	//    ^^^^ this marks the last element
};


// Functions

// create dynamic buffer, build keyword trees
void Mnemo_init(void) {
	mnemo_dyna_buf = DynaBuf_create(MNEMO_DYNABUF_INITIALSIZE);
	Tree_add_table(&mnemo_6502_tree, mnemos_6502);
	Tree_add_table(&mnemo_6510_tree, mnemos_6510);
	Tree_add_table(&mnemo_65c02_tree, mnemos_65c02);
//	Tree_add_table(&mnemo_Rockwell65c02_tree, mnemos_Rockwell65c02);
	Tree_add_table(&mnemo_WDC65c02_tree, mnemos_WDC65c02);
	Tree_add_table(&mnemo_65816_tree, mnemos_65816);
}


// Address mode parsing

// Utility function for parsing indices.
static int get_index(bool next) {
	int	addressing_mode	= HAM__;

	if(next)
		GetByte();
	if(!Input_accept_comma())
		return(addressing_mode);
	switch(GotByte) {

		case 's':
		case 'S':
		addressing_mode = HAM_S;
		break;

		case 'x':
		case 'X':
		addressing_mode = HAM_X;
		break;

		case 'y':
		case 'Y':
		addressing_mode = HAM_Y;
		break;

		default:
		Throw_error(exception_syntax);

	}
	if(addressing_mode != HAM__)
		NEXTANDSKIPSPACE();
	return(addressing_mode);
}

// This function stores the command's argument in the given result_int_t
// structure (using the valueparser). The addressing mode is returned.
static int get_argument(result_int_t* result) {
	int	open_paren,
		addressing_mode	= HAM_ABS;

	SKIPSPACE();
	switch(GotByte) {

		case '[':
		GetByte();// proceed with next char
		ALU_int_result(result);
		if(GotByte == ']')
			addressing_mode |= HAM_LIND | get_index(TRUE);
		else
			Throw_error(exception_syntax);
		break;

		case '#':
		GetByte();// proceed with next char
		addressing_mode |= HAM_IMM;
		ALU_int_result(result);
		break;

		default:
		// liberal, to allow for "(...,"
		open_paren = ALU_liberal_int(result);
		// check for implied addressing
		if((result->flags & MVALUE_EXISTS) == 0)
			addressing_mode |= HAM_IMP;
		// check for indirect addressing
		if(result->flags & MVALUE_INDIRECT)
			addressing_mode |= HAM_IND;
		// check for internal index (before closing parenthesis)
		if(open_paren) {
			// in case there are still open parentheses,
			// read internal index
			addressing_mode |= (get_index(FALSE) << 2);
			if(GotByte == ')')
				GetByte();// go on with next char
			else
				Throw_error(exception_syntax);
		}
		// check for external index (after closing parenthesis)
		addressing_mode |= get_index(FALSE);
		break;

	}
	// ensure end of line
	Input_ensure_EOS();
	//printf("AM: %x\n", addressing_mode);
	return(addressing_mode);
}

// Helper function for calc_arg_size()
// Only call with "size_bit = MVALUE_FORCE16" or "size_bit = MVALUE_FORCE24"
static int check_oversize(int size_bit, result_int_t* argument) {
	// only check if value is *defined*
	if((argument->flags & MVALUE_DEFINED) == 0)
		return(size_bit);// pass on result

	// value is defined, so check
	if(size_bit == MVALUE_FORCE16) {
		// check 16-bit argument for high byte zero
		if((argument->intval <= 255) && (argument->intval >= -128))
			Throw_warning(exception_highbyte_zero);
	} else
		// check 24-bit argument for bank byte zero
		if((argument->intval <= 65535) && (argument->intval >= -32768))
			Throw_warning(exception_highbyte_zero);
	return(size_bit);// pass on result
}

// Utility function for comparing force bits, argument value, argument size,
// "unsure"-flag and possible addressing modes. Returns force bit matching
// number of parameter bytes to send. If it returns zero, an error occurred
// (and has already been delivered).
// force_bit		none, 8b, 16b, 24b
// argument		value and flags of parameter
// addressing_modes	adressing modes (8b, 16b, 24b or any combination)
// Return value = force bit for number of parameter bytes to send (0 = error)
static int calc_arg_size(int force_bit, result_int_t* argument, int addressing_modes) {
	// If there are no possible addressing modes, complain
	if(addressing_modes == MAYBE______) {
		Throw_error(exception_illegal_combination);
		return(0);
	}
	// If command has force bit, act upon it
	if(force_bit) {
		// If command allows this force bit, return it
		if(addressing_modes & force_bit)
			return(force_bit);
		// If not, complain
		Throw_error("Illegal combination of command and postfix.");
		return(0);
	}
	// Command has no force bit. Check whether value has one
	// If value has force bit, act upon it
	if(argument->flags & MVALUE_FORCEBITS) {
		// Value has force bit set, so return this or bigger size
		if(MVALUE_FORCE08 & addressing_modes & argument->flags)
			return(MVALUE_FORCE08);
		if(MVALUE_FORCE16 & addressing_modes & argument->flags)
			return(MVALUE_FORCE16);
		if(MVALUE_FORCE24 & addressing_modes)
			return(MVALUE_FORCE24);
		Throw_error(exception_number_out_of_range);// else error
		return(0);
	}
	// Value has no force bit. Check whether there's only one addr mode
	// If only one addressing mode, use that
	if((addressing_modes == MVALUE_FORCE08)
	|| (addressing_modes == MVALUE_FORCE16)
	|| (addressing_modes == MVALUE_FORCE24))
		return(addressing_modes);// There's only one, so use it
	// There's more than one addressing mode. Check whether value is sure
	// If value is unsure, use default size
	if(argument->flags & MVALUE_UNSURE) {
		// If there is an 8-bit addressing mode *and* the value
		// is sure to fit into 8 bits, use the 8-bit mode
		if((addressing_modes & MVALUE_FORCE08) && (argument->flags & MVALUE_ISBYTE))
			return(MVALUE_FORCE08);
		// If there is a 16-bit addressing, use that
		// Call helper function for "oversized addr mode" warning
		if(MVALUE_FORCE16 & addressing_modes)
			return(check_oversize(MVALUE_FORCE16, argument));
		// If there is a 24-bit addressing, use that
		// Call helper function for "oversized addr mode" warning
		if(MVALUE_FORCE24 & addressing_modes)
			return(check_oversize(MVALUE_FORCE24, argument));
		// otherwise, use 8-bit-addressing, which will raise an
		// error later on if the value won't fit
		return(MVALUE_FORCE08);
	}
	// Value is sure, so use its own size
	// If value is negative, size cannot be chosen. Complain!
	if(argument->intval < 0) {
		Throw_error("Negative value - cannot choose addressing mode.");
		return(0);
	}
	// Value is positive or zero. Check size ranges
	// If there is an 8-bit addressing mode and value fits, use 8 bits
	if((addressing_modes & MVALUE_FORCE08) && (argument->intval < 256))
		return(MVALUE_FORCE08);
	// If there is a 16-bit addressing mode and value fits, use 16 bits
	if((addressing_modes & MVALUE_FORCE16) && (argument->intval < 65536))
		return(MVALUE_FORCE16);
	// If there is a 24-bit addressing mode, use that. In case the
	// value doesn't fit, the output function will do the complaining.
	if(addressing_modes & MVALUE_FORCE24)
		return(MVALUE_FORCE24);
	// Value is too big for all possible addressing modes
	Throw_error(exception_number_out_of_range);
	return(0);
}

// Mnemonics using only implied addressing.
static void group_only_implied_addressing(int opcode) {
	Output_byte(opcode);
	Input_ensure_EOS();
}

// Mnemonics using only 8bit relative addressing (short branch instructions).
static void group_only_relative8_addressing(int opcode) {
	result_int_t	result;

	ALU_int_result(&result);
	if(result.flags & MVALUE_DEFINED) {
		result.intval -= (CPU_pc.intval + 2);
		if((result.intval > 127) || (result.intval < -128))
			Throw_error(exception_too_far);
	}
	Output_byte(opcode);
	// this fn has its own range check (see above).
	// No reason to irritate the user with another error message,
	// so use Output_byte() instead of Output_8b()
	//Output_8b(result.value);
	Output_byte(result.intval);
	Input_ensure_EOS();
}

// Mnemonics using only 16bit relative addressing (BRL and PER).
static void group_only_relative16_addressing(int opcode) {
	result_int_t	result;

	ALU_int_result(&result);
	if(result.flags & MVALUE_DEFINED) {
		result.intval -= (CPU_pc.intval + 3);
		if((result.intval > 32767) || (result.intval < -32768))
			Throw_error(exception_too_far);
	}
	Output_byte(opcode);
	// this fn has its own range check (see above).
	// No reason to irritate the user with another error message,
	// so use Output_byte() instead of Output_16b()
	//Output_16b(result.value);
	Output_byte(result.intval);
	Output_byte(result.intval >> 8);
	Input_ensure_EOS();
}

// set addressing mode bits depending on which opcodes exist, then calculate
// argument size and output both opcode and argument
static void make_command(int force_bit, result_int_t* result, unsigned long opcodes) {
	int	addressing_modes	= MAYBE______;

	if(opcodes & 0x0000ff)
		addressing_modes |= MAYBE_1____;
	if(opcodes & 0x00ff00)
		addressing_modes |= MAYBE___2__;
	if(opcodes & 0xff0000)
		addressing_modes |= MAYBE_____3;
	switch(calc_arg_size(force_bit, result, addressing_modes)) {

		case MVALUE_FORCE08:
		Output_byte(opcodes & 255);
		Output_8b(result->intval);
		break;

		case MVALUE_FORCE16:
		Output_byte((opcodes >> 8) & 255);
		Output_16b(result->intval);
		break;

		case MVALUE_FORCE24:
		Output_byte((opcodes >> 16) & 255);
		Output_24b(result->intval);
		break;

	}
}

// check whether 16bit immediate addressing is allowed. If not, return given
// opcode. If it is allowed, set force bits according to CPU register length
// and return given opcode for both 8- and 16-bit mode.
static unsigned int imm_ops(int *force_bit, unsigned char opcode, int imm_flag) {
	// if the CPU does not allow 16bit immediate addressing (or if the
	// opcode does not allow it), return immediately.
	if((CPU_now->long_regs == NULL) || (imm_flag == 0))
		return(opcode);
	// check force bits (if no force bits given, use relevant flag)
	if(*force_bit == 0)
		*force_bit = ((imm_flag & IMM_ACCU) ?
			CPU_now->long_regs[LONGREG_IDX_A] :
			CPU_now->long_regs[LONGREG_IDX_R]) ?
				MVALUE_FORCE16 :
				MVALUE_FORCE08;
	// return identical opcodes for 8bit and 16bit args!
	return((((unsigned int) opcode) << 8) | opcode);
}

// The main accumulator stuff (ADC, AND, CMP, EOR, LDA, ORA, SBC, STA)
// plus PEI.
static void group_main(int index, int imm_flag) {
	unsigned long	imm_opcodes;
	result_int_t	result;
	int		force_bit	= Input_get_force_bit();// skips spaces after

	switch(get_argument(&result)) {

	// #$ff or #$ffff (depending on accu length)
		case HAM_IMM:
		imm_opcodes = imm_ops(&force_bit, accu_imm[index], imm_flag);
		// CAUTION - do not incorporate the line above into the line
		// below - "fb" might be undefined (depends on compiler).
		make_command(force_bit, &result, imm_opcodes);
		break;

	// $ff, $ffff, $ffffff
		case HAM_ABS:
		make_command(force_bit, &result, accu_abs[index]);
		break;

	// $ff,x, $ffff,x, $ffffff,x
		case HAM_ABSX:
		make_command(force_bit, &result, accu_xabs[index]);
		break;

	// $ffff,y (in theory, "$ff,y" as well)
		case HAM_ABSY:
		make_command(force_bit, &result, accu_yabs[index]);
		break;

	// $ff,s
		case HAM_ABSS:
		make_command(force_bit, &result, accu_sabs8[index]);
		break;

	// ($ff,x)
		case HAM_XIND:
		make_command(force_bit, &result, accu_xind8[index]);
		break;

	// ($ff)
		case HAM_IND:
		make_command(force_bit, &result, accu_ind8[index]);
		break;

	// ($ff),y
		case HAM_INDY:
		make_command(force_bit, &result, accu_indy8[index]);
		break;

	// [$ff]
		case HAM_LIND:
		make_command(force_bit, &result, accu_lind8[index]);
		break;

	// [$ff],y
		case HAM_LINDY:
		make_command(force_bit, &result, accu_lindy8[index]);
		break;

	// ($ff,s),y
		case HAM_SINDY:
		make_command(force_bit, &result, accu_sindy8[index]);
		break;

	// other combinations are illegal
		default:
		Throw_error(exception_illegal_combination);

	}
}

// Various mnemonics with different addressing modes.
static void group_misc(int index, int imm_flag) {
	unsigned long	imm_opcodes;
	result_int_t	result;
	int		force_bit	= Input_get_force_bit();// skips spaces after

	switch(get_argument(&result)) {

	// implied addressing
		case HAM_IMP:
		if(misc_impl[index])
			Output_byte(misc_impl[index]);
		else
			Throw_error(exception_illegal_combination);
		break;

	// #$ff or #$ffff (depending on index register length)
		case HAM_IMM:
		imm_opcodes = imm_ops(&force_bit, misc_imm[index], imm_flag);
		// CAUTION - do not incorporate the line above into the line
		// below - force_bit might be undefined (depends on compiler).
		make_command(force_bit, &result, imm_opcodes);
		break;

	// $ff or  $ffff
		case HAM_ABS:
		make_command(force_bit, &result, misc_abs[index]);
		break;

	// $ff,x  or  $ffff,x
		case HAM_ABSX:
		make_command(force_bit, &result, misc_xabs[index]);
		break;

	// $ff,y  or  $ffff,y
		case HAM_ABSY:
		make_command(force_bit, &result, misc_yabs[index]);
		break;

	// other combinations are illegal
		default:
		Throw_error(exception_illegal_combination);
	}
}

// Mnemonics using "8bit, 8bit" addressing. Only applies to "MVN" and "MVP".
static void group_move(int opcode) {
	intval_t	source,
			target;

	// assembler syntax: "opcode source, target"
	source = ALU_any_int();
	if(Input_accept_comma()) {
		target = ALU_any_int();	// machine language:
		Output_byte(opcode);	//	opcode
		Output_8b(target);	//	target
		Output_8b(source);	//	source
		Input_ensure_EOS();
	} else
		Throw_error(exception_syntax);
}

// The jump instructions.
static void group_jump(int index) {
	result_int_t	result;
	int		force_bit	= Input_get_force_bit();// skips spaces after

	switch(get_argument(&result)) {

		// absolute16 or absolute24
		case HAM_ABS:
		make_command(force_bit, &result, jump_abs[index]);
		break;

		// ($ffff)
		case HAM_IND:
		make_command(force_bit, &result, jump_ind[index]);
		// check whether to warn about 6502's JMP() bug
		if(((result.intval & 0xff) == 0xff)
		&& (result.flags & MVALUE_DEFINED)
		&& (CPU_now->flags & CPUFLAG_INDJMPBUGGY))
			Throw_warning("Assembling buggy JMP($xxff) instruction");
		break;

		// ($ffff,x)
		case HAM_XIND:
		make_command(force_bit, &result, jump_xind[index]);
		break;

		// [$ffff]
		case HAM_LIND:
		make_command(force_bit, &result, jump_lind[index]);
		break;

		// other combinations are illegal
		default:
		Throw_error(exception_illegal_combination);

	}
}

// Work function
static bool check_mnemo_tree(node_t* tree, dynabuf_t* dyna_buf) {
	void*	node_body;
	int	code,
		imm_flag;	// flag for immediate addressing

	// search for tree item
	if(!Tree_easy_scan(tree, &node_body, dyna_buf))
		return(FALSE);
	code = ((int) node_body) & CODEMASK;	// get opcode or table index
	imm_flag = ((int) node_body) & FLAGSMASK;	// get flag
	switch(((long) node_body) >> GROUPSHIFT) {

	// mnemonics with only implied addressing
		case G_IMPLIED:
		group_only_implied_addressing(code);
		break;

	// main accumulator stuff
		case G_MAIN:
		group_main(code, imm_flag);
		break;

	// misc
		case G_MISC:
		group_misc(code, imm_flag);
		break;

	// short relative
		case G_REL_SHORT:
		group_only_relative8_addressing(code);
		break;

	// long relative
		case G_REL_LONG:
		group_only_relative16_addressing(code);
		break;

	// the jump instructions
		case G_JUMP:
		group_jump(code);
		break;

	// "mvp" and "mvn"
		case G_MOVE:
		group_move(code);
		break;

	// others indicate bugs
		default:
		Bug_found("IllegalGroupIndex", code);

	}
	return(TRUE);
}

// Check whether mnemonic in GlobalDynaBuf is supported by 6502 cpu.
bool keyword_is_6502mnemo(int length) {
	if(length != 3)
		return(FALSE);
	// make lower case version of mnemonic in local dynamic buffer
	DynaBuf_to_lower(mnemo_dyna_buf, GlobalDynaBuf);
	if(check_mnemo_tree(mnemo_6502_tree, mnemo_dyna_buf))
		return(TRUE);
	return(FALSE);
}

// Check whether mnemonic in GlobalDynaBuf is supported by 6510 cpu.
bool keyword_is_6510mnemo(int length) {
	if(length != 3)
		return(FALSE);
	// make lower case version of mnemonic in local dynamic buffer
	DynaBuf_to_lower(mnemo_dyna_buf, GlobalDynaBuf);
	// first check extensions...
	if(check_mnemo_tree(mnemo_6510_tree, mnemo_dyna_buf))
		return(TRUE);
	// ...then check original opcodes
	if(check_mnemo_tree(mnemo_6502_tree, mnemo_dyna_buf))
		return(TRUE);
	return(FALSE);
}

// Check whether mnemonic in GlobalDynaBuf is supported by 65c02 cpu.
bool keyword_is_65c02mnemo(int length) {
	if(length != 3)
		return(FALSE);
	// make lower case version of mnemonic in local dynamic buffer
	DynaBuf_to_lower(mnemo_dyna_buf, GlobalDynaBuf);
	// first check extensions...
	if(check_mnemo_tree(mnemo_65c02_tree, mnemo_dyna_buf))
		return(TRUE);
	// ...then check original opcodes
	if(check_mnemo_tree(mnemo_6502_tree, mnemo_dyna_buf))
		return(TRUE);
	return(FALSE);
}

//// Check whether mnemonic in GlobalDynaBuf is supported by Rockwell 65c02 cpu.
//bool keyword_is_Rockwell65c02mnemo(int length) {
//	if((length != 3) && (length != 4))
//		return(FALSE);
//	// make lower case version of mnemonic in local dynamic buffer
//	DynaBuf_to_lower(mnemo_dyna_buf, GlobalDynaBuf);
//	// first check 65c02 extensions...
//	if(check_mnemo_tree(mnemo_65c02_tree, mnemo_dyna_buf))
//		return(TRUE);
//	// ...then check original opcodes...
//	if(check_mnemo_tree(mnemo_6502_tree, mnemo_dyna_buf))
//		return(TRUE);
//	// ...then check Rockwell/WDC extensions (rmb, smb, bbr, bbs)
//	if(check_mnemo_tree(mnemo_Rockwell65c02_tree, mnemo_dyna_buf))
//		return(TRUE);
//	return(FALSE);
//}

//// Check whether mnemonic in GlobalDynaBuf is supported by WDC 65c02 cpu.
//bool keyword_is_WDC65c02mnemo(int length) {
//	if((length != 3) && (length != 4))
//		return(FALSE);
//	// make lower case version of mnemonic in local dynamic buffer
//	DynaBuf_to_lower(mnemo_dyna_buf, GlobalDynaBuf);
//	// first check 65c02 extensions...
//	if(check_mnemo_tree(mnemo_65c02_tree, mnemo_dyna_buf))
//		return(TRUE);
//	// ...then check original opcodes...
//	if(check_mnemo_tree(mnemo_6502_tree, mnemo_dyna_buf))
//		return(TRUE);
//	// ...then check Rockwell/WDC extensions (rmb, smb, bbr, bbs)...
//	if(check_mnemo_tree(mnemo_Rockwell65c02_tree, mnemo_dyna_buf))
//		return(TRUE);
//	// ...then check WDC extensions (only two mnemonics, so do last)
//	if(check_mnemo_tree(mnemo_WDC65c02_tree, mnemo_dyna_buf))
//		return(TRUE);
//	return(FALSE);
//}

// Check whether mnemonic in GlobalDynaBuf is supported by 65816 cpu.
bool keyword_is_65816mnemo(int length) {
	if(length != 3)
		return(FALSE);
	// make lower case version of mnemonic in local dynamic buffer
	DynaBuf_to_lower(mnemo_dyna_buf, GlobalDynaBuf);
	// first check "new" extensions...
	if(check_mnemo_tree(mnemo_65816_tree, mnemo_dyna_buf))
		return(TRUE);
	// ...then "old" extensions...
	if(check_mnemo_tree(mnemo_65c02_tree, mnemo_dyna_buf))
		return(TRUE);
	// ...then check original opcodes...
	if(check_mnemo_tree(mnemo_6502_tree, mnemo_dyna_buf))
		return(TRUE);
	// ...then check WDC extensions "stp" and "wai"
	if(check_mnemo_tree(mnemo_WDC65c02_tree, mnemo_dyna_buf))
		return(TRUE);
	return(FALSE);
}
