//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// CPU stuff

#include "config.h"
#include "alu.h"
#include "cpu.h"
#include "dynabuf.h"
#include "global.h"
#include "input.h"
#include "mnemo.h"
#include "output.h"
#include "tree.h"


// Constants
static struct cpu_t	CPU_6502 = {
	keyword_is_6502mnemo,
	NULL,			// no long registers
	CPUFLAG_INDJMPBUGGY,	// JMP ($xxFF) is buggy
	234			// !align fills with "NOP"
};
static struct cpu_t	CPU_6510 = {
	keyword_is_6510mnemo,
	NULL,			// no long registers
	CPUFLAG_INDJMPBUGGY,	// JMP ($xxFF) is buggy
	234			// !align fills with "NOP"
};
static struct cpu_t	CPU_65c02= {
	keyword_is_65c02mnemo,
	NULL,			// no long registers
	0,			// no flags
	234			// !align fills with "NOP"
};
/*
static struct cpu_t	CPU_Rockwell65c02 = {
	keyword_is_Rockwell65c02mnemo,
	NULL,			// no long registers
	0,			// no flags
	234			// !align fills with "NOP"
};
static struct cpu_t	CPU_WDC65c02	= {
	keyword_is_WDC65c02mnemo,
	NULL,			// no long registers
	0,			// no flags
	234			// !align fills with "NOP"
};
*/
static bool	long_of_65816[2];	// 65816 struct needs array of 2 bools
static struct cpu_t	CPU_65816 = {
	keyword_is_65816mnemo,
	long_of_65816,		// two booleans for long accu/long regs
	0,			// no flags
	234			// !align fills with "NOP"
};
#define s_rl	(s_brl+1)	// Yes, I know I'm sick


// Variables
struct cpu_t	*CPU_now;	// Struct of current CPU type (default 6502)
result_int_t	CPU_pc;	// (Pseudo) program counter at start of statement
int		CPU_2add;	// Increase PC by this after statement
static intval_t	current_offset;	// PseudoPC - MemIndex
static bool	uses_pseudo_pc;	// offset assembly active?
// predefined stuff
static node_t*	CPU_tree	= NULL;// tree to hold CPU types
static node_t	CPUs[]	= {
//	PREDEFNODE("z80",		&CPU_Z80),
	PREDEFNODE("6502",		&CPU_6502),
	PREDEFNODE("6510",		&CPU_6510),
	PREDEFNODE("65c02",		&CPU_65c02),
//	PREDEFNODE("Rockwell65c02",	&CPU_Rockwell65c02),
//	PREDEFNODE("WDC65c02",		&CPU_WDC65c02),
	PREDEFLAST(s_65816,		&CPU_65816),
	//    ^^^^ this marks the last element
};


// Insert byte until PC fits condition
static enum eos_t PO_align(void) {
	intval_t	and,
			equal,
			fill,
			test	= CPU_pc.intval;

	// make sure PC is defined.
	if((CPU_pc.flags & MVALUE_DEFINED) == 0) {
		Throw_error(exception_pc_undefined);
		CPU_pc.flags |= MVALUE_DEFINED;	// do not complain again
		return(SKIP_REMAINDER);
	}
	and = ALU_defined_int();
	if(!Input_accept_comma())
		Throw_error(exception_syntax);
	equal = ALU_defined_int();
	if(Input_accept_comma())
		fill = ALU_any_int();
	else
		fill = CPU_now->default_align_value;
	while((test++ & and) != equal)
		Output_8b(fill);
	return(ENSURE_EOS);
}

// Try to find CPU type held in DynaBuf. Returns whether succeeded.
bool CPU_find_cpu_struct(struct cpu_t** target) {
	void*	node_body;

	if(!Tree_easy_scan(CPU_tree, &node_body, GlobalDynaBuf))
		return(FALSE);
	*target = node_body;
	return(TRUE);
}

// Select CPU ("!cpu" pseudo opcode)
static enum eos_t PO_cpu(void) {
	struct cpu_t*	cpu_buffer	= CPU_now;	// remember current cpu

	if(Input_read_and_lower_keyword())
		if(!CPU_find_cpu_struct(&CPU_now))
			Throw_error("Unknown processor.");
	// If there's a block, parse that and then restore old value!
	if(Parse_optional_block())
		CPU_now = cpu_buffer;
	return(ENSURE_EOS);
}

static const char	Warning_old_offset_assembly[]	=
	"\"!pseudopc/!realpc\" is deprecated; use \"!pseudopc {}\" instead.";

