//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Label stuff
#ifndef label_H
#define label_H

#include <stdio.h>


// "label" structure type definition
struct label_t {
	struct result_t	result;	// Expression flags and value
	int		usage;	// usage count
	int		pass;	// pass of creation (for anon counters)
};


// Variables
extern node_ra_t*	Label_forest[];	// trees (because of 8-bit hash)


// Prototypes

// register pseudo opcodes and clear label forest
extern void	Label_init(void);
// function acts upon the label's flag bits and produces an error if needed.
extern void	Label_set_value(label_t*, result_t*, bool change_allowed);
// Parse implicit label definition (can be either global or local).
// Name must be held in GlobalDynaBuf.
extern void	Label_implicit_definition(zone_t zone, int stat_flags, int force_bit, bool change);
// Parse label definition (can be either global or local).
// Name must be held in GlobalDynaBuf.
extern void	Label_parse_definition(zone_t zone, int stat_flags);
// Search for label. Create if nonexistant. If created, assign flags.
// Name must be held in GlobalDynaBuf.
extern label_t*	Label_find(zone_t, int flags);
// Dump global labels to file
extern void	Label_dump_all(FILE* fd);
// Fix name of anonymous forward label (held in GlobalDynaBuf, NOT TERMINATED!)
// so it references the *next* anonymous forward label definition.
extern label_t*	Label_fix_forward_name(void);


#endif
