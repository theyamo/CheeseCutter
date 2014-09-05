//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Arithmetic/logic unit
// 11 Oct 006	Improved float reading in parse_decimal_value()

#include <stdlib.h>
#include <math.h>	// only for experimental fp support
#include "platform.h"	// done first in case "inline" is redefined
#include "alu.h"
#include "cpu.h"
#include "dynabuf.h"
#include "encoding.h"
#include "global.h"
#include "input.h"
#include "label.h"
#include "section.h"
#include "tree.h"


// Constants

#define FUNCION_DYNABUF_INITIALSIZE	8	// enough for "arctan"
#define HALF_INITIAL_STACK_SIZE	8
static const char	exception_div_by_zero[]	= "Division by zero.";
static const char	exception_no_value[]	= "No value given.";
static const char	exception_paren_open[]	= "Too many '('.";
static const char	exception_undefined[]	= "Value not defined.";
#define s_or	(s_eor+1)	// Yes, I know I'm sick
#define s_xor	(s_scrxor+3)	// Yes, I know I'm sick
static const char	s_arcsin[]	= "arcsin";
#define s_sin	(s_arcsin+3)	// Yes, I know I'm sick
static const char	s_arccos[]	= "arccos";
#define s_cos	(s_arccos+3)	// Yes, I know I'm sick
static const char	s_arctan[]	= "arctan";
#define s_tan	(s_arctan+3)	// Yes, I know I'm sick

// Operator handles (FIXME - use function pointers instead? or too slow?)
enum op_handle_t {
//	special values (pseudo operators)
	OPHANDLE_END,		//		"reached end of expression"
	OPHANDLE_RETURN,	//		"return value to caller"
//	functions
	OPHANDLE_INT,		//	int(v)
	OPHANDLE_FLOAT,		//	float(v)
	OPHANDLE_SIN,		//	sin(v)
	OPHANDLE_COS,		//	cos(v)
	OPHANDLE_TAN,		//	tan(v)
	OPHANDLE_ARCSIN,	//	arcsin(v)
	OPHANDLE_ARCCOS,	//	arccos(v)
	OPHANDLE_ARCTAN,	//	arctan(v)
//	monadic operators
	OPHANDLE_OPENING,	//	(v	'(', starts subexpression
	OPHANDLE_NOT,		//	!v	NOT v	bit-wise NOT
	OPHANDLE_NEGATE,	//	-v		Negate
	OPHANDLE_LOWBYTEOF,	//	<v		Lowbyte of
	OPHANDLE_HIGHBYTEOF,	//	>v		Highbyte of
	OPHANDLE_BANKBYTEOF,	//	^v		Bankbyte of
//	dyadic operators
	OPHANDLE_CLOSING,	//	v)	')', ends subexpression
	OPHANDLE_POWEROF,	//	v^w
	OPHANDLE_MULTIPLY,	//	v*w
	OPHANDLE_DIVIDE,	//	v/w		(Integer) Division
	OPHANDLE_INTDIV,	//	v/w	v DIV w	Integer Division
	OPHANDLE_MODULO,	//	v%w	v MOD w	Remainder
	OPHANDLE_SL,		//	v<<w	v ASL w	v LSL w	Shift left
	OPHANDLE_ASR,		//	v>>w	v ASR w	Arithmetic shift right
	OPHANDLE_LSR,		//	v>>>w	v LSR w	Logical shift right
	OPHANDLE_ADD,		//	v+w
	OPHANDLE_SUBTRACT,	//	v-w
	OPHANDLE_EQUALS,	//	v=w
	OPHANDLE_LE,		//	v<=w
	OPHANDLE_LESSTHAN,	//	v< w
	OPHANDLE_GE,		//	v>=w
	OPHANDLE_GREATERTHAN,	//	v> w
	OPHANDLE_NOTEQUAL,	//	v!=w	v<>w	v><w
	OPHANDLE_AND,		//	v&w		v AND w
	OPHANDLE_OR,		//	v|w		v OR w
	OPHANDLE_EOR,		//	v EOR w		v XOR w		(remove)
	OPHANDLE_XOR,		//	v XOR w
};
struct operator_t {
	enum op_handle_t	handle;
	int			priority;
};
typedef struct operator_t op_t;

// operator structs (only hold handle and priority value)
static op_t ops_end		= {OPHANDLE_END,	 0};	// special
static op_t ops_return		= {OPHANDLE_RETURN,	 1};	// special
static op_t ops_closing		= {OPHANDLE_CLOSING,	 2};	// dyadic
static op_t ops_opening		= {OPHANDLE_OPENING,	 3};	// monadic
static op_t ops_or		= {OPHANDLE_OR,		 4};	// dyadic
static op_t ops_eor		= {OPHANDLE_EOR,	 5};	//	(remove)
static op_t ops_xor		= {OPHANDLE_XOR,	 5};	// dyadic
static op_t ops_and		= {OPHANDLE_AND,	 6};	// dyadic
static op_t ops_equals		= {OPHANDLE_EQUALS,	 7};	// dyadic
static op_t ops_notequal	= {OPHANDLE_NOTEQUAL,	 8};	// dyadic
	// same priority for all comparison operators
static op_t ops_le		= {OPHANDLE_LE,		 9};	// dyadic
static op_t ops_lessthan	= {OPHANDLE_LESSTHAN,	 9};	// dyadic
static op_t ops_ge		= {OPHANDLE_GE,		 9};	// dyadic
static op_t ops_greaterthan	= {OPHANDLE_GREATERTHAN, 9};	// dyadic
	// same priority for all byte extraction operators
static op_t ops_lowbyteof	= {OPHANDLE_LOWBYTEOF,	10};	// monadic
static op_t ops_highbyteof	= {OPHANDLE_HIGHBYTEOF,	10};	// monadic
static op_t ops_bankbyteof	= {OPHANDLE_BANKBYTEOF,	10};	// monadic
	// same priority for all shift operators
static op_t ops_sl		= {OPHANDLE_SL,		11};	// dyadic
static op_t ops_asr		= {OPHANDLE_ASR,	11};	// dyadic
static op_t ops_lsr		= {OPHANDLE_LSR,	11};	// dyadic
	// same priority for "+" and "-"
static op_t ops_add		= {OPHANDLE_ADD,	12};	// dyadic
static op_t ops_subtract	= {OPHANDLE_SUBTRACT,	12};	// dyadic
	// same priority for "*", "/" and "%"
