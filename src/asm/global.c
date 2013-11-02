//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Global stuff - things that are needed by several modules
//  4 Oct 2006	Fixed a typo in a comment

#include <stdio.h>
#include <setjmp.h>
#include "platform.h"	// done first in case "inline" is redefined
#include "acme.h"
#include "cpu.h"
#include "dynabuf.h"
#include "global.h"
#include "input.h"
#include "label.h"
#include "macro.h"
#include "output.h"
#include "section.h"
#include "tree.h"


// Constants

const char	s_65816[]	= "65816";
const char	s_and[]		= "and";
const char	s_asl[]		= "asl";
const char	s_asr[]		= "asr";
const char	s_brl[]		= "brl";
const char	s_cbm[]		= "cbm";
const char	s_eor[]		= "eor";
const char	s_error[]	= "error";
const char	s_lsr[]		= "lsr";
const char	s_scrxor[]	= "scrxor";
// Exception messages during assembly
const char	exception_cannot_open_input_file[] = "Cannot open input file.";
const char	exception_missing_string[]	= "No string given.";
const char	exception_no_left_brace[]	= "Missing '{'.";
const char	exception_no_memory_left[]	= "Out of memory.";
const char	exception_no_right_brace[]= "Found end-of-file instead of '}'.";
//const char	exception_not_yet[]	= "Sorry, feature not yet implemented.";
const char	exception_number_out_of_range[]	= "Number out of range.";
const char	exception_pc_undefined[]	= "Program counter undefined.";
const char	exception_syntax[]		= "Syntax error.";
// default value for number of errors before exiting
#define MAXERRORS	10

// Flag table:
// This table contains flags for all the 256 possible byte values. The
// assembler reads the table whenever it needs to know whether a byte is
// allowed to be in a label name, for example.
//   Bits	Meaning when set
// 7.......	Byte allowed to start keyword
// .6......	Byte allowed in keyword
// ..5.....	Byte is upper case, can be lowercased by OR-ing this bit(!)
// ...4....	special character for input syntax: 0x00 TAB LF CR SPC : ; }
// ....3...	preceding sequence of '-' characters is anonymous backward
//		label. Currently only set for ')', ',' and CHAR_EOS.
// .....210	unused
const char	Byte_flags[256]	= {
/*$00*/	0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,// control characters
	0x00, 0x10, 0x10, 0x00, 0x00, 0x10, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
/*$20*/	0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,// " !"#$%&'"
	0x00, 0x08, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00,// "()*+,-./"
	0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40,// "01234567"
	0x40, 0x40, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00,// "89:;<=>?"
/*$40*/	0x00, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0,// "@ABCDEFG"
	0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0,// "HIJKLMNO"
	0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0,// "PQRSTUVW"
	0xe0, 0xe0, 0xe0, 0x00, 0x00, 0x00, 0x00, 0xc0,// "XYZ[\]^_"
/*$60*/	0x00, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,// "`abcdefg"
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,// "hijklmno"
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,// "pqrstuvw"
	0xc0, 0xc0, 0xc0, 0x00, 0x00, 0x10, 0x00, 0x00,// "xyz{|}~" BACKSPACE
/*$80*/	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,// umlauts etc. ...
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
/*$a0*/	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
/*$c0*/	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
/*$e0*/	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
	0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
};


// Variables

node_t*	pseudo_opcode_tree	= NULL;	// tree to hold pseudo opcodes
int	pass_count;			// number of current pass (starts 0)
char	GotByte;			// Last byte read (processed)
int	Process_verbosity	= 0;	// Level of additional output
// Global counters
int	pass_undefined_count;	// "NeedValue" type errors
int	pass_real_errors;	// Errors yet
signed long	max_errors	= MAXERRORS;// errors before giving up
FILE*	msg_stream		= NULL;// set to stdout by --use-stdout
jmp_buf exception_env;
char* error_message;
//int cbm_load_address = 0;

// Functions


// Memory allocation stuff

// Allocate memory and die if not available
void* safe_malloc(size_t size) {
	void*	block;

	if((block = malloc(size)) == NULL)
		Throw_serious_error(exception_no_memory_left);
	return(block);
}


// Parser stuff

