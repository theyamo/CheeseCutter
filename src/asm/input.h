//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Input stuff
#ifndef input_H
#define input_H

#include <stdio.h>
#include <string.h>

// type definitions

// values for input_t component "Src.State"
enum inputstate_t {
	INPUTSTATE_NORMAL,	// everything's fine
	INPUTSTATE_AGAIN,	// re-process last byte
	INPUTSTATE_SKIPBLANKS,	// shrink multiple spaces
	INPUTSTATE_LF,		// send start-of-line after end-of-statement
	INPUTSTATE_CR,		// same, but also remember to skip LF
	INPUTSTATE_SKIPLF,	// skip LF if that's next
	INPUTSTATE_COMMENT,	// skip characters until newline or EOF
	INPUTSTATE_EOB,		// send end-of-block after end-of-statement
	INPUTSTATE_EOF,		// send end-of-file after end-of-statement
};



typedef struct {
	const char*	original_filename;// during RAM reads, too
	int		line_number;	// in file (on RAM reads, too)
	bool		source_is_ram;	// TRUE if RAM, FALSE if file
	enum inputstate_t	state;	// state of input
	union {
		FILE*	fd;	// file descriptor
		char*	ram_ptr;	// RAM read ptr (loop or macro block)
	} src;
	char *string_source;
	int string_source_length;
	int string_source_position;
} input_t;

// Constants
extern const char	FILE_READBINARY[];
// Special characters
// The program *heavily* relies on CHAR_EOS (end of statement) being 0x00!
#define CHAR_EOS	(0)	// end of statement	(in high-level format)
#define CHAR_SOB	'{'	// start of block
#define CHAR_EOB	'}'	// end of block
#define CHAR_SOL	(10)	// start of line	(in high-level format)
#define CHAR_EOF	(13)	// end of file		(in high-level format)
// If the characters above are changed, don't forget to adjust Byte_flags[]!


// Variables
extern input_t*	Input_now;	// current input structure


// Prototypes

// register pseudo opcodes
extern void	Input_init(void);
// Let current input point to start of file
extern void	Input_new_file(char *); 
// get next byte from currently active byte source in shortened high-level
// format. When inside quotes, use GetQuotedByte() instead!
extern char	GetByte(void);
// get next byte from currently active byte source in un-shortened high-level
// format. Complains if CHAR_EOS (end of statement) is read.
extern char	GetQuotedByte(void);
// Skip remainder of statement, for example on error
extern void	Input_skip_remainder(void);
// Ensure that the remainder of the current statement is empty, for example
// after mnemonics using implied addressing.
extern void	Input_ensure_EOS(void);
// Skip or store block (starting with next byte, so call directly after
// reading opening brace).
// If "Store" is TRUE, the block is read into GlobalDynaBuf, then a copy
// is made and a pointer to that is returned.
// If "Store" is FALSE, NULL is returned.
// After calling this function, GotByte holds '}'. Unless EOF was found first,
// but then a serious error would have been thrown.
extern char*	Input_skip_or_store_block(bool store);
// Read bytes and add to GlobalDynaBuf until the given terminator (or CHAR_EOS)
// is found. Act upon single and double quotes by entering (and leaving) quote
// mode as needed (So the terminator does not terminate when inside quotes).
extern void	Input_until_terminator(char terminator);
// Append to GlobalDynaBuf while characters are legal for keywords.
// Throws "missing string" error if none. Returns number of characters added.
extern int	Input_append_keyword_to_global_dynabuf(void);
// Check whether GotByte is a dot.
// If not, store global zone value.
// If yes, store current zone value and read next byte.
// Then jump to Input_read_keyword(), which returns length of keyword.
extern int	Input_read_zone_and_keyword(zone_t*);
// Clear dynamic buffer, then append to it until an illegal (for a keyword)
// character is read. Zero-terminate the string. Return its length (without
// terminator).
// Zero lengths will produce a "missing string" error.
extern int	Input_read_keyword(void);
// Clear dynamic buffer, then append to it until an illegal (for a keyword)
// character is read. Zero-terminate the string, then convert to lower case.
// Return its length (without terminator).
// Zero lengths will produce a "missing string" error.
extern int	Input_read_and_lower_keyword(void);
// Try to read a file name. If "allow_library" is TRUE, library access by using
// <...> quoting is possible as well. The file name given in the assembler
// source code is converted from UNIX style to platform style.
// Returns whether error occurred (TRUE on error). Filename in GlobalDynaBuf.
// Errors are handled and reported, but caller should call
// Input_skip_remainder() then.
extern bool	Input_read_filename(bool library_allowed);
// Try to read a comma, skipping spaces before and after. Return TRUE if comma
// found, otherwise FALSE.
extern bool	Input_accept_comma(void);
// read optional info about parameter length
extern int	Input_get_force_bit(void);


#endif
