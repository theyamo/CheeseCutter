//
// ACME - a crossassembler for producing 6502/65c02/65816 code.
// Copyright (C) 1998-2006 Marco Baye
// Have a look at "acme.c" for further info
//
// Tree stuff
#ifndef tree_H
#define tree_H

#include <stdio.h>
#include "config.h"


// Macros for pre-defining tree node tables
#define PREDEFNODE(s, v)	{NULL, NULL, 1, s, (void*) (v)}
#define PREDEFLAST(s, v)	{NULL, NULL, 0, s, (void*) (v)}


// type definitions

typedef unsigned int	hash_t;
// Must be unsigned, otherwise the hash algorithm won't be very useful!

// tree node structure type definition (for easy lookups)
struct node_t {
	node_t*		greater_than;	// pointer to sub-tree
	node_t*		less_than_or_equal;// pointer to sub-tree
	hash_t		hash_value;
	const char*	id_string;	// name, zero-terminated
	void*		body;		// bytes, handles or handler function
};

// tree node structure type definition (for macros/labels)
struct node_ra_t {
	node_ra_t*	greater_than;	// pointer to sub-tree
	node_ra_t*	less_than_or_equal;// pointer to sub-tree
	hash_t		hash_value;
	char*		id_string;	// name, zero-terminated
	void*		body;		// macro/label body
	unsigned int	id_number;	// zone number
};


// Prototypes

// Add predefined tree items to given tree.
extern void	Tree_add_table(node_t** tree, node_t* table_to_add);
// Search for a given ID string in a given tree. Store "Body" component in
// NodeBody and return TRUE. Return FALSE if no matching item found.
extern bool	Tree_easy_scan(node_t* tree, void** node_body, struct dynabuf_t* dyna_buf);
// Search for a "RAM tree" item. Save pointer to found tree item in given
// location. If no matching item is found, check the "Create" flag: If set,
// create new tree item, link to tree, fill with data and store its pointer.
// If "Create" is clear, store NULL. Returns whether item was created.
extern bool	Tree_hard_scan(node_ra_t**, node_ra_t**, int, bool);
// Calls given function for each node of each tree of given forest.
extern void	Tree_dump_forest(node_ra_t**, int, void (*)(node_ra_t*, FILE*), FILE*);


#endif
