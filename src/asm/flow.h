//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Flow control stuff (loops, conditional assembly etc.)
#ifndef flow_H
#define flow_H

#include <stdio.h>
#include "config.h"


// Prototypes

// register pseudo opcodes and build keyword tree for until/while
extern void	Flow_init(void);
// Parse a whole source code file
extern void	Parse_source(const char*);


#endif
