//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
//
// Modified by abaddon 2013
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#define RELEASE		"0.93"		// update before release (FIXME)
#define CODENAME	"Zarquon"	// update before release
#define CHANGE_DATE	"11 Oct"	// update before release
#define CHANGE_YEAR	"2006"		// update before release
#define HOME_PAGE	"http://home.pages.de/~mac_bacon/smorbrod/acme/"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#include "acme.h"
#include "alu.h"
#include "basics.h"
#include "config.h"
#include "cpu.h"
#include "dynabuf.h"
#include "encoding.h"
#include "flow.h"
#include "global.h"
#include "input.h"
#include "label.h"
#include "macro.h"
#include "mnemo.h"
#include "output.h"
#include "platform.h"
#include "section.h"


// Constants
static const char	FILE_WRITETEXT[]	= "w";
static const char	FILE_WRITEBINARY[]	= "wb";
// names for error messages
static const char	name_outfile[]		= "output filename";
static const char	name_dumpfile[]		= "label dump filename";
// long options
#define OPTION_HELP		"help"
#define OPTION_FORMAT		"format"
#define OPTION_OUTFILE		"outfile"
#define OPTION_LABELDUMP	"labeldump"
#define OPTION_SETPC		"setpc"
#define OPTION_CPU		"cpu"
#define OPTION_INITMEM		"initmem"
#define OPTION_MAXERRORS	"maxerrors"
#define OPTION_MAXDEPTH		"maxdepth"
#define OPTION_USE_STDOUT	"use-stdout"
#define OPTION_VERSION		"version"


// Variables
static signed long	start_addr		= -1;	// <0 is illegal
static signed long	fill_value		= MEMINIT_USE_DEFAULT;
static struct cpu_t	*default_cpu		= NULL;
const char*	labeldump_filename	= NULL;
const char*	output_filename		= NULL;
const char* source = NULL;
// maximum recursion depth for macro calls and "!source"
signed long	macro_recursions_left	= MAX_NESTING;
signed long	source_recursions_left	= MAX_NESTING;


// Perform a single pass. Returns number of "NeedValue" type errors.
static int perform_pass(void) {
	// call modules' "pass init" functions
	CPU_passinit(default_cpu);// set default cpu values (PC undefined)
	Output_passinit(start_addr);// call after CPU_passinit(), to define PC
	Encoding_passinit();	// set default encoding
	Section_passinit();	// set initial zone (untitled)
	// init variables
	pass_undefined_count = 0;	// no "NeedValue" errors yet
	pass_real_errors = 0;	// no real errors yet
	Parse_source(source);
	if(pass_real_errors) {
		longjmp(exception_env, 0);
	} else
		Output_end_segment();
	return(pass_undefined_count);
}

// do passes until done (or errors occured). Return whether output is ready.
static bool do_actual_work(void) {
	int	undefined_prev,	// "NeedValue" errors of previous pass
		undefined_curr;	// "NeedValue" errors of current pass

	if(Process_verbosity > 1)
		puts("First pass.");
	pass_count = 0;
	undefined_curr = perform_pass();	// First pass
	// now pretend there has been a pass before the first one
	undefined_prev = undefined_curr + 1;
	// As long as the number of "NeedValue" errors is decreasing but
	// non-zero, keep doing passes.
	while(undefined_curr && (undefined_curr < undefined_prev)) {
		pass_count++;
		undefined_prev = undefined_curr;
		if(Process_verbosity > 1)
			puts("Further pass.");
		undefined_curr = perform_pass();
	}
	// If still errors (unsolvable by doing further passes),
	// perform additional pass to find and show them
	if(undefined_curr == 0)
		return(TRUE);
	if(Process_verbosity > 1)
		puts("Further pass needed to find error.");
	ALU_throw_errors();	// activate error output (CAUTION - one-way!)
	pass_count++;
	perform_pass();	// perform pass, but now show "value undefined"
	return(FALSE);
}

char* acme_assemble(const char* src, const int *length, char *error) {
	error_message = error;
	source = src;
	msg_stream = stdout;
	DynaBuf_init();// inits *global* dynamic buffer - important, so first
	// Init platform-specific stuff.
	// For example, this could read the library path from an
	// environment variable, which in turn may need DynaBuf already.
	PLATFORM_INIT;
	// init some keyword trees needed for argument handling
	CPUtype_init();
	Outputfile_init();
	// Init modules (most of them will just build keyword trees)
	ALU_init();
	Basics_init();
	CPU_init();
	Encoding_init();
	Flow_init();
	Input_init();
	Label_init();
	Macro_init();
	Mnemo_init();
	Output_init(fill_value);
	Section_init();
	if(!setjmp(exception_env)) {
		if(do_actual_work()) {
			return Output_get_final_data(length);
		}
	}
	return NULL;
}
