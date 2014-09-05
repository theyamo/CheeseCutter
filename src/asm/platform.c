//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Platform specific stuff

#include "config.h"
#include "platform.h"


// Amiga
#ifdef _AMIGA
#ifndef platform_C
#define platform_C
// Nothing here - Amigas don't need no stinkin' platform-specific stuff!
#endif
#endif

// DOS and OS/2
#ifdef __DJGPP__
#include "_dos.c"
#endif
#ifdef __OS2__
#include "_dos.c"
#endif
//#ifdef __Windows__
//#include "_dos.c"
//#endif

// RISC OS
#ifdef __riscos__
#include "_riscos.c"
#endif

// add further platform files here

// Unix/Linux/others (surprisingly also works on Windows)
#include "_std.c"
