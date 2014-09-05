//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Mnemonic definitions
#ifndef mnemo_H
#define mnemo_H


// Prototypes

// create dynamic buffer, build keyword trees
extern void	Mnemo_init(void);
// Check whether mnemonic in GlobalDynaBuf is supported by 6502 cpu.
extern bool	keyword_is_6502mnemo(int length);
// Check whether mnemonic in GlobalDynaBuf is supported by 6510 cpu.
extern bool	keyword_is_6510mnemo(int length);
// Check whether mnemonic in GlobalDynaBuf is supported by 65c02 cpu.
extern bool	keyword_is_65c02mnemo(int length);
// Check whether mnemonic in GlobalDynaBuf is supported by Rockwell 65c02 cpu.
//extern bool	keyword_is_Rockwell65c02mnemo(int length);
// Check whether mnemonic in GlobalDynaBuf is supported by WDC 65c02 cpu.
//extern bool	keyword_is_WDC65c02mnemo(int length);
// Check whether mnemonic in GlobalDynaBuf is supported by 65816 cpu.
extern bool	keyword_is_65816mnemo(int length);


#endif