static op_t ops_multiply	= {OPHANDLE_MULTIPLY,	13};	// dyadic
static op_t ops_divide		= {OPHANDLE_DIVIDE,	13};	// dyadic
static op_t ops_intdiv		= {OPHANDLE_INTDIV,	13};	// dyadic
static op_t ops_modulo		= {OPHANDLE_MODULO,	13};	// dyadic
	// highest "real" priorities
static op_t ops_negate		= {OPHANDLE_NEGATE,	14};	// monadic
static op_t ops_powerof		= {OPHANDLE_POWEROF,	15};	// dyadic
static op_t ops_not		= {OPHANDLE_NOT,	16};	// monadic
	// function calls act as if they were monadic operators
static op_t ops_int		= {OPHANDLE_INT,	17};	// function
static op_t ops_float		= {OPHANDLE_FLOAT,	17};	// function
static op_t ops_sin		= {OPHANDLE_SIN,	17};	// function
static op_t ops_cos		= {OPHANDLE_COS,	17};	// function
static op_t ops_tan		= {OPHANDLE_TAN,	17};	// function
static op_t ops_arcsin		= {OPHANDLE_ARCSIN,	17};	// function
static op_t ops_arccos		= {OPHANDLE_ARCCOS,	17};	// function
static op_t ops_arctan		= {OPHANDLE_ARCTAN,	17};	// function


// Variables

static dynabuf_t*	function_dyna_buf;	// dynamic buffer for fn names
static op_t**		operator_stack		= NULL;
static int		operator_stk_size	= HALF_INITIAL_STACK_SIZE;
static int		operator_sp;		// operator stack pointer
static struct result_t*	operand_stack	= NULL;	// flags and value
static int		operand_stk_size	= HALF_INITIAL_STACK_SIZE;
static int		operand_sp;		// value stack pointer
static int		indirect_flag;	// Flag for indirect addressing
					// (indicated by useless parentheses)
					// Contains either 0 or MVALUE_INDIRECT
enum alu_state_t {
	STATE_EXPECT_OPERAND_OR_MONADIC_OPERATOR,
	STATE_EXPECT_DYADIC_OPERATOR,
	STATE_TRY_TO_REDUCE_STACKS,
	STATE_MAX_GO_ON,	// "border value" to find the stoppers:
	STATE_ERROR,		// error has occured
	STATE_END,		// standard end
};
static enum alu_state_t	alu_state;	// deterministic finite automaton
// predefined stuff
static node_t*	operator_tree	= NULL;// tree to hold operators
static node_t	operator_list[]	= {
	PREDEFNODE(s_asr,	&ops_asr),
	PREDEFNODE(s_lsr,	&ops_lsr),
	PREDEFNODE(s_asl,	&ops_sl),
	PREDEFNODE("lsl",	&ops_sl),
	PREDEFNODE("div",	&ops_intdiv),
	PREDEFNODE("mod",	&ops_modulo),
	PREDEFNODE(s_and,	&ops_and),
	PREDEFNODE(s_or,	&ops_or),
	PREDEFNODE(s_eor,	&ops_eor),		// remove sometime
	PREDEFLAST(s_xor,	&ops_xor),
	//    ^^^^ this marks the last element
};
static node_t*	function_tree	= NULL;// tree to hold functions
static node_t	function_list[]	= {
	PREDEFNODE("int",	&ops_int),
	PREDEFNODE("float",	&ops_float),
	PREDEFNODE(s_arcsin,	&ops_arcsin),
	PREDEFNODE(s_arccos,	&ops_arccos),
	PREDEFNODE(s_arctan,	&ops_arctan),
	PREDEFNODE(s_sin,	&ops_sin),
	PREDEFNODE(s_cos,	&ops_cos),
	PREDEFLAST(s_tan,	&ops_tan),
	//    ^^^^ this marks the last element
};

#define LEFT_FLAGS	(operand_stack[operand_sp-2].flags)
#define RIGHT_FLAGS	(operand_stack[operand_sp-1].flags)
#define LEFT_INTVAL	(operand_stack[operand_sp-2].val.intval)
#define RIGHT_INTVAL	(operand_stack[operand_sp-1].val.intval)
#define LEFT_FPVAL	(operand_stack[operand_sp-2].val.fpval)
#define RIGHT_FPVAL	(operand_stack[operand_sp-1].val.fpval)

#define PUSH_OPERATOR(x)	operator_stack[operator_sp++] = (x)

#define PUSH_INTOPERAND(i, f)	do {\
	operand_stack[operand_sp].flags = (f);\
	operand_stack[operand_sp++].val.intval = (i);\
} while(0)
#define PUSH_FPOPERAND(fp, f)	do {\
	operand_stack[operand_sp].flags = (f) | MVALUE_IS_FP;\
	operand_stack[operand_sp++].val.fpval = (fp);\
} while(0)


// Functions

// Handle "NeedValue" type errors: problems that may be solved by performing
// further passes. This function only counts, it will not show the errors to
// the user.
static void just_count(void) {
	pass_undefined_count++;
}

// Handle "NeedValue" type errors: problems that may be solved by performing
// further passes. This function counts these errors and shows them to the user.
static void count_and_throw(void) {
	pass_undefined_count++;
	Throw_error(exception_undefined);
}

// Function pointer for "result is undefined" type errors.
static void (*result_is_undefined)(void)	= just_count;

// Activate error output for "value undefined"
void ALU_throw_errors(void) {
	result_is_undefined = count_and_throw;
}

// Enlarge operator stack
static void enlarge_operator_stack(void) {
	operator_stk_size *= 2;
	operator_stack =
		realloc(operator_stack, operator_stk_size * sizeof(op_t*));
	if(operator_stack == NULL)
		Throw_serious_error(exception_no_memory_left);
}

// Enlarge operand stack
static void enlarge_operand_stack(void) {
	operand_stk_size *= 2;
	operand_stack =
		realloc(operand_stack, operand_stk_size * sizeof(struct result_t));
	if(operand_stack == NULL)
		Throw_serious_error(exception_no_memory_left);
}

// create dynamic buffer, operator/function trees and operator/operand stacks
void ALU_init(void) {
	function_dyna_buf = DynaBuf_create(FUNCION_DYNABUF_INITIALSIZE);
	Tree_add_table(&operator_tree, operator_list);
	Tree_add_table(&function_tree, function_list);
	enlarge_operator_stack();
	enlarge_operand_stack();
}

// not-so-braindead algorithm for calculating "to the power of" function for
// integer operands.
// my_pow(whatever, 0) returns 1. my_pow(0, whatever_but_zero) returns 0.
static inline intval_t my_pow(intval_t mantissa, intval_t exponent) {
	intval_t	result	= 1;

	while(exponent) {
		// handle exponent's lowmost bit
		if(exponent & 1)
			result *= mantissa;
		// square the mantissa, halve the exponent
		mantissa *= mantissa;
		exponent >>= 1;
	}
	return(result);
}

