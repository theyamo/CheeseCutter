//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// CPU stuff
#ifndef cpu_H
#define cpu_H

#include "config.h"


// CPU type structure definition
struct cpu_t {
	// This function is not allowed to change GlobalDynaBuf
	// because that's where the mnemonic is stored!
	bool	(*keyword_is_mnemonic)(int);
	bool*	long_regs;	// pointer to array of bool:
#define LONGREG_IDX_A	0	// array index for "long accu" bool
#define LONGREG_IDX_R	1	// array index for "long index regs" bool
	int	flags;
	char	default_align_value;
};
#define	CPUFLAG_INDJMPBUGGY	(1u << 0)


// Variables
extern struct cpu_t	*CPU_now;// Struct of current CPU type (default 6502)
extern result_int_t	CPU_pc;	// Current program counter (pseudo value)
extern int		CPU_2add;	// add to PC after statement


// Prototypes

// create cpu type tree (is done early)
extern void	CPUtype_init(void);
// register pseudo opcodes (done later)
extern void	CPU_init(void);
// Set default values for pass
extern void	CPU_passinit(struct cpu_t* cpu_type);
// set program counter to defined value
extern void	CPU_set_pc(intval_t new_pc);
// Try to find CPU type held in DynaBuf. Returns whether succeeded.
extern bool	CPU_find_cpu_struct(struct cpu_t** target);
// return whether offset assembly is active
extern bool	CPU_uses_pseudo_pc(void);

#endif
