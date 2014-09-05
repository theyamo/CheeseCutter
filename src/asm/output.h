//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Output stuff
#ifndef output_H
#define output_H

#include <stdio.h>
#include "config.h"


// Constants
#define MEMINIT_USE_DEFAULT	256


// Prototypes

// Init file format tree (is done early)
extern void	Outputfile_init(void);
// alloc and init mem buffer, register pseudo opcodes (done later)
extern void	Output_init(signed long fill_value);
// clear segment list
extern void	Output_passinit(signed long start_addr);
// call this if really calling Output_byte would be a waste of time
extern void	Output_fake(int size);
// Send low byte of arg to output buffer and advance pointer
extern void	(*Output_byte)(intval_t);
// Output 8-bit value with range check
extern void	Output_8b(intval_t);
// Output 16-bit value with range check
extern void	Output_16b(intval_t);
// Output 24-bit value with range check
extern void	Output_24b(intval_t);
// Output 32-bit value (without range check)
extern void	Output_32b(intval_t);
// Try to set output format held in DynaBuf. Returns whether succeeded.
extern bool	Output_set_output_format(void);
// write smallest-possible part of memory buffer to file
extern void	Output_save_file(FILE* fd);
// send final output as binary
extern char* Output_get_final_data();
// Call when "*=EXPRESSION" is parsed
extern void	Output_start_segment(void);
// Show start and end of current segment
extern void	Output_end_segment(void);


#endif