// arithmetic shift right (works even if C compiler does not support it)
static inline intval_t my_asr(intval_t left, intval_t right) {
	intval_t	result	= left >> right;	// perform shift right

	// if left operand >= 0, then ASR and LSR are equivalent, so ok
	// if result < 0, then ASR has been performed, so ok
	if((left >= 0) || (result < 0))
		return(result);
	// otherwise, correct result and return that
	return(result | (-1L << (8 * sizeof(intval_t) - right)));
}

// Lookup (and create, if necessary) label tree item and return its value.
// DynaBuf holds the label's name and "zone" its zone.
// This function is not allowed to change DynaBuf because that's where the
// label name is stored!
static void get_label_value(zone_t zone) {
	label_t*	label;

	// If the label gets created now, mark it as unsure
	label = Label_find(zone, MVALUE_UNSURE);
	// in first pass, count usage
	if(pass_count == 0)
		label->usage++;
	// push operand, regardless of whether int or float
	operand_stack[operand_sp] = label->result;
	operand_stack[operand_sp++].flags |= MVALUE_EXISTS;
}

// Parse quoted character.
// The character will be converted using the current encoding.
static inline void parse_quoted_character(char closing_quote) {
	intval_t	value;

	// read character to parse - make sure not at end of statement
	if(GetQuotedByte() == CHAR_EOS)
		return;
	// on empty string, complain
	if(GotByte == closing_quote) {
		Throw_error(exception_missing_string);
		Input_skip_remainder();
		return;
	}
	// parse character
	value = (intval_t) Encoding_encode_char(GotByte);
	// Read closing quote (hopefully)
	if(GetQuotedByte() == closing_quote)
		GetByte();// If length == 1, proceed with next byte
	else
		if(GotByte) {
			// If longer than one character
			Throw_error("There's more than one character.");
			Input_skip_remainder();
		}
	PUSH_INTOPERAND(value, MVALUE_GIVEN | MVALUE_ISBYTE);
	// Now GotByte = char following closing quote (or CHAR_EOS on error)
}

// Parse hexadecimal value. It accepts "0" to "9", "a" to "f" and "A" to "F".
// Capital letters will be converted to lowercase letters using the flagtable.
// The current value is stored as soon as a character is read that is none of
// those given above.
static void parse_hexadecimal_value(void) {// Now GotByte = "$" or "x"
	char		byte;
	bool		go_on;		// continue loop flag
	int		digits	= -1,	// digit counter
			flags	= MVALUE_GIVEN;
	intval_t	value	= 0;

	do {
		digits++;
		go_on = FALSE;
		byte = GetByte();
		//	first, convert "A-F" to "a-f"
		byte |= (BYTEFLAGS(byte) & BYTEIS_UPCASE);
		// if digit, add digit value
		if((byte >= '0') && (byte <= '9')) {
			value = (value << 4) + (byte - '0');
			go_on = TRUE;// keep going
		}
		// if legal ("a-f") character, add character value
		if((byte >= 'a') && (byte <= 'f')) {
			value = (value << 4) + (byte - 'a') + 10;
			go_on = TRUE;// keep going
		}
	} while(go_on);
	// set force bits
	if(digits > 2) {
		if(digits > 4) {
			if(value < 65536)
				flags |= MVALUE_FORCE24;
		} else {
			if(value < 256)
				flags |= MVALUE_FORCE16;
		}
	}
	PUSH_INTOPERAND(value, flags);
	// Now GotByte = non-hexadecimal char
}

// Parse a decimal value. As decimal values don't use any prefixes, this
// function expects the first digit to be read already. If the first two digits
// are "0x", this function branches to the one for parsing hexadecimal values.
// This function accepts '0' through '9' and one dot ('.') as the decimal
// point. The current value is stored as soon as a character is read that is
// none of those given above. Float usage is only activated when a decimal
// point has been found, so don't expect "100000000000000000000" to work.
static inline void parse_decimal_value(void) {// Now GotByte = first digit
	double		fpval,
			denominator;
	intval_t	intval	= (GotByte & 15);// this works. it's ASCII.

	GetByte();
	if((intval == 0) && (GotByte == 'x'))
		return(parse_hexadecimal_value());
	// parse digits until no more
	while((GotByte >= '0') && (GotByte <= '9')) {
		intval *= 10;
		intval += (GotByte & 15);// this works. it's ASCII.
		GetByte();
	}
	// check whether it's a float
	if(GotByte == '.') {
		// read fractional part and store as fp value
		GetByte();
		fpval = intval;
		denominator = 1;
		// parse digits until no more
		while((GotByte >= '0') && (GotByte <= '9')) {
			fpval *= 10;
			fpval += (GotByte & 15);// this works. it' ASCII.
			denominator *= 10;
			GetByte();
		}
		fpval /= denominator;
		PUSH_FPOPERAND(fpval, MVALUE_GIVEN);
	} else {
		// integer
		PUSH_INTOPERAND(intval, MVALUE_GIVEN);
	}
	// Now GotByte = non-decimal char
}

// Parse octal value. It accepts "0" to "7". The current value is stored as
// soon as a character is read that is none of those given above.
static inline void parse_octal_value(void) {// Now GotByte = "&"
	intval_t	value	= 0;
	int		flags	= MVALUE_GIVEN,
			digits	= 0;	// digit counter

	GetByte();
	while((GotByte >= '0') && (GotByte <= '7')) {
		value = (value << 3) + (GotByte & 7);// this works. it's ASCII.
		digits++;
		GetByte();
	}
	// set force bits
	if(digits > 3) {
		if(digits > 6) {
			if(value < 65536)
				flags |= MVALUE_FORCE24;
		} else {
			if(value < 256)
				flags |= MVALUE_FORCE16;
		}
	}
	PUSH_INTOPERAND(value, flags);
	// Now GotByte = non-octal char
}

// Parse binary value. Apart from '0' and '1', it also accepts the characters
// '.' and '#', this is much more readable. The current value is stored as soon
// as a character is read that is none of those given above.
static inline void parse_binary_value(void) {// Now GotByte = "%"
	intval_t	value	= 0;
	bool		go_on	= TRUE;	// continue loop flag
	int		flags	= MVALUE_GIVEN,
			digits	= -1;	// digit counter

	do {
		digits++;
		switch(GetByte()) {

			case '0':
			case '.':
			value <<= 1;
			break;

			case '1':
			case '#':
			value = (value << 1) | 1;
			break;

			default:
			go_on = FALSE;
		}
	} while(go_on);
	// set force bits
	if(digits > 8) {
		if(digits > 16) {
			if(value < 65536)
				flags |= MVALUE_FORCE24;
		} else {
			if(value < 256)
				flags |= MVALUE_FORCE16;
		}
	}
	PUSH_INTOPERAND(value, flags);
	// Now GotByte = non-binary char
}

