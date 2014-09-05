//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Platform specific stuff (in this case, for unknown OSes)
#ifndef platform_C
#define platform_C

#include <stdlib.h>
#include "dynabuf.h"


// Variables
char	*AnyOS_lib_prefix	= NULL;	// header string of library tree


// Functions

// used as PLATFORM_INIT: reads "ACME" environment variable
void AnyOS_entry(void) {
	char	*env_var;

	// Find out the path of ACME's library
	env_var = getenv("ACME");
	// if environment variable was found, make a copy
	if(env_var) {
		DYNABUF_CLEAR(GlobalDynaBuf);
		// copy environment variable to global dynamic buffer
		DynaBuf_add_string(GlobalDynaBuf, env_var);
		DynaBuf_append(GlobalDynaBuf, '/');	// add dir separator
		DynaBuf_append(GlobalDynaBuf, '\0');	// add terminator
		AnyOS_lib_prefix = DynaBuf_get_copy(GlobalDynaBuf);
	}
}


#endif