// Parse (re-)definitions of program counter
static void parse_pc_def(void) {// Now GotByte = "*"
	NEXTANDSKIPSPACE();	// proceed with next char
	// re-definitions of program counter change segment
	if(GotByte == '=') {
		GetByte();// proceed with next char
		Output_start_segment();
		Input_ensure_EOS();
	} else {
		Throw_error(exception_syntax);
		Input_skip_remainder();
	}
}

// Parse pseudo opcodes. Has to be re-entrant.
static inline void parse_pseudo_opcode(void) {// Now GotByte = "!"
	void*		node_body;
	enum eos_t	(*fn)(void);
	enum eos_t	then	= SKIP_REMAINDER;	// prepare for errors

	GetByte();// read next byte
	// on missing keyword, return (complaining will have been done)
	if(Input_read_and_lower_keyword()) {
		// search for tree item
		if((Tree_easy_scan(pseudo_opcode_tree, &node_body, GlobalDynaBuf))
		&& node_body) {
			fn = (enum eos_t (*)(void)) node_body;
			SKIPSPACE();
			// call function
			then = fn();
		} else
			Throw_error("Unknown pseudo opcode.");
	}
	if(then == SKIP_REMAINDER)
		Input_skip_remainder();
	else if(then == ENSURE_EOS)
		Input_ensure_EOS();
	// the other two possibilities (PARSE_REMAINDER and AT_EOS_ANYWAY)
	// will lead to the remainder of the line being parsed by the mainloop.
}

// Check and return whether first label of statement. Complain if not.
static bool first_label_of_statement(int *statement_flags) {
	if((*statement_flags) & SF_IMPLIED_LABEL) {
		Throw_error(exception_syntax);
		Input_skip_remainder();
		return(FALSE);
	}
	(*statement_flags) |= SF_IMPLIED_LABEL;	// now there has been one
	return(TRUE);
}

// Parse global label definition or assembler mnemonic
static void parse_mnemo_or_global_label_def(int *statement_flags) {
	// It is only a label if it isn't a mnemonic
	if((CPU_now->keyword_is_mnemonic(Input_read_keyword()) == FALSE)
	&& first_label_of_statement(statement_flags)) {
		// Now GotByte = illegal char
		// 04 Jun 2005 - this fix should help to
		// explain "strange" error messages.
		if(*GLOBALDYNABUF_CURRENT == ' ')
			Throw_first_pass_warning("Label name starts with a shift-space character.");
		Label_parse_definition(ZONE_GLOBAL, *statement_flags);
	}
}

// Parse local label definition
static void parse_local_label_def(int *statement_flags) {
	if(!first_label_of_statement(statement_flags))
		return;
	GetByte();// start after '.'
	if(Input_read_keyword())
		Label_parse_definition(Section_now->zone, *statement_flags);
}

// Parse anonymous backward label definition. Called with GotByte == '-'
static void parse_backward_anon_def(int *statement_flags) {
	if(!first_label_of_statement(statement_flags))
		return;
	DYNABUF_CLEAR(GlobalDynaBuf);
	do
		DYNABUF_APPEND(GlobalDynaBuf, '-');
	while(GetByte() == '-');
	DynaBuf_append(GlobalDynaBuf, '\0');
	Label_implicit_definition(Section_now->zone, *statement_flags, 0, TRUE);
}

// Parse anonymous forward label definition. Called with GotByte == ?
static void parse_forward_anon_def(int *statement_flags) {
	label_t*	counter_label;

	if(!first_label_of_statement(statement_flags))
		return;
	DYNABUF_CLEAR(GlobalDynaBuf);
	DynaBuf_append(GlobalDynaBuf, '+');
	while(GotByte == '+') {
		DYNABUF_APPEND(GlobalDynaBuf, '+');
		GetByte();
	}
	counter_label = Label_fix_forward_name();
	counter_label->result.val.intval++;
	DynaBuf_append(GlobalDynaBuf, '\0');
	Label_implicit_definition(Section_now->zone, *statement_flags, 0, TRUE);
}

