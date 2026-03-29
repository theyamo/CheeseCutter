PREFIX ?= /usr/local
DESTDIR ?=
EXAMPLESDIR ?= $(PREFIX)/share/examples/ccutter
VERSION := $(shell cat Version 2>/dev/null || echo "unknown")
DLIBS=-L-ldl -L-lstdc++ -L-lSDL2
DFLAGS=-d-version=DerelictSDL2_Static -I./src -J./src/c64 -J./src/font
CFLAGS=-O2 -std=c99
CXXFLAGS=-O2 -I./src
COMPILE.d = $(DC) $(DFLAGS) -c
DC=ldc2
TARGET=ccutter

include Makefile.objects.mk

.PHONY: install release dist clean dclean tar

%.o: %.d
	$(DC) $(DFLAGS) -c -of=$@ $<

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

all: ct2util ccutter

ccutter: $(C64OBJS) $(OBJS) $(CXX_OBJS)
	$(DC) -of=$@ $(OBJS) $(CXX_OBJS) $(DLIBS)

ct: $(C64OBJS) $(CTOBJS)

ct2util: $(C64OBJS) $(UTILOBJS)
	$(DC) -of=$@ $(UTILOBJS)

c64: $(C64OBJS)

install: all
	strip ccutter
	strip ct2util
	install -D -m 755 ccutter $(DESTDIR)$(PREFIX)/bin/ccutter
	install -D -m 755 ct2util $(DESTDIR)$(PREFIX)/bin/ct2util
	install -d $(DESTDIR)$(EXAMPLESDIR)/example_tunes
	cp -r tunes/* $(DESTDIR)$(EXAMPLESDIR)/example_tunes/

# release version with additional optimizations
release: DFLAGS += -frelease -fno-bounds-check
release: all
	strip ccutter
	strip ct2util

# tarred release
dist:	release
	tar --transform 's,^\.,cheesecutter-$(VERSION),' -czf cheesecutter-$(VERSION)-linux-x86.tar.gz $(DIST_FILES)

clean: 
	rm -f *.o *~ resid/*.o resid-fp/*.o ccutter ct2util \
		$(C64OBJS) $(OBJS) $(CTOBJS) $(CXX_OBJS) $(UTILOBJS) $(C_OBJS)

dclean: clean
	rm -f cheesecutter-$(VERSION)-linux-x86.tar.gz

# tarred source from master
tar:
	git archive master --prefix=cheesecutter-$(VERSION)/ | bzip2 > cheesecutter-$(VERSION)-src.tar.bz2
# --------------------------------------------------------------------------------

src/c64/player.bin: src/c64/player_v4.acme
	acme -f cbm -Wno-old-for --outfile $@ $<

src/ct/base.o: src/c64/player.bin
src/ui/ui.o: src/ui/help.o
