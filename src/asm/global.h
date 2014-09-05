//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Global stuff - things that are needed by several modules
#ifndef global_H
#define global_H

#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>
#include "config.h"


// Constants

#define SF_FOUND_BLANK		(1u)	// statement had space or tab
#define SF_IMPLIED_LABEL	(2u)	// statement had implied label def
extern const char	s_65816[];
extern const char	s_and[];
extern const char	s_asl[];
extern const char	s_asr[];
extern const char	s_brl[];
extern const char	s_cbm[];
extern const char	s_eor[];
extern const char	s_error[];
extern const char	s_lsr[];
extern const char	s_scrxor[];
// Error messages during assembly
extern const char	exception_cannot_open_input_file[];
extern const char	exception_missing_string[];
extern const char	exception_no_left_brace[];
extern const char	exception_no_memory_left[];
extern const char	exception_no_right_brace[];
//extern const char	exception_not_yet[];
extern const char	exception_number_out_of_range[];
extern const char	exception_pc_undefined[];
extern const char	exception_syntax[];
// Byte flags table
extern const char	Byte_flags[];
#define BYTEFLAGS(c)	(Byte_flags[(unsigned char) c])
#define STARTS_KEYWORD	(1u << 7)	// Byte is allowed to start a keyword
#define CONTS_KEYWORD	(1u << 6)	// Byte is allowed in a keyword
#define BYTEIS_UPCASE	(1u << 5)	// Byte is upper case and can be
			// converted to lower case by OR-ing this bit(!)
#define BYTEIS_SYNTAX	(1u << 4)	// special character for input syntax
#define FOLLOWS_ANON	(1u << 3)	// preceding '-' are backward label
// bits 2, 1 and 0 are unused


// Variables

extern node_t*		pseudo_opcode_tree;// tree to hold pseudo opcodes
// structures
enum eos_t {
	SKIP_REMAINDER,		// skip remainder of line - (after errors)
	ENSURE_EOS,		// make sure there's nothing left in statement
	PARSE_REMAINDER,	// parse what's left
	AT_EOS_ANYWAY,		// actually, same as PARSE_REMAINDER
};
extern int	pass_count;
extern int	Process_verbosity;// Level of additional output
extern char	GotByte;// Last byte read (processed)
// Global counters
extern int	pass_undefined_count;// "NeedValue" type errors in current pass
extern int	pass_real_errors;	// Errors yet
extern signed long	max_errors;	// errors before giving up
extern FILE*	msg_stream;		// set to stdout by --errors_to_stdout
extern jmp_buf exception_env;
extern char* error_message;
//extern int cbm_load_address;

// Macros for skipping a single space character
#define SKIPSPACE()		do {if(GotByte   == ' ') GetByte();} while(0)
#define NEXTANDSKIPSPACE()	do {if(GetByte() == ' ') GetByte();} while(0)


// Prototypes

// Allocate memory and die if not available
extern inline void*	safe_malloc(size_t);
// Parse block, beginning with next byte.
// End reason (either CHAR_EOB or CHAR_EOF) can be found in GotByte afterwards
// Has to be re-entrant.
extern void	Parse_until_eob_or_eof(void);
// Skip space. If GotByte is CHAR_SOB ('{'), parse block and return TRUE.
// Otherwise (if there is no block), return FALSE.
// Don't forget to call EnsureEOL() afterwards.
extern int	Parse_optional_block(void);
// Output a warning.
// This means the produced code looks as expected. But there has been a
// situation that should be reported to the user, for example ACME may have
// assembled a 16-bit parameter with an 8-bit value.
extern void	Throw_warning(const char*);
// Output a warning if in first pass. See above.
extern void	Throw_first_pass_warning(const char*);
// Output an error.
// This means something went wrong in a way that implies that the output
// almost for sure won't look like expected, for example when there was a
// syntax error. The assembler will try to go on with the assembly though, so
// the user gets to know about more than one of his typos at a time.
extern void	Throw_error(const char*);
// Output a serious error, stopping assembly.
// Serious errors are those that make it impossible to go on with the
// assembly. Example: "!fill" without a parameter - the program counter cannot
// be set correctly in this case, so proceeding would be of no use at all.
extern void	Throw_serious_error(const char*);
// Handle bugs
extern void	Bug_found(const char*, int);


#endif