// Parse function call (sin(), cos(), arctan(), ...)
static inline void parse_function_call(void) {
	void*	node_body;

	// make lower case version of name in local dynamic buffer
	DynaBuf_to_lower(function_dyna_buf, GlobalDynaBuf);
	// search for tree item
	if(Tree_easy_scan(function_tree, &node_body, function_dyna_buf))
		PUSH_OPERATOR((op_t*) node_body);
	else
		Throw_error("Unknown function.");
}

// Expect operand or monadic operator (hopefully inlined)
static inline void expect_operand_or_monadic_operator(void) {
	op_t*	operator;
	bool	perform_negation;

	SKIPSPACE();
	switch(GotByte) {

		case '+':// anonymous forward label
		// count plus signs to build name of anonymous label
		DYNABUF_CLEAR(GlobalDynaBuf);
		do
			DYNABUF_APPEND(GlobalDynaBuf, '+');
		while(GetByte() == '+');
		Label_fix_forward_name();
		get_label_value(Section_now->zone);
		goto now_expect_dyadic;

		case '-':// NEGATION operator or anonymous backward label
		// count minus signs in case it's an anonymous backward label
		perform_negation = FALSE;
		DYNABUF_CLEAR(GlobalDynaBuf);
		do {
			DYNABUF_APPEND(GlobalDynaBuf, '-');
			perform_negation = !perform_negation;
		} while(GetByte() == '-');
		SKIPSPACE();
		if(BYTEFLAGS(GotByte) & FOLLOWS_ANON) {
			DynaBuf_append(GlobalDynaBuf, '\0');
			get_label_value(Section_now->zone);
			goto now_expect_dyadic;
		} // goto means we don't need an "else {" here
		if(perform_negation)
			PUSH_OPERATOR(&ops_negate);
		// State doesn't change
		break;

// Real monadic operators (state doesn't change, still ExpectMonadic)

		case '!':// NOT operator
		operator = &ops_not;
		goto get_byte_and_push_monadic;

		case '<':// LOWBYTE operator
		operator = &ops_lowbyteof;
		goto get_byte_and_push_monadic;

		case '>':// HIGHBYTE operator
		operator = &ops_highbyteof;
		goto get_byte_and_push_monadic;

		case '^':// BANKBYTE operator
		operator = &ops_bankbyteof;
		goto get_byte_and_push_monadic;

// Faked monadic operators

		case '(':// left parenthesis
		operator = &ops_opening;
		goto get_byte_and_push_monadic;

		case ')':// right parenthesis
		// this makes "()" also throw a syntax error
		Throw_error(exception_syntax);
		alu_state = STATE_ERROR;
		break;

// Operands (values, state changes to ExpectDyadic)

		// Quoted character
		case '"':
		case '\'':
		// Character will be converted using current encoding
		parse_quoted_character(GotByte);
		// Now GotByte = char following closing quote
		goto now_expect_dyadic;

		// Binary value
		case '%':
		parse_binary_value();// Now GotByte = non-binary char
		goto now_expect_dyadic;

		// Octal value
		case '&':
		parse_octal_value();// Now GotByte = non-octal char
		goto now_expect_dyadic;

		// Hexadecimal value
		case '$':
		parse_hexadecimal_value();
		// Now GotByte = non-hexadecimal char
		goto now_expect_dyadic;

		// Program counter
		case '*':
		GetByte();// proceed with next char
		PUSH_INTOPERAND(CPU_pc.intval, CPU_pc.flags | MVALUE_EXISTS);
		// Now GotByte = char after closing quote
		goto now_expect_dyadic;

		// Local label
		case '.':
		GetByte();// start after '.'
		if(Input_read_keyword()) {
			// Now GotByte = illegal char
			get_label_value(Section_now->zone);
			goto now_expect_dyadic;
		} // goto means we don't need an "else {" here
		alu_state = STATE_ERROR;
		break;

		// Decimal values and global labels
		default:// (all other characters)
		if((GotByte >= '0') && (GotByte <= '9')) {
			parse_decimal_value();
			// Now GotByte = non-decimal char
			goto now_expect_dyadic;
		} // goto means we don't need an "else {" here
		if(BYTEFLAGS(GotByte) & STARTS_KEYWORD) {
			register int	length;
			// Read global label (or "NOT")
			length = Input_read_keyword();
			// Now GotByte = illegal char
			// Check for NOT. Okay, it's hardcoded,
			// but so what? Sue me...
			if((length == 3)
			&& ((GlobalDynaBuf->buffer[0] | 32) == 'n')
			&& ((GlobalDynaBuf->buffer[1] | 32) == 'o')
			&& ((GlobalDynaBuf->buffer[2] | 32) == 't')) {
				PUSH_OPERATOR(&ops_not);
				// state doesn't change
			} else {
				if(GotByte == '(')
					parse_function_call();
				else {
					get_label_value(ZONE_GLOBAL);
					goto now_expect_dyadic;
				}
			}
		} else {
			// illegal character read - so don't go on
			PUSH_INTOPERAND(0, 0);
			// push pseudo value, EXISTS flag is clear
			if(operator_stack[operator_sp-1] == &ops_return) {
				PUSH_OPERATOR(&ops_end);
				alu_state = STATE_TRY_TO_REDUCE_STACKS;
			} else {
				Throw_error(exception_syntax);
				alu_state = STATE_ERROR;
			}
		}
		break;

// no other possibilities, so here are the shared endings

get_byte_and_push_monadic:
		GetByte();
		PUSH_OPERATOR(operator);
		// State doesn't change
		break;

now_expect_dyadic:
		alu_state = STATE_EXPECT_DYADIC_OPERATOR;
		break;

	}
}

