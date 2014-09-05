//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Main definitions
#ifndef acme_H
#define acme_H

#include "config.h"


// Variables
extern const char*	labeldump_filename;
extern const char*	output_filename;
// maximum recursion depth for macro calls and "!source"
extern signed long	macro_recursions_left;
extern signed long	source_recursions_left;


// Prototypes

// Tidy up before exiting by saving label dump
extern int	ACME_finalize(int exit_code);


#endif
