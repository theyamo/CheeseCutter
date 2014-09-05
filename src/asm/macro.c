//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Macro stuff

#include <string.h>	// needs strlen() + memcpy()
#include "config.h"
#include "platform.h"	// done first in case "inline" is redefined
#include "acme.h"
#include "alu.h"
#include "dynabuf.h"
#include "global.h"
#include "input.h"
#include "label.h"
#include "section.h"
#include "tree.h"
#include "macro.h"


// Constants
#define MACRONAME_DYNABUF_INITIALSIZE	128
#define ARG_SEPARATOR	' '	// separates macro title from arg types
#define ARGTYPE_NUM_VAL	'v'
#define ARGTYPE_NUM_REF	'V'
//#define ARGTYPE_STR_VAL	's'
//#define ARGTYPE_STR_REF	'S'
#define REFERENCE_CHAR	'~'	// prefix for call-by-reference
#define HALF_INITIAL_ARG_TABLE_SIZE	4
static const char	exception_macro_twice[]	= "Macro already defined.";


// macro struct type definition
struct macro_t {
	int	def_line_number;// line number of definition	for error msgs
	char*	def_filename;	// file name of definition	for error msgs
	char*	original_name;	// user-supplied name		for error msgs
	char*	parameter_list;	// parameters (whole line)
	char*	body;	// RAM block containing macro body
};
// there's no need to make this a struct and add a type component:
// when the macro has been found, accessing its parameter_list component
// gives us the possibility to find out which args are call-by-value and
// which ones are call-by-reference.
union macro_arg_t {
	result_t	result;	// value and flags (call by value)
	label_t*	label;	// pointer to label struct (call by reference)
};


// Variables
static dynabuf_t*	user_macro_name;	// original macro title
static dynabuf_t*	internal_name;		// plus param type chars
static node_ra_t*	macro_forest[256];	// trees (because of 8b hash)
// Dynamic argument table
static union macro_arg_t*	arg_table	= NULL;
static int			argtable_size	= HALF_INITIAL_ARG_TABLE_SIZE;


// Functions

// Enlarge the argument table
static void enlarge_arg_table(void) {
	argtable_size *= 2;
	arg_table =
		realloc(arg_table, argtable_size * sizeof(union macro_arg_t));
	if(arg_table == NULL)
		Throw_serious_error(exception_no_memory_left);
}

// create dynamic buffers and arg table
void Macro_init(void) {
	user_macro_name = DynaBuf_create(MACRONAME_DYNABUF_INITIALSIZE);
	internal_name = DynaBuf_create(MACRONAME_DYNABUF_INITIALSIZE);
	enlarge_arg_table();
}

// Read macro zone and title. Title is read to GlobalDynaBuf and then copied
// over to internal_name DynaBuf, where ARG_SEPARATOR is added.
// In user_macro_name DynaBuf, the original name is reconstructed (even with
// '.' prefix) so a copy can be linked to the resulting macro struct.
static zone_t get_zone_and_title(void) {
	zone_t	macro_zone;

	Input_read_zone_and_keyword(&macro_zone);	// skips spaces before
	// now GotByte = illegal character after title
	// copy macro title to private dynabuf and add separator character
	DYNABUF_CLEAR(user_macro_name);
	DYNABUF_CLEAR(internal_name);
	if(macro_zone != ZONE_GLOBAL)
		DynaBuf_append(user_macro_name, '.');
	DynaBuf_add_string(user_macro_name, GLOBALDYNABUF_CURRENT);
	DynaBuf_add_string(internal_name, GLOBALDYNABUF_CURRENT);
	DynaBuf_append(user_macro_name, '\0');
	DynaBuf_append(internal_name, ARG_SEPARATOR);
	SKIPSPACE();// done here once so it's not necessary at two callers
	return(macro_zone);
}

// Check for comma. If there, append to GlobalDynaBuf.
static inline bool pipe_comma(void) {
	bool	result;

	result = Input_accept_comma();
	if(result)
		DYNABUF_APPEND(GlobalDynaBuf, ',');
	return(result);
}

// Return malloc'd copy of string
static char* get_string_copy(const char* original) {
	size_t	size;
	char*	copy;

	size = strlen(original) + 1;
	copy = safe_malloc(size);
	memcpy(copy, original, size);
	return(copy);
}

// This function is called from both macro definition and macro call.
// Terminate macro name and copy from internal_name to GlobalDynaBuf
// (because that's where Tree_hard_scan() looks for the search string).
// Then try to find macro and return whether it was created.
static bool search_for_macro(node_ra_t** result, zone_t zone, bool create) {
	DynaBuf_append(internal_name, '\0');	// terminate macro name
	// now internal_name = macro_title SPC argument_specifiers NUL
	DYNABUF_CLEAR(GlobalDynaBuf);
	DynaBuf_add_string(GlobalDynaBuf, internal_name->buffer);
	DynaBuf_append(GlobalDynaBuf, '\0');
	return(Tree_hard_scan(result, macro_forest, zone, create));
}