// Expect dyadic operator (hopefully inlined)
static inline void expect_dyadic_operator(void) {
	void*	node_body;
	op_t*	operator;

	SKIPSPACE();
	switch(GotByte) {

// Single-character dyadic operators

		case '^':// "to the power of"
		operator = &ops_powerof;
		goto get_byte_and_push_dyadic;

		case '+':// add
		operator = &ops_add;
		goto get_byte_and_push_dyadic;

		case '-':// subtract
		operator = &ops_subtract;
		goto get_byte_and_push_dyadic;

		case '*':// multiply
		operator = &ops_multiply;
		goto get_byte_and_push_dyadic;

		case '/':// divide
		operator = &ops_divide;
		goto get_byte_and_push_dyadic;

		case '%':// modulo
		operator = &ops_modulo;
		goto get_byte_and_push_dyadic;

		case '&':// bitwise AND
		operator = &ops_and;
		goto get_byte_and_push_dyadic;

		case '|':// bitwise OR
		operator = &ops_or;
		goto get_byte_and_push_dyadic;

// This part is commented out because there is no XOR character defined
//		case ???:// bitwise exclusive OR
//		operator = &ops_xor;
//		goto get_byte_and_push_dyadic;

		case '=':// is equal
		operator = &ops_equals;
		goto get_byte_and_push_dyadic;

		case ')':// closing parenthesis
		operator = &ops_closing;
		goto get_byte_and_push_dyadic;

// Multi-character dyadic operators

		// "!="
		case '!':
		if(GetByte() == '=') {
			operator = &ops_notequal;
			goto get_byte_and_push_dyadic;
		} // goto means we don't need an "else {" here
		Throw_error(exception_syntax);
		alu_state = STATE_ERROR;
		break;

		// "<", "<=", "<<" and "<>"
		case '<':
		switch(GetByte()) {

			case '=':// "<=", less or equal
			operator = &ops_le;
			goto get_byte_and_push_dyadic;

			case '<':// "<<", shift left
			operator = &ops_sl;
			goto get_byte_and_push_dyadic;

			case '>':// "<>", not equal
			operator = &ops_notequal;
			goto get_byte_and_push_dyadic;

			default:// "<", less than
			operator = &ops_lessthan;
			goto push_dyadic;
		}
		break;

		// ">", ">=", ">>", ">>>" and "><"
		case '>':
		switch(GetByte()) {

			case '=':// ">=", greater or equal
			operator = &ops_ge;
			goto get_byte_and_push_dyadic;

			case '<':// "><", not equal
			operator = &ops_notequal;
			goto get_byte_and_push_dyadic;

			case '>':// ">>" or ">>>", shift right
			operator = &ops_asr;// arithmetic shift right
			if(GetByte() != '>')
				goto push_dyadic;
			operator = &ops_lsr;// logical shift right
			goto get_byte_and_push_dyadic;

			default:// ">", greater than
			operator = &ops_greaterthan;
			goto push_dyadic;
		}
		break;

// end of expression or text version of dyadic operator
		default:
		// check string version of operators
		if(BYTEFLAGS(GotByte) & STARTS_KEYWORD) {
			Input_read_and_lower_keyword();
			// Now GotByte = illegal char
			// search for tree item
			if(Tree_easy_scan(operator_tree, &node_body, GlobalDynaBuf)) {
				operator = node_body;
				goto push_dyadic;
			}
			// goto means we don't need an "else {" here
			Throw_error("Unknown operator.");
			alu_state = STATE_ERROR;
		} else {
			operator = &ops_end;
			goto push_dyadic;
		}
		break;

// no other possibilities, so here are the shared endings

get_byte_and_push_dyadic:
		GetByte();
push_dyadic:
		PUSH_OPERATOR(operator);
		alu_state = STATE_TRY_TO_REDUCE_STACKS;
		break;

	}
}

// call C's sin/cos/tan function
static void perform_fp(double (*fn)(double)) {
	if((RIGHT_FLAGS & MVALUE_IS_FP) == 0) {
		RIGHT_FPVAL = RIGHT_INTVAL;
		RIGHT_FLAGS |= MVALUE_IS_FP;
	}
	RIGHT_FPVAL = fn(RIGHT_FPVAL);
}

// make sure arg is in [-1, 1] range before calling function
static void perform_ranged_fp(double (*fn)(double)) {
	if((RIGHT_FLAGS & MVALUE_IS_FP) == 0) {
		RIGHT_FPVAL = RIGHT_INTVAL;
		RIGHT_FLAGS |= MVALUE_IS_FP;
	}
	if((RIGHT_FPVAL >= -1) && (RIGHT_FPVAL <= 1))
		RIGHT_FPVAL = fn(RIGHT_FPVAL);
	else {
		if(RIGHT_FLAGS & MVALUE_DEFINED)
			Throw_error("Argument out of range.");
		RIGHT_FPVAL = 0;
	}
}

// convert right-hand value from fp to int
static void right_fp_to_int() {
	RIGHT_INTVAL = RIGHT_FPVAL;
	RIGHT_FLAGS &= ~MVALUE_IS_FP;
}

// check both left-hand and right-hand values. if float, convert to int.
// in first pass, throw warning
static void both_ensure_int(bool warn) {
	if(LEFT_FLAGS & MVALUE_IS_FP) {
		LEFT_INTVAL = LEFT_FPVAL;
		LEFT_FLAGS &= ~MVALUE_IS_FP;
	}
	if(RIGHT_FLAGS & MVALUE_IS_FP) {
		RIGHT_INTVAL = RIGHT_FPVAL;
		RIGHT_FLAGS &= ~MVALUE_IS_FP;
	}
	Throw_first_pass_warning("Converted to integer for binary logic operator.");
}

// check both left-hand and right-hand values. if int, convert to float.
static void both_ensure_fp() {
	if((LEFT_FLAGS & MVALUE_IS_FP) == 0) {
		LEFT_FPVAL = LEFT_INTVAL;
		LEFT_FLAGS |= MVALUE_IS_FP;
	}
	if((RIGHT_FLAGS & MVALUE_IS_FP) == 0) {
		RIGHT_FPVAL = RIGHT_INTVAL;
		RIGHT_FLAGS |= MVALUE_IS_FP;
	}
}

// make sure both values are float, but mark left one as int (will become one)
static void ensure_int_from_fp() {
	both_ensure_fp();
	LEFT_FLAGS &= ~MVALUE_IS_FP;
}

