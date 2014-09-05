//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Macro stuff
#ifndef macro_H
#define macro_H

#include "config.h"


// Prototypes

// create dynamic buffers and arg table
extern void	Macro_init(void);	// create private dynabuf
// only call once (during first pass)
extern void	Macro_parse_definition(void);
// Parse macro call ("+MACROTITLE"). Has to be re-entrant.
extern void	Macro_parse_call(void);


#endif