// This function is called when an already existing macro is re-defined.
// It first outputs a warning and then a serious error, stopping assembly.
// Showing the first message as a warning guarantees that ACME does not reach
// the maximum error limit inbetween.
static void report_redefinition(node_ra_t* macro_node) {
	struct macro_t*	original_macro	= macro_node->body;

	// show warning with location of current definition
	Throw_warning(exception_macro_twice);
	// CAUTION, ugly kluge: fiddle with Input_now and Section_now
	// data to generate helpful error messages
	Input_now->original_filename = original_macro->def_filename;
	Input_now->line_number = original_macro->def_line_number;
	Section_now->type = "original";
	Section_now->title = "definition";
	// show serious error with location of original definition
	Throw_serious_error(exception_macro_twice);
}

// This function is only called during the first pass, so there's no need to
// check whether to skip the definition or not.
// Return with GotByte = '}'
void Macro_parse_definition(void) {// Now GotByte = illegal char after "!macro"
	char*		formal_parameters;
	node_ra_t*	macro_node;
	struct macro_t*	new_macro;
	zone_t		macro_zone	= get_zone_and_title();

	// now GotByte = first non-space after title
	DYNABUF_CLEAR(GlobalDynaBuf);	// prepare to hold formal parameters
	// GlobalDynaBuf = "" (will hold formal parameter list)
	// user_macro_name = ['.'] MacroTitle NUL
	// internal_name = MacroTitle ARG_SEPARATOR (grows to signature)
	// Accept n>=0 comma-separated formal parameters before CHAR_SOB ('{').
	// Valid argument formats are:
	// .LOCAL_LABEL_BY_VALUE
	// ~.LOCAL_LABEL_BY_REFERENCE
	// GLOBAL_LABEL_BY_VALUE	global args are very uncommon,
	// ~GLOBAL_LABEL_BY_REFERENCE	but not forbidden
	// now GotByte = non-space
	if(GotByte != CHAR_SOB) {	// any at all?
		do {
			// handle call-by-reference character ('~')
			if(GotByte != REFERENCE_CHAR)
				DynaBuf_append(internal_name, ARGTYPE_NUM_VAL);
			else {
				DynaBuf_append(internal_name, ARGTYPE_NUM_REF);
				DynaBuf_append(GlobalDynaBuf, REFERENCE_CHAR);
				GetByte();
			}
			// handle prefix for local labels ('.')
			if(GotByte == '.') {
				DynaBuf_append(GlobalDynaBuf, '.');
				GetByte();
			}
			// handle label name
			Input_append_keyword_to_global_dynabuf();
		} while(pipe_comma());
		// ensure CHAR_SOB ('{')
		if(GotByte != CHAR_SOB)
			Throw_serious_error(exception_no_left_brace);
	}
	DynaBuf_append(GlobalDynaBuf, CHAR_EOS);	// terminate param list
	// now GlobalDynaBuf = comma-separated parameter list without spaces,
	// but terminated with CHAR_EOS.
	formal_parameters = DynaBuf_get_copy(GlobalDynaBuf);
	// now GlobalDynaBuf = unused
	// Reading the macro body would change the line number. To have correct
	// error messages, we're checking for "macro twice" *now*.
	// Search for macro. Create if not found.
	// But if found, complain (macro twice).
	if(search_for_macro(&macro_node, macro_zone, TRUE) == FALSE)
		report_redefinition(macro_node);// quits with serious error
	// Create new macro struct and set it up. Finally we'll read the body.
	new_macro = safe_malloc(sizeof(struct macro_t));
	new_macro->def_line_number = Input_now->line_number;
	new_macro->def_filename = get_string_copy(Input_now->original_filename);
	new_macro->original_name = get_string_copy(user_macro_name->buffer);
	new_macro->parameter_list = formal_parameters;
	new_macro->body = Input_skip_or_store_block(TRUE);// changes LineNumber
	macro_node->body = new_macro;	// link macro struct to tree node
	// and that about sums it up
}

