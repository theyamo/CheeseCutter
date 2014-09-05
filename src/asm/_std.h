//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Platform specific stuff (in this case, for unknown OSes)
#ifndef platform_H
#define platform_H


// Symbolic constants and macros

// Called once on program startup (could register exit handler, if needed)
#define PLATFORM_INIT		AnyOS_entry()

// Convert UNIX-style pathname to AnyOS-style pathname (no change)
#define PLATFORM_CONVERTPATHCHAR(a)	(a)

// String containing the prefix for accessing files from the library tree
#define PLATFORM_LIBPREFIX	AnyOS_lib_prefix

// Setting the created files' types
#define PLATFORM_SETFILETYPE_CBM(a)
#define PLATFORM_SETFILETYPE_PLAIN(a)
#define PLATFORM_SETFILETYPE_TEXT(a)

// Platform specific message output
#define PLATFORM_WARNING(a)
#define PLATFORM_ERROR(a)
#define PLATFORM_SERIOUS(a)

// Integer-to-character conversion
#define PLATFORM_UINT2CHAR(x)	do {\
	x ^= x >> 16;\
	x ^= x >>  8;\
	x &= 255;\
} while(0)

// Output of platform-specific command line switches
#define PLATFORM_OPTION_HELP

// Processing of platform-specific command line switches
#define PLATFORM_SHORTOPTION_CODE
#define PLATFORM_LONGOPTION_CODE


// Variables
extern char	*AnyOS_lib_prefix;	// header string of library tree


// Prototypes

// used as PLATFORM_INIT: reads "ACME" environment variable
extern void	AnyOS_entry(void);


#endif