// Start offset assembly
static enum eos_t PO_pseudopc(void) {
	bool		outer_state	= uses_pseudo_pc;
	intval_t	new_pc,
			outer_offset	= current_offset;
	int		outer_flags	= CPU_pc.flags;

	// set new
	new_pc = ALU_defined_int();
	current_offset = (current_offset + new_pc - CPU_pc.intval) & 0xffff;
	CPU_pc.intval = new_pc;
	CPU_pc.flags |= MVALUE_DEFINED;
	uses_pseudo_pc = TRUE;
	// If there's a block, parse that and then restore old value!
	if(Parse_optional_block()) {
		// restore old
		uses_pseudo_pc = outer_state;
		CPU_pc.flags = outer_flags;
		CPU_pc.intval = (outer_offset + CPU_pc.intval - current_offset) & 0xffff;
		current_offset = outer_offset;
	} else
		Throw_first_pass_warning(Warning_old_offset_assembly);
	return(ENSURE_EOS);
}

// End offset assembly
static enum eos_t PO_realpc(void) {
	Throw_first_pass_warning(Warning_old_offset_assembly);
	// deactivate offset assembly
	CPU_pc.intval = (CPU_pc.intval - current_offset) & 0xffff;
	current_offset = 0;
	uses_pseudo_pc = FALSE;
	return(ENSURE_EOS);
}

// return whether offset assembly is active
bool CPU_uses_pseudo_pc(void) {
	return(uses_pseudo_pc);
}

// If cpu type and value match, set register length variable to value.
// If cpu type and value don't match, complain instead.
static void check_and_set_reg_length(bool *var, bool long_reg) {
	if(long_reg && ((CPU_now->long_regs) == NULL))
		Throw_error("Chosen CPU does not support long registers.");
	else
		*var = long_reg;
}

// Set register length, block-wise if needed.
static enum eos_t set_register_length(bool *var, bool long_reg) {
	bool	buffer	= *var;

	// Set new register length (or complain - whichever is more fitting)
	check_and_set_reg_length(var, long_reg);
	// If there's a block, parse that and then restore old value!
	if(Parse_optional_block())
		check_and_set_reg_length(var, buffer);// restore old length
	return(ENSURE_EOS);
}

// Switch to long accu ("!al" pseudo opcode)
static enum eos_t PO_al(void) {
	return(set_register_length(CPU_now->long_regs + LONGREG_IDX_A, TRUE));
}

// Switch to short accu ("!as" pseudo opcode)
static enum eos_t PO_as(void) {
	return(set_register_length(CPU_now->long_regs + LONGREG_IDX_A, FALSE));
}

// Switch to long index registers ("!rl" pseudo opcode)
static enum eos_t PO_rl(void) {
	return(set_register_length(CPU_now->long_regs + LONGREG_IDX_R, TRUE));
}

// Switch to short index registers ("!rs" pseudo opcode)
static enum eos_t PO_rs(void) {
	return(set_register_length(CPU_now->long_regs + LONGREG_IDX_R, FALSE));
}

// pseudo opcode table
static node_t	pseudo_opcodes[]	= {
	PREDEFNODE("align",	PO_align),
	PREDEFNODE("cpu",	PO_cpu),
	PREDEFNODE("pseudopc",	PO_pseudopc),
	PREDEFNODE("realpc",	PO_realpc),
	PREDEFNODE("al",	PO_al),
	PREDEFNODE("as",	PO_as),
	PREDEFNODE(s_rl,	PO_rl),
	PREDEFLAST("rs",	PO_rs),
	//    ^^^^ this marks the last element
};

// Set default values for pass
void CPU_passinit(struct cpu_t* cpu_type) {
	// handle cpu type (default is 6502)
	CPU_now		= cpu_type ? cpu_type : &CPU_6502;
	CPU_pc.flags = 0;	// not defined yet
	CPU_pc.intval = 512;	// actually, there should be no need to init
	CPU_2add = 0;	// Increase PC by this at end of statement
	CPU_65816.long_regs[LONGREG_IDX_A] = FALSE;	// short accu
	CPU_65816.long_regs[LONGREG_IDX_R] = FALSE;	// short index regs
	uses_pseudo_pc	= FALSE;	// offset assembly is not active,
	current_offset	= 0;		// so offset is 0
}

// create cpu type tree (is done early)
void CPUtype_init(void) {
	Tree_add_table(&CPU_tree, CPUs);
}

// register pseudo opcodes (done later)
void CPU_init(void) {
	Tree_add_table(&pseudo_opcode_tree, pseudo_opcodes);
}

// set program counter to defined value
void CPU_set_pc(intval_t new_pc) {
	CPU_pc.flags |= MVALUE_DEFINED;
	CPU_pc.intval = new_pc;
}
