//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Section stuff

#include "config.h"
#include "dynabuf.h"
#include "global.h"
#include "input.h"
#include "tree.h"
#include "section.h"


// Constants
static const char	type_zone[]	= "Zone";
static const char	s_subzone[]	= "subzone";
#define s_zone	(s_subzone+3)	// Yes, I know I'm sick
static char		untitled[]	= "<untitled>";
// ...is actually constant, but flagging it "const" results in heap of warnings

// fake section structure (for error msgs before any real section is in use)
static section_t	initial_section	= {
	0,		// zone value
	"during",	// "type"	=> normally "zone Title" or
	"init",		// "title"	=>  "macro test", now "during init"
	FALSE,		// no, title was not malloc'd
};


// Variables
section_t*		Section_now	= &initial_section;// current section
static section_t	outer_section;	// outermost section struct
static zone_t		zone_max;	// Highest zone number yet

// Write given info into given zone structure and activate it
void Section_new_zone(section_t* section, const char* type, char* title, bool allocated) {
	section->zone = ++zone_max;
	section->type = type;
	section->title = title;
	section->allocated = allocated;
	// activate new section
	Section_now = section;
}

// Tidy up: If necessary, release section title.
// Warning - the state of the component "Allocd" may have
// changed in the meantime, so don't rely on a local variable.
void Section_finalize(section_t* section) {
	if(section->allocated)
		free(section->title);
}

// Switch to new zone ("!zone" or "!zn"). Has to be re-entrant.
static enum eos_t PO_zone(void) {
	section_t	entry_values;// buffer for outer zone
	char*		new_title;
	bool		allocated;

	// remember everything about current structure
	entry_values = *Section_now;
	// set default values in case there is no valid title
	new_title = untitled;
	allocated = FALSE;
	// Check whether a zone title is given. If yes and it can be read,
	// get copy, remember pointer and remember to free it later on.
	if(BYTEFLAGS(GotByte) & CONTS_KEYWORD) {
		// Because we know of one character for sure,
		// there's no need to check the return value.
		Input_read_keyword();
		new_title = DynaBuf_get_copy(GlobalDynaBuf);
		allocated = TRUE;
	}
	// setup new section
	// section type is "subzone", just in case a block follows
	Section_new_zone(Section_now, "Subzone", new_title, allocated);
	if(Parse_optional_block()) {
		// Block has been parsed, so it was a SUBzone.
		Section_finalize(Section_now);// end inner zone
		*Section_now = entry_values;// restore entry values
	} else {
		// no block found, so it's a normal zone change
		Section_finalize(&entry_values);// end outer zone
		Section_now->type = type_zone;// change type to "zone"
	}
	return(ENSURE_EOS);
}

// Start subzone ("!subzone" or "!sz"). Has to be re-entrant.
static enum eos_t PO_subzone(void) {
	// output deprecation warning
	Throw_first_pass_warning("\"!subzone {}\" is deprecated; use \"!zone {}\" instead.");
	// call "!zone" instead
	return(PO_zone());
}

// predefined stuff
static node_t	pseudo_opcodes[]	= {
	PREDEFNODE(s_zone,	PO_zone),
	PREDEFNODE("zn",	PO_zone),
	PREDEFNODE(s_subzone,	PO_subzone),
	PREDEFLAST("sz",	PO_subzone),
	//    ^^^^ this marks the last element
};

// register pseudo opcodes
void Section_init(void) {
	Tree_add_table(&pseudo_opcode_tree, pseudo_opcodes);
}

// Setup outermost section
void Section_passinit(void) {
	zone_max = ZONE_GLOBAL;// will be incremented by next line
	Section_new_zone(&outer_section, type_zone, untitled, FALSE);
}