// Try to reduce stacks by performing high-priority operations
static inline void try_to_reduce_stacks(int* open_parentheses) {
	if(operator_sp < 2) {
		alu_state = STATE_EXPECT_OPERAND_OR_MONADIC_OPERATOR;
		return;
	}
	if(operator_stack[operator_sp-2]->priority < operator_stack[operator_sp-1]->priority) {
		alu_state = STATE_EXPECT_OPERAND_OR_MONADIC_OPERATOR;
		return;
	}
	switch(operator_stack[operator_sp-2]->handle) {

// special (pseudo) operators

		case OPHANDLE_RETURN:
		// don't touch indirect_flag; needed for INDIRECT flag
		operator_sp--;// decrement operator stack pointer
		alu_state = STATE_END;
		break;

		case OPHANDLE_OPENING:
		indirect_flag = MVALUE_INDIRECT;// parentheses found
		switch(operator_stack[operator_sp-1]->handle) {

			case OPHANDLE_CLOSING:// matching parentheses
			operator_sp -= 2;// remove both of them
			alu_state = STATE_EXPECT_DYADIC_OPERATOR;
			break;

			case OPHANDLE_END:// unmatched parenthesis
			(*open_parentheses)++;// count
			goto RNTLObutDontTouchIndirectFlag;

			default:
			Bug_found("StrangeParenthesis", operator_stack[operator_sp-1]->handle);
		}
		break;

		case OPHANDLE_CLOSING:
		Throw_error("Too many ')'.");
		goto remove_next_to_last_operator;

// functions

		case OPHANDLE_INT:
		if(RIGHT_FLAGS & MVALUE_IS_FP)
			right_fp_to_int();
		goto remove_next_to_last_operator;

		case OPHANDLE_FLOAT:
		// convert right-hand value from int to fp
		if((RIGHT_FLAGS & MVALUE_IS_FP) == 0) {
			RIGHT_FPVAL = RIGHT_INTVAL;
			RIGHT_FLAGS |= MVALUE_IS_FP;
		}
		goto remove_next_to_last_operator;

		case OPHANDLE_SIN:
		perform_fp(sin);
		goto remove_next_to_last_operator;

		case OPHANDLE_COS:
		perform_fp(cos);
		goto remove_next_to_last_operator;

		case OPHANDLE_TAN:
		perform_fp(tan);
		goto remove_next_to_last_operator;

		case OPHANDLE_ARCSIN:
		perform_ranged_fp(asin);
		goto remove_next_to_last_operator;

		case OPHANDLE_ARCCOS:
		perform_ranged_fp(acos);
		goto remove_next_to_last_operator;

		case OPHANDLE_ARCTAN:
		perform_fp(atan);
		goto remove_next_to_last_operator;

// monadic operators

		case OPHANDLE_NOT:
		// different operations for fp and int
		if(RIGHT_FLAGS & MVALUE_IS_FP)
			right_fp_to_int();
		RIGHT_INTVAL = ~(RIGHT_INTVAL);
		RIGHT_FLAGS &= ~MVALUE_ISBYTE;
		goto remove_next_to_last_operator;

		case OPHANDLE_NEGATE:
		// different operations for fp and int
		if(RIGHT_FLAGS & MVALUE_IS_FP)
			RIGHT_FPVAL = -(RIGHT_FPVAL);
		else
			RIGHT_INTVAL = -(RIGHT_INTVAL);
		RIGHT_FLAGS &= ~MVALUE_ISBYTE;
		goto remove_next_to_last_operator;

		case OPHANDLE_LOWBYTEOF:
		// fp becomes int
		if(RIGHT_FLAGS & MVALUE_IS_FP)
			right_fp_to_int();
		RIGHT_INTVAL = (RIGHT_INTVAL) & 255;
		RIGHT_FLAGS |= MVALUE_ISBYTE;
		RIGHT_FLAGS &= ~MVALUE_FORCEBITS;
		goto remove_next_to_last_operator;

		case OPHANDLE_HIGHBYTEOF:
		// fp becomes int
		if(RIGHT_FLAGS & MVALUE_IS_FP)
			right_fp_to_int();
		RIGHT_INTVAL = ((RIGHT_INTVAL) >> 8) & 255;
		RIGHT_FLAGS |= MVALUE_ISBYTE;
		RIGHT_FLAGS &= ~MVALUE_FORCEBITS;
		goto remove_next_to_last_operator;

		case OPHANDLE_BANKBYTEOF:
		// fp becomes int
		if(RIGHT_FLAGS & MVALUE_IS_FP)
			right_fp_to_int();
		RIGHT_INTVAL = ((RIGHT_INTVAL) >> 16) & 255;
		RIGHT_FLAGS |= MVALUE_ISBYTE;
		RIGHT_FLAGS &= ~MVALUE_FORCEBITS;
		goto remove_next_to_last_operator;

// dyadic operators

		case OPHANDLE_POWEROF:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			both_ensure_fp();
			LEFT_FPVAL = pow(LEFT_FPVAL, RIGHT_FPVAL);
			goto handle_flags_and_dec_stacks;
		}
		if(RIGHT_INTVAL >= 0)
			LEFT_INTVAL = my_pow(LEFT_INTVAL, RIGHT_INTVAL);
		else {
			if(RIGHT_FLAGS & MVALUE_DEFINED)
				Throw_error("Exponent is negative.");
			LEFT_INTVAL = 0;
		}
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_MULTIPLY:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			both_ensure_fp();
			LEFT_FPVAL *= RIGHT_FPVAL;
		} else
			LEFT_INTVAL *= RIGHT_INTVAL;
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_DIVIDE:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			both_ensure_fp();
			if(RIGHT_FPVAL)
				LEFT_FPVAL /= RIGHT_FPVAL;
			else {
				if(RIGHT_FLAGS & MVALUE_DEFINED)
					Throw_error(exception_div_by_zero);
				LEFT_FPVAL = 0;
			}
		} else {
			if(RIGHT_INTVAL)
				LEFT_INTVAL /= RIGHT_INTVAL;
			else {
				if(RIGHT_FLAGS & MVALUE_DEFINED)
					Throw_error(exception_div_by_zero);
				LEFT_INTVAL = 0;
			}
		}
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_INTDIV:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			both_ensure_fp();
			if(RIGHT_FPVAL)
				LEFT_INTVAL = LEFT_FPVAL / RIGHT_FPVAL;
			else {
				if(RIGHT_FLAGS & MVALUE_DEFINED)
					Throw_error(exception_div_by_zero);
				LEFT_INTVAL = 0;
			}
			LEFT_FLAGS &= ~MVALUE_IS_FP;
		} else {
			if(RIGHT_INTVAL)
				LEFT_INTVAL /= RIGHT_INTVAL;
			else {
				if(RIGHT_FLAGS & MVALUE_DEFINED)
					Throw_error(exception_div_by_zero);
				LEFT_INTVAL = 0;
			}
		}
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_MODULO:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP)
			both_ensure_int(FALSE);
		if(RIGHT_INTVAL)
			LEFT_INTVAL %= RIGHT_INTVAL;
		else {
			if(RIGHT_FLAGS & MVALUE_DEFINED)
				Throw_error(exception_div_by_zero);
			LEFT_INTVAL = 0;
		}
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_ADD:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			both_ensure_fp();
			LEFT_FPVAL += RIGHT_FPVAL;
		} else
			LEFT_INTVAL += RIGHT_INTVAL;
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_SUBTRACT:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			both_ensure_fp();
			LEFT_FPVAL -= RIGHT_FPVAL;
		} else
			LEFT_INTVAL -= RIGHT_INTVAL;
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_SL:
		if(RIGHT_FLAGS & MVALUE_IS_FP)
			right_fp_to_int();
		if(LEFT_FLAGS & MVALUE_IS_FP)
			LEFT_FPVAL *= (1 << RIGHT_INTVAL);
		else
			LEFT_INTVAL <<= RIGHT_INTVAL;
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_ASR:
		if(RIGHT_FLAGS & MVALUE_IS_FP)
			right_fp_to_int();
		if(LEFT_FLAGS & MVALUE_IS_FP)
			LEFT_FPVAL /= (1 << RIGHT_INTVAL);
		else
			LEFT_INTVAL = my_asr(LEFT_INTVAL, RIGHT_INTVAL);
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_LSR:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP)
			both_ensure_int(TRUE);
		LEFT_INTVAL = ((uintval_t) LEFT_INTVAL) >> RIGHT_INTVAL;
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_LE:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			ensure_int_from_fp();
			LEFT_INTVAL = (LEFT_FPVAL <= RIGHT_FPVAL);
		} else
			LEFT_INTVAL = (LEFT_INTVAL <= RIGHT_INTVAL);
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_LESSTHAN:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			ensure_int_from_fp();
			LEFT_INTVAL = (LEFT_FPVAL < RIGHT_FPVAL);
		} else
			LEFT_INTVAL = (LEFT_INTVAL < RIGHT_INTVAL);
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_GE:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			ensure_int_from_fp();
			LEFT_INTVAL = (LEFT_FPVAL >= RIGHT_FPVAL);
		} else
			LEFT_INTVAL = (LEFT_INTVAL >= RIGHT_INTVAL);
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_GREATERTHAN:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			ensure_int_from_fp();
			LEFT_INTVAL = (LEFT_FPVAL > RIGHT_FPVAL);
		} else
			LEFT_INTVAL = (LEFT_INTVAL > RIGHT_INTVAL);
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_NOTEQUAL:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			ensure_int_from_fp();
			LEFT_INTVAL = (LEFT_FPVAL != RIGHT_FPVAL);
		} else
			LEFT_INTVAL = (LEFT_INTVAL != RIGHT_INTVAL);
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_EQUALS:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP) {
			ensure_int_from_fp();
			LEFT_INTVAL = (LEFT_FPVAL == RIGHT_FPVAL);
		} else
			LEFT_INTVAL = (LEFT_INTVAL == RIGHT_INTVAL);
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_AND:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP)
			both_ensure_int(TRUE);
		LEFT_INTVAL &= RIGHT_INTVAL;
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_EOR:
		Throw_first_pass_warning("\"EOR\" is deprecated; use \"XOR\" instead.");
		/*FALLTHROUGH*/

		case OPHANDLE_XOR:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP)
			both_ensure_int(TRUE);
		LEFT_INTVAL ^= RIGHT_INTVAL;
		goto handle_flags_and_dec_stacks;

		case OPHANDLE_OR:
		if((RIGHT_FLAGS | LEFT_FLAGS) & MVALUE_IS_FP)
			both_ensure_int(TRUE);
		LEFT_INTVAL |= RIGHT_INTVAL;
		goto handle_flags_and_dec_stacks;

		default:
		Bug_found("IllegalOperatorHandle", operator_stack[operator_sp-2]->handle);
		break;