// Parse block, beginning with next byte.
// End reason (either CHAR_EOB or CHAR_EOF) can be found in GotByte afterwards
// Has to be re-entrant.
void Parse_until_eob_or_eof(void) {
	int	statement_flags;

//	// start with next byte, don't care about spaces
//	NEXTANDSKIPSPACE();
	// start with next byte
	GetByte();
	// loop until end of block or end of file
	while((GotByte != CHAR_EOB) && (GotByte != CHAR_EOF)) {
		// process one statement
		statement_flags = 0;// no "label = pc" definition yet
		// Parse until end of statement. Only loops if statement
		// contains "label = pc" definition and something else; or
		// if "!ifdef" is true.
		do {
			switch(GotByte) {

				case CHAR_EOS:	// end of statement
				// Ignore now, act later
				// (stops from being "default")
				break;

				case ' ':	// space
				statement_flags |= SF_FOUND_BLANK;
				/*FALLTHROUGH*/

				case CHAR_SOL:	// start of line
				GetByte();// skip
				break;

				case '-':
				parse_backward_anon_def(&statement_flags);
				break;

				case '+':
				GetByte();
				if((GotByte == '.')
				|| (BYTEFLAGS(GotByte) & CONTS_KEYWORD))
					Macro_parse_call();
				else
					parse_forward_anon_def(&statement_flags);
				break;

				case '!':
				parse_pseudo_opcode();
				break;

				case '*':
				parse_pc_def();
				break;

				case '.':
				parse_local_label_def(&statement_flags);
				break;

				default:
				if(BYTEFLAGS(GotByte) & STARTS_KEYWORD) {
					parse_mnemo_or_global_label_def(&statement_flags);
				} else {
					Throw_error(exception_syntax);
					Input_skip_remainder();
				}
			}
		} while(GotByte != CHAR_EOS);	// until end-of-statement
		// adjust program counter
		CPU_pc.intval = (CPU_pc.intval + CPU_2add) & 0xffff;
		CPU_2add = 0;
		// go on with next byte
		GetByte();//NEXTANDSKIPSPACE();
	}
}

// Skip space. If GotByte is CHAR_SOB ('{'), parse block and return TRUE.
// Otherwise (if there is no block), return FALSE.
// Don't forget to call EnsureEOL() afterwards.
bool Parse_optional_block(void) {
	SKIPSPACE();
	if(GotByte != CHAR_SOB)
		return(FALSE);
	Parse_until_eob_or_eof();
	if(GotByte != CHAR_EOB)
		Throw_serious_error(exception_no_right_brace);
	GetByte();
	return(TRUE);
}


// Error handling

// This function will do the actual output for warnings, errors and serious
// errors. It shows the given message string, as well as the current
// context: file name, line number, source type and source title.
static void throw_message(const char* message, const char* type) {
	snprintf(error_message, 100, "assembler: %s - line %d (%s %s): %s\n", type,
		Input_now->line_number,
		Section_now->type, Section_now->title,
		message
	);
	error_message += strlen(error_message);
	//fprintf(stdout, "%d ",strlen(error_message));
//	fprintf(stdout, error_message);
}

// Output a warning.
// This means the produced code looks as expected. But there has been a
// situation that should be reported to the user, for example ACME may have
// assembled a 16-bit parameter with an 8-bit value.
void Throw_warning(const char* message) {
	PLATFORM_WARNING(message);
	throw_message(message, "Warning");
}

// Output a warning if in first pass. See above.
void Throw_first_pass_warning(const char* message) {
	if(pass_count == 0)
		Throw_warning(message);
}

// Output an error.
// This means something went wrong in a way that implies that the output
// almost for sure won't look like expected, for example when there was a
// syntax error. The assembler will try to go on with the assembly though, so
// the user gets to know about more than one of his typos at a time.
void Throw_error(const char* message) {
	PLATFORM_ERROR(message);
	throw_message(message, "Error");
	pass_real_errors++;
	if(pass_real_errors >= max_errors)
		longjmp(exception_env, 0);
		//exit(ACME_finalize(EXIT_FAILURE));
}

// Output a serious error, stopping assembly.
// Serious errors are those that make it impossible to go on with the
// assembly. Example: "!fill" without a parameter - the program counter cannot
// be set correctly in this case, so proceeding would be of no use at all.
void Throw_serious_error(const char* message) {
	PLATFORM_SERIOUS(message);
	throw_message(message, "Serious error");
	longjmp(exception_env, 0);
	//exit(ACME_finalize(EXIT_FAILURE));
}

// Handle bugs
void Bug_found(const char* message, int code) {
	Throw_warning("Bug in ACME, code follows");
	fprintf(stderr, "(0x%x:)", code);
	Throw_serious_error(message);
}
