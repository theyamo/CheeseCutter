//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Character encoding stuff
#ifndef encoding_H
#define encoding_H


// Prototypes

// register pseudo opcodes and build keyword tree for encoders
extern void	Encoding_init(void);
// convert character using current encoding
extern char	(*Encoding_encode_char)(char);
// Set "raw" as default encoding
extern void	Encoding_passinit(void);


#endif