// no other possibilities, so here are the shared endings

// entry point for dyadic operators
handle_flags_and_dec_stacks:
		// Handle flags and decrement value stack pointer
		// "OR" EXISTS, UNSURE and FORCEBIT flags
		LEFT_FLAGS |= RIGHT_FLAGS &
			(MVALUE_EXISTS|MVALUE_UNSURE|MVALUE_FORCEBITS);
		// "AND" DEFINED flag
		LEFT_FLAGS &= (RIGHT_FLAGS | ~MVALUE_DEFINED);
		LEFT_FLAGS &= ~MVALUE_ISBYTE;// clear ISBYTE flag
		operand_sp--;
		/*FALLTHROUGH*/

// entry point for monadic operators
remove_next_to_last_operator:
		// toplevel operation was something other than parentheses
		indirect_flag = 0;
		/*FALLTHROUGH*/

// entry point for '(' operator (has set indirect_flag, so don't clear now)
RNTLObutDontTouchIndirectFlag:
		// Remove operator and shift down next one
		operator_stack[operator_sp-2] = operator_stack[operator_sp-1];
		operator_sp--;// decrement operator stack pointer
		break;
	}
}

// The core of it. Returns number of parentheses left open.
// FIXME - make state machine using function pointers? or too slow?
static int parse_expression(result_t* result) {
	int	open_parentheses	= 0;

	operator_sp = 0;	// operator stack pointer
	operand_sp = 0;	// value stack pointer
	// begin by reading value (or monadic operator)
	alu_state = STATE_EXPECT_OPERAND_OR_MONADIC_OPERATOR;
	indirect_flag = 0;	// Contains either 0 or MVALUE_INDIRECT
	PUSH_OPERATOR(&ops_return);
	do {
		// check stack sizes. enlarge if needed
		if(operator_sp >= operator_stk_size)
			enlarge_operator_stack();
		if(operand_sp >= operand_stk_size)
			enlarge_operand_stack();
		switch(alu_state) {

			case STATE_EXPECT_OPERAND_OR_MONADIC_OPERATOR:
			expect_operand_or_monadic_operator();
			break;

			case STATE_EXPECT_DYADIC_OPERATOR:
			expect_dyadic_operator();
			break;// no fallthrough; state might
			// have been changed to END or ERROR

			case STATE_TRY_TO_REDUCE_STACKS:
			try_to_reduce_stacks(&open_parentheses);
			break;

			case STATE_MAX_GO_ON:	// suppress
			case STATE_ERROR:	// compiler
			case STATE_END:		// warnings
			break;

		}
	} while(alu_state < STATE_MAX_GO_ON);
	// done. check state.
	if(alu_state == STATE_END) {
		// check for bugs
		if(operand_sp != 1)
			Bug_found("OperandStackNotEmpty", operand_sp);
		if(operator_sp != 1)
			Bug_found("OperatorStackNotEmpty", operator_sp);
		// copy result
		*result = operand_stack[0];
		result->flags |= indirect_flag;	// OR indirect flag
		// only allow *one* force bit
		if(result->flags & MVALUE_FORCE24)
			result->flags &= ~(MVALUE_FORCE16 | MVALUE_FORCE08);
		else if(result->flags & MVALUE_FORCE16)
			result->flags &= ~MVALUE_FORCE08;
		// if there was nothing to parse, mark as undefined
		// (so ALU_defined_int() can react)
		if((result->flags & MVALUE_EXISTS) == 0)
			result->flags &= ~MVALUE_DEFINED;
		// do some checks depending on int/float
		if(result->flags & MVALUE_IS_FP) {
/*float*/		// if undefined, return zero
			if((result->flags & MVALUE_DEFINED) == 0)
				result->val.fpval = 0;
			// if value is sure, check to set ISBYTE
			else if(((result->flags & MVALUE_UNSURE) == 0)
			&& (result->val.fpval <= 255.0)
			&& (result->val.fpval >= -128.0))
				result->flags |= MVALUE_ISBYTE;
		} else {
/*int*/			// if undefined, return zero
			if((result->flags & MVALUE_DEFINED) == 0)
				result->val.intval = 0;
			// if value is sure, check to set ISBYTE
			else if(((result->flags & MVALUE_UNSURE) == 0)
			&& (result->val.intval <= 255)
			&& (result->val.intval >= -128))
				result->flags |= MVALUE_ISBYTE;
		}
	} else {
		// State is STATE_ERROR. But actually, nobody cares.
		// ...errors have already been reported anyway. :)
	}
	// return number of open (unmatched) parentheses
	return(open_parentheses);
}