// Parse macro call ("+MACROTITLE"). Has to be re-entrant.
void Macro_parse_call(void) {	// Now GotByte = dot or first char of macro name
	char		local_gotbyte;
	label_t*	label;
	section_t	new_section,
			*outer_section;
	input_t		new_input,
			*outer_input;
	struct macro_t*	actual_macro;
	node_ra_t	*macro_node,
			*label_node;
	zone_t		macro_zone,
			label_zone;
	int		arg_count	= 0;

	// Enter deeper nesting level
	// Quit program if recursion too deep.
	if(--macro_recursions_left < 0)
		Throw_serious_error("Too deeply nested. Recursive macro calls?");
	macro_zone = get_zone_and_title();
	// now GotByte = first non-space after title
	// internal_name = MacroTitle ARG_SEPARATOR (grows to signature)
	// Accept n>=0 comma-separated arguments before CHAR_EOS.
	// Valid argument formats are:
	// EXPRESSION (everything that does NOT start with '~'
	// ~.LOCAL_LABEL_BY_REFERENCE
	// ~GLOBAL_LABEL_BY_REFERENCE
	// now GotByte = non-space
	if(GotByte != CHAR_EOS) {	// any at all?
		do {
			// if arg table cannot take another element, enlarge
			if(argtable_size <= arg_count)
				enlarge_arg_table();
			// Decide whether call-by-reference or call-by-value
			// In both cases, GlobalDynaBuf may be used.
			if(GotByte == REFERENCE_CHAR) {
				// read call-by-reference arg
				DynaBuf_append(internal_name, ARGTYPE_NUM_REF);
				GetByte();	// skip '~' character
				Input_read_zone_and_keyword(&label_zone);
				// GotByte = illegal char
				arg_table[arg_count].label =
					Label_find(label_zone, 0);
			} else {
				// read call-by-value arg
				DynaBuf_append(internal_name, ARGTYPE_NUM_VAL);
				ALU_any_result(&(arg_table[arg_count].result));
			}
			arg_count++;
		} while(Input_accept_comma());
	}
	// now arg_table contains the arguments
	// now GlobalDynaBuf = unused
	// check for "unknown macro"
	// Search for macro. Do not create if not found.
	search_for_macro(&macro_node, macro_zone, FALSE);
	if(macro_node == NULL) {
		Throw_error("Macro not defined (or wrong signature).");
		Input_skip_remainder();
	} else {
		// make macro_node point to the macro struct
		actual_macro = macro_node->body;
		local_gotbyte = GotByte;// CAUTION - ugly kluge
		// set up new input
		new_input.original_filename = actual_macro->def_filename;
		new_input.line_number = actual_macro->def_line_number;
		new_input.source_is_ram = TRUE;
		new_input.state = INPUTSTATE_NORMAL;	// FIXME - fix others!
		new_input.src.ram_ptr = actual_macro->parameter_list;
		// remember old input
		outer_input = Input_now;
		// activate new input
		Input_now = &new_input;
		// remember old section
		outer_section = Section_now;
		// start new section (with new zone)
		// FALSE = title mustn't be freed
		Section_new_zone(&new_section, "Macro",
			actual_macro->original_name, FALSE);
		GetByte();	// fetch first byte of parameter list
		// assign arguments
		if(GotByte != CHAR_EOS) {	// any at all?
			arg_count = 0;
			do {
				// Decide whether call-by-reference
				// or call-by-value
				// In both cases, GlobalDynaBuf may be used.
				if(GotByte == REFERENCE_CHAR) {
					// assign call-by-reference arg
					GetByte();	// skip '~' character
					Input_read_zone_and_keyword(&label_zone);
					if((Tree_hard_scan(&label_node, Label_forest, label_zone, TRUE) == FALSE)
					&& (pass_count == 0))
						Throw_error("Macro parameter twice.");
					label_node->body = arg_table[arg_count].label;
				} else {
					// assign call-by-value arg
					Input_read_zone_and_keyword(&label_zone);
					label = Label_find(label_zone, 0);
// FIXME - add a possibility to Label_find to make it possible to find out
// whether label was just created. Then check for the same error message here
// as above ("Macro parameter twice.").
					label->result = arg_table[arg_count].result;
				}
				arg_count++;
			} while(Input_accept_comma());
		}
		// and now, finally, parse the actual macro body
		Input_now->state = INPUTSTATE_NORMAL;	// FIXME - fix others!
// maybe call parse_ram_block(actual_macro->def_line_number, actual_macro->body)
		Input_now->src.ram_ptr = actual_macro->body;
		Parse_until_eob_or_eof();
		if(GotByte != CHAR_EOB)
			Bug_found("IllegalBlockTerminator", GotByte);
		// end section (free title memory, if needed)
		Section_finalize(&new_section);
		// restore previous section
		Section_now = outer_section;
		// restore previous input:
		Input_now = outer_input;
		// restore old Gotbyte context
		GotByte = local_gotbyte;// CAUTION - ugly kluge
		Input_ensure_EOS();
	}
	macro_recursions_left++;	// leave this nesting level
}
