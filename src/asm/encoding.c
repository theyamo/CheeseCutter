//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Character encoding stuff

#include <stdio.h>
#include <string.h>
#include "alu.h"
#include "acme.h"
#include "dynabuf.h"
#include "encoding.h"
#include "global.h"
#include "output.h"
#include "input.h"
#include "tree.h"


// Encoder function type definition
typedef char (*encoder_t)(char)	;


// Constants
static const char	s_pet[]		= "pet";
static const char	s_raw[]		= "raw";
static const char	s_scr[]		= "scr";


// Variables
static char	outermost_table[256];	// space for encoding table...
static char*	loaded_table	= outermost_table;	// ...loaded from file
// predefined stuff
static node_t*	encoder_tree	= NULL;	// tree to hold encoders


// Functions

// convert character using current encoding
// Conversion function pointer. No init needed: gets set before each pass.
char		(*Encoding_encode_char)(char);

// Insert string(s)
static enum eos_t encode_string(encoder_t inner_encoder, char eor) {
	encoder_t	outer_encoder	= Encoding_encode_char;// buffer encoder

	// make given encoder the current one (for ALU-parsed values)
	Encoding_encode_char = inner_encoder;
	do {
		if(GotByte == '"') {
			// read initial character
			GetQuotedByte();
			// send characters until closing quote is reached
			while(GotByte && (GotByte != '"')) {
				Output_8b(eor ^ Encoding_encode_char(GotByte));
				GetQuotedByte();
			}
			if(GotByte == CHAR_EOS)
				return(AT_EOS_ANYWAY);
			// after closing quote, proceed with next char
			GetByte();
		} else {
			// Parse value. No problems with single characters
			// because the current encoding is
			// temporarily set to the given one.
			Output_8b(ALU_any_int());
		}
	} while(Input_accept_comma());
	Encoding_encode_char = outer_encoder;	// reactivate buffered encoder
	return(ENSURE_EOS);
}

// Insert text string (default format)
static enum eos_t PO_text(void) {
	return(encode_string(Encoding_encode_char, 0));
}

// convert raw to raw (do not convert at all)
static char encoder_raw(char byte) {
	return(byte);
}

// Insert raw string
static enum eos_t PO_raw(void) {
	return(encode_string(encoder_raw, 0));
}

// convert raw to petscii
static char encoder_pet(char byte) {
	if((byte >= 'A') && (byte <= 'Z'))
		return((char) (byte | 0x80));	// FIXME - check why SAS-C
	if((byte >= 'a') && (byte <= 'z'))	//	wants these casts.
		return((char)(byte - 32));	//	There are more below.
	return(byte);
}

// Insert PetSCII string
static enum eos_t PO_pet(void) {
	return(encode_string(encoder_pet, 0));
}

// convert raw to C64 screencode
static char encoder_scr(char byte) {
	if((byte >= 'a') && (byte <= 'z'))
		return((char)(byte - 96));	// shift uppercase down
	if((byte >= '[') && (byte <= '_'))
		return((char)(byte - 64));	// shift [\]^_ down
	if(byte == '`')
		return(64);	// shift ` down
	if(byte == '@')
		return(0);	// shift @ down
	return(byte);
}

// Insert screencode string
static enum eos_t PO_scr(void) {
	return(encode_string(encoder_scr, 0));
}

// Insert screencode string, EOR'd
static enum eos_t PO_scrxor(void) {
	intval_t	num	= ALU_any_int();

	if(Input_accept_comma())
		return(encode_string(encoder_scr, num));
	Throw_error(exception_syntax);
	return(SKIP_REMAINDER);
}

// Switch to CBM mode ("!cbm" pseudo opcode)
static enum eos_t PO_cbm(void) {
	Encoding_encode_char = encoder_pet;
	// output deprecation warning
	Throw_first_pass_warning("\"!cbm\" is deprecated; use \"!ct pet\" instead.");
	return(ENSURE_EOS);
}

//
static char encoder_file(char byte) {
	return(loaded_table[(unsigned char) byte]);
}

// read encoding table from file
static enum eos_t user_defined_encoding(void) {
	FILE*		fd;
	char		local_table[256],
			*buffered_table		= loaded_table;
	encoder_t	buffered_encoder	= Encoding_encode_char;

	// if file name is missing, don't bother continuing
	if(Input_read_filename(TRUE))
		return(SKIP_REMAINDER);
	fd = fopen(GLOBALDYNABUF_CURRENT, FILE_READBINARY);
	if(fd) {
		if(fread(local_table, sizeof(char), 256, fd) != 256)
			Throw_error("Conversion table incomplete.");
		fclose(fd);
	} else
		Throw_error(exception_cannot_open_input_file);
	Encoding_encode_char = encoder_file;	// activate new encoding
	loaded_table = local_table;		// activate local table
	// If there's a block, parse that and then restore old values
	if(Parse_optional_block())
		Encoding_encode_char = buffered_encoder;
	else
		// if there's *no* block, the table must be used from now on.
		// copy the local table to the "outer" table
		memcpy(buffered_table, local_table, 256);
	// re-activate "outer" table (it might have been changed by memcpy())
	loaded_table = buffered_table;
	return(ENSURE_EOS);
}

// use one of the pre-defined encodings (raw, pet, scr)
static enum eos_t predefined_encoding(void) {
	void*		node_body;
	char		local_table[256],
			*buffered_table		= loaded_table;
	encoder_t	buffered_encoder	= Encoding_encode_char;

	// use one of the pre-defined encodings
	if(Input_read_and_lower_keyword()) {
		// search for tree item
		if(Tree_easy_scan(encoder_tree, &node_body, GlobalDynaBuf))
			Encoding_encode_char = (encoder_t) node_body;// activate new encoder
		else
			Throw_error("Unknown encoding.");
	}
	loaded_table = local_table;	// activate local table
	// If there's a block, parse that and then restore old values
	if(Parse_optional_block())
		Encoding_encode_char = buffered_encoder;
	// re-activate "outer" table
	loaded_table = buffered_table;
	return(ENSURE_EOS);
}

// Set current encoding ("!convtab" pseudo opcode)
static enum eos_t PO_convtab(void) {
	if((GotByte == '<') || (GotByte == '"'))
		return(user_defined_encoding());
	else
		return(predefined_encoding());
}

// pseudo opcode table
static node_t	pseudo_opcodes[]	= {
	PREDEFNODE(s_cbm,	PO_cbm),
	PREDEFNODE("ct",	PO_convtab),
	PREDEFNODE("convtab",	PO_convtab),
	PREDEFNODE(s_pet,	PO_pet),
	PREDEFNODE(s_raw,	PO_raw),
	PREDEFNODE(s_scr,	PO_scr),
	PREDEFNODE(s_scrxor,	PO_scrxor),
	PREDEFNODE("text",	PO_text),
	PREDEFLAST("tx",	PO_text),
	//    ^^^^ this marks the last element
};

// keywords for "!convtab" pseudo opcode
static node_t	encoders[]	= {
	PREDEFNODE(s_pet,	encoder_pet),
	PREDEFNODE(s_raw,	encoder_raw),
	PREDEFLAST(s_scr,	encoder_scr),
	//    ^^^^ this marks the last element
};


// Exported functions

// register pseudo opcodes and build keyword tree for encoders
void Encoding_init(void) {
	Tree_add_table(&encoder_tree, encoders);
	Tree_add_table(&pseudo_opcode_tree, pseudo_opcodes);
}

// Set "raw" as default encoding
void Encoding_passinit(void) {
	Encoding_encode_char = encoder_raw;
}