// These functions handle numerical expressions. There are operators for
// arithmetic, logic, shift and comparison operations.
// There are several different ways to call the core function:
// intval_t ALU_any_int(void);
//		returns int value (0 if result was undefined)
// intval_t ALU_defined_int(void);
//		returns int value
//		if result was undefined, serious error is thrown
// void ALU_int_result(result_int_t*);
//		stores int value and flags (floats are transformed to int)
// void ALU_any_result(result_t*);
//		stores value and flags (result may be either int or float)
// int ALU_liberal_int(result_int_t*);
//		stores int value and flags. allows one '(' too many (for x-
//		indirect addressing). returns number of additional '(' (1 or 0).
// bool ALU_optional_defined_int(intval_t*);
//		stores int value if given. Returns whether stored.
//		Throws error if undefined.

// return int value (if result is undefined, returns zero)
// It the result's "exists" flag is clear (=empty expression), it throws an
// error.
// If the result's "defined" flag is clear, result_is_undefined() is called.
intval_t ALU_any_int(void) {
	result_t	result;

	if(parse_expression(&result))
		Throw_error(exception_paren_open);
	if((result.flags & MVALUE_EXISTS) == 0)
		Throw_error(exception_no_value);
	else if((result.flags & MVALUE_DEFINED) == 0)
		result_is_undefined();
	if(result.flags & MVALUE_IS_FP)
		return(result.val.fpval);
	else
		return(result.val.intval);
}

// return int value (if result is undefined, serious error is thrown)
intval_t ALU_defined_int(void) {
	result_t	result;

	if(parse_expression(&result))
		Throw_error(exception_paren_open);
	if((result.flags & MVALUE_DEFINED) == 0)
		Throw_serious_error(exception_undefined);
	if(result.flags & MVALUE_IS_FP)
		return(result.val.fpval);
	else
		return(result.val.intval);
}

// Store int value if given. Returns whether stored. Throws error if undefined.
// This function needs either a defined value or no expression at all. So
// empty expressions are accepted, but undefined ones are not.
// If the result's "defined" flag is clear and the "exists" flag is set, it
// throws a serious error and therefore stops assembly.
bool ALU_optional_defined_int(intval_t* target) {
	result_t	result;

	if(parse_expression(&result))
		Throw_error(exception_paren_open);
	if((result.flags & MVALUE_GIVEN) == MVALUE_EXISTS)
		Throw_serious_error(exception_undefined);
	if((result.flags & MVALUE_EXISTS) == 0)
		return(FALSE);
	// something was given, so store
	if(result.flags & MVALUE_IS_FP)
		*target = result.val.fpval;
	else
		*target = result.val.intval;
	return(TRUE);
}

// Store int value and flags (floats are transformed to int)
// It the result's "exists" flag is clear (=empty expression), it throws an
// error.
// If the result's "defined" flag is clear, result_is_undefined() is called.
void ALU_int_result(result_int_t* intresult) {
	result_t	result;

	if(parse_expression(&result))
		Throw_error(exception_paren_open);
	if((result.flags & MVALUE_EXISTS) == 0)
		Throw_error(exception_no_value);
	else if((result.flags & MVALUE_DEFINED) == 0)
		result_is_undefined();
	if(result.flags & MVALUE_IS_FP) {
		intresult->intval = result.val.fpval;
		intresult->flags = result.flags & ~MVALUE_IS_FP;
	} else {
		intresult->intval = result.val.intval;
		intresult->flags = result.flags;
	}
}

// Store int value and flags.
// This function allows for one '(' too many. Needed when parsing indirect
// addressing modes where internal indices have to be possible. Returns number
// of parentheses still open (either 0 or 1).
int ALU_liberal_int(result_int_t* intresult) {
	result_t	result;
	int		parentheses_still_open;

	parentheses_still_open = parse_expression(&result);
	if(parentheses_still_open > 1) {
		parentheses_still_open = 0;
		Throw_error(exception_paren_open);
	}
	if((result.flags & MVALUE_EXISTS)
	&& ((result.flags & MVALUE_DEFINED) == 0))
		result_is_undefined();
	if(result.flags & MVALUE_IS_FP) {
		intresult->intval = result.val.fpval;
		intresult->flags = result.flags & ~MVALUE_IS_FP;
	} else {
		intresult->intval = result.val.intval;
		intresult->flags = result.flags;
	}
	return(parentheses_still_open);
}

// Store value and flags (result may be either int or float)
// It the result's "exists" flag is clear (=empty expression), it throws an
// error.
// If the result's "defined" flag is clear, result_is_undefined() is called.
void ALU_any_result(result_t* result) {
	if(parse_expression(result))
		Throw_error(exception_paren_open);
	if((result->flags & MVALUE_EXISTS) == 0)
		Throw_error(exception_no_value);
	else if((result->flags & MVALUE_DEFINED) == 0)
		result_is_undefined();
}
