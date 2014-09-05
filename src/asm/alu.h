//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// ALU stuff (the expression parser)
#ifndef alu_H
#define alu_H

#include "config.h"


// Constants

// Meaning of bits in "flags" of result_t and result_int_t structures:
#define MVALUE_IS_FP	(1u << 8)
	// Floating point value (never set in result_int_t)
#define MVALUE_INDIRECT	(1u << 7)
	// Needless parentheses indicate use of indirect addressing modes
#define MVALUE_EXISTS	(1u << 6)
	// 0: expression was empty. 1: there was *something* to parse.
#define MVALUE_UNSURE	(1u << 5)
	// Value once was related to undefined expression. Needed for producing
	// the same addresses in all passes; because in the first pass there
	// will almost for sure be labels that are undefined, you can't simply
	// get the addressing mode from looking at the parameter's value.
#define MVALUE_DEFINED	(1u << 4)
	// 0: undefined expression (value will be zero). 1: known result
#define MVALUE_ISBYTE	(1u << 3)
	// Value is guaranteed to fit in one byte
#define MVALUE_FORCE24	(1u << 2)
	// Value usage forces 24-bit usage
#define MVALUE_FORCE16	(1u << 1)
	// Value usage forces 16-bit usage
#define MVALUE_FORCE08	(1u << 0)
	// Value usage forces 8-bit usage
#define MVALUE_FORCEBITS	(MVALUE_FORCE08|MVALUE_FORCE16|MVALUE_FORCE24)
#define MVALUE_GIVEN	(MVALUE_DEFINED | MVALUE_EXISTS)
	// Bit mask for fixed values (defined and existing)


// Prototypes

// create dynamic buffer, operator/function trees and operator/operand stacks
extern void	ALU_init(void);
// Activate error output for "value undefined"
extern void	ALU_throw_errors(void);
// returns int value (0 if result was undefined)
extern intval_t	ALU_any_int(void);
// returns int value (if result was undefined, serious error is thrown)
extern intval_t	ALU_defined_int(void);
// stores int value if given. Returns whether stored. Throws error if undefined.
extern bool	ALU_optional_defined_int(intval_t*);
// stores int value and flags (floats are transformed to int)
extern void	ALU_int_result(result_int_t*);
// stores int value and flags, allowing for one '(' too many (x-indirect addr)
extern int	ALU_liberal_int(result_int_t*);
// stores value and flags (result may be either int or float)
extern void	ALU_any_result(result_t*);


#endif
