//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Dynamic buffer stuff
#ifndef dynabuf_H
#define dynabuf_H

#include "config.h"


// Macros
#define DYNABUF_CLEAR(db)		{db->size = 0;}
#define DYNABUF_APPEND(db, byte)	do {\
	if(db->size == db->reserved)\
		DynaBuf_enlarge(db);\
	db->buffer[(db->size)++] = byte;\
} while(0)
// The next one is dangerous - the buffer location can change when a character
// is appended. So after calling this, don't change the buffer as long as you
// use the address.
#define GLOBALDYNABUF_CURRENT		(GlobalDynaBuf->buffer)


// dynamic buffer structure
struct dynabuf_t {
	char*	buffer;		// pointer to buffer
	int	size;		// size of buffer's used portion
	int	reserved;	// total size of buffer
};
typedef struct dynabuf_t dynabuf_t;


// Variables
extern dynabuf_t*	GlobalDynaBuf;	// global dynamic buffer


// Prototypes

// create global DynaBuf (call once on program startup)
extern void	DynaBuf_init(void);
// create (private) DynaBuf
extern dynabuf_t*	DynaBuf_create(int initial_size);
// call whenever buffer is too small
extern void	DynaBuf_enlarge(dynabuf_t* db);
// return malloc'd copy of buffer contents
extern char*	DynaBuf_get_copy(dynabuf_t* db);
// copy string to buffer (without terminator)
extern void	DynaBuf_add_string(dynabuf_t* db, const char*);
// add string version of int to buffer (without terminator)
extern void	DynaBuf_add_signed_long(dynabuf_t* db, signed long value);
// add string version of float to buffer (without terminator)
extern void	DynaBuf_add_double(dynabuf_t* db, double value);
// converts buffer contents to lower case
extern void	DynaBuf_to_lower(dynabuf_t* target, dynabuf_t* source);
// add char to buffer
extern void	DynaBuf_append(dynabuf_t* db, char);


#endif
