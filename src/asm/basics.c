//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// basic assembly stuff

#include <stdlib.h>
#include <stdio.h>
#include "config.h"
#include "cpu.h"
#include "basics.h"
#include "alu.h"
#include "dynabuf.h"
#include "input.h"
#include "global.h"
#include "output.h"
#include "tree.h"


// Constants
#define USERMSG_DYNABUF_INITIALSIZE	80
static const char	s_08[]	= "08";
#define s_8	(s_08+1)	// Yes, I know I'm sick
#define s_16	(s_65816+3)	// Yes, I know I'm sick


// Variables
static dynabuf_t*	user_message;	// dynamic buffer (!warn/error/serious)


// Functions

// Helper function for !8, !16, !24 and !32 pseudo opcodes
static enum eos_t output_objects(void (*fn)(intval_t)) {
	do
		fn(ALU_any_int());
	while(Input_accept_comma());
	return(ENSURE_EOS);
}

// Insert 8-bit values ("!08" / "!8" / "!by" / "!byte" pseudo opcode)
static enum eos_t PO_08(void) {
	return(output_objects(Output_8b));
}

// Insert 16-bit values ("!16" / "!wo" / "!word" pseudo opcode)
static enum eos_t PO_16(void) {
	return(output_objects(Output_16b));
}

// Insert 24-bit values ("!24" pseudo opcode)
static enum eos_t PO_24(void) {
	return(output_objects(Output_24b));
}

// Insert 32-bit values ("!32" pseudo opcode)
static enum eos_t PO_32(void) {
	return(output_objects(Output_32b));
}

// Include binary file
static enum eos_t PO_binary(void) {
	FILE*		fd;
	int		byte;
	intval_t	size	= -1,	// means "not given" => "until EOF"
			skip	= 0;

	// if file name is missing, don't bother continuing
	if(Input_read_filename(TRUE))
		return(SKIP_REMAINDER);
	// try to open file
	fd = fopen(GLOBALDYNABUF_CURRENT, FILE_READBINARY);
	if(fd == NULL) {
		Throw_error(exception_cannot_open_input_file);
		return(SKIP_REMAINDER);
	}
	// read optional arguments
	if(Input_accept_comma()) {
		if(ALU_optional_defined_int(&size)
		&& (size <0))
			Throw_serious_error("Negative size argument.");
		if(Input_accept_comma())
			ALU_optional_defined_int(&skip);// read skip
	}
	// check whether including is a waste of time
	if((size >= 0) && (pass_undefined_count || pass_real_errors))
		Output_fake(size);	// really including is useless anyway
	else {
		// really insert file
		fseek(fd, skip, SEEK_SET);	// set read pointer
		// if "size" non-negative, read "size" bytes.
		// otherwise, read until EOF.
		while(size != 0) {
			byte = getc(fd);
			if(byte == EOF)
				break;
			Output_byte(byte);
			size--;
		}
		// if more should have been read, warn and add padding
		if(size > 0) {
			Throw_warning("Padding with zeroes.");
			do
				Output_byte(0);
			while(--size);
		}
	}
	fclose(fd);
	// if verbose, produce some output
	if((pass_count == 0) && (Process_verbosity > 1))
		printf("Loaded %d ($%x) bytes from file offset %ld ($%lx).\n",
		CPU_2add, CPU_2add, skip, skip);
	return(ENSURE_EOS);
}

// Reserve space by sending bytes of given value ("!fi" / "!fill" pseudo opcode)
static enum eos_t PO_fill(void) {
	intval_t	fill	= FILLVALUE_FILL,
			size	= ALU_defined_int();

	if(Input_accept_comma())
		fill = ALU_any_int();
	while(size--)
		Output_8b(fill);
	return(ENSURE_EOS);
}

// show user-defined message
static enum eos_t throw_string(const char prefix[], void (*fn)(const char*)) {
	result_t	result;

	DYNABUF_CLEAR(user_message);
	DynaBuf_add_string(user_message, prefix);
	do {
		if(GotByte == '"') {
			// parse string
			GetQuotedByte();	// read initial character
			// send characters until closing quote is reached
			while(GotByte && (GotByte != '"')) {
				DYNABUF_APPEND(user_message, GotByte);
				GetQuotedByte();
			}
			if(GotByte == CHAR_EOS)
				return(AT_EOS_ANYWAY);
			// after closing quote, proceed with next char
			GetByte();
		} else {
			// parse value
			ALU_any_result(&result);
			if(result.flags & MVALUE_IS_FP) {
				// floating point
				if(result.flags & MVALUE_DEFINED)
					DynaBuf_add_double(
						user_message,
						result.val.fpval);
				else
					DynaBuf_add_string(
						user_message,
						"<UNDEFINED FLOAT>");
			} else {
				// integer
				if(result.flags & MVALUE_DEFINED)
					DynaBuf_add_signed_long(
						user_message,
						result.val.intval);
				else
					DynaBuf_add_string(
						user_message,
						"<UNDEFINED INT>");
			}
		}
	} while(Input_accept_comma());
	DynaBuf_append(user_message, '\0');
	fn(user_message->buffer);
	return(ENSURE_EOS);
}

////
//static enum eos_t PO_print(void) {
//	return(throw_string());
//}

// throw warning as given in source code
static enum eos_t PO_warn(void) {
	return(throw_string("!warn: ", Throw_warning));
}

// throw error as given in source code
static enum eos_t PO_error(void) {
	return(throw_string("!error: ", Throw_error));
}

// throw serious error as given in source code
static enum eos_t PO_serious(void) {
	return(throw_string("!serious: ", Throw_serious_error));
}

// pseudo ocpode table
static node_t	pseudo_opcodes[]	= {
	PREDEFNODE(s_08,	PO_08),
	PREDEFNODE(s_8,		PO_08),
	PREDEFNODE("by",	PO_08),
	PREDEFNODE("byte",	PO_08),
	PREDEFNODE(s_16,	PO_16),
	PREDEFNODE("wo",	PO_16),
	PREDEFNODE("word",	PO_16),
	PREDEFNODE("24",	PO_24),
	PREDEFNODE("32",	PO_32),
	PREDEFNODE("bin",	PO_binary),
	PREDEFNODE("binary",	PO_binary),
	PREDEFNODE("fi",	PO_fill),
	PREDEFNODE("fill",	PO_fill),
//	PREDEFNODE("print",	PO_print),
	PREDEFNODE("warn",	PO_warn),
	PREDEFNODE(s_error,	PO_error),
	PREDEFLAST("serious",	PO_serious),
	//    ^^^^ this marks the last element
};

// register pseudo opcodes and create dynamic buffer
void Basics_init(void) {
	user_message = DynaBuf_create(USERMSG_DYNABUF_INITIALSIZE);
	Tree_add_table(&pseudo_opcode_tree, pseudo_opcodes);
}
