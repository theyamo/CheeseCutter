LIBS=-ldl -lstdc++
COMFLAGS=-pg
DLINK=$(COMFLAGS)
VERSION=$(shell cat Version)
DFLAGS=$(COMFLAGS) -I./src -J./src/c64 -J./src/font -O1 -frelease -fno-bounds-check
CFLAGS=$(COMFLAGS) -O1
CXXFLAGS=-I./src -O3
COMPILE.d = $(DC) $(DFLAGS) -c -o $@
OUTPUT_OPTION = 
DC=gdc
EXE=
TARGET=ccutter
OBJCOPY=objcopy

include Makefile.objects.mk

$(TARGET): $(C64OBJS) $(OBJS) $(CXX_OBJS)
	$(DC) $(DLINK) -o $(TARGET) $(OBJS) $(CXX_OBJS) $(LIBS)

.cpp.o : $(CXX_SRCS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

.c.o : $(C_SRCS)
	$(CC) -c $< -o $@

ct: $(C64OBJS) $(CTOBJS)

ct2util: $(C64OBJS) $(UTILOBJS)
	$(DC) $(DLINK) -o $@ $(UTILOBJS) $(LIBS) 

c64: $(C64OBJS)

all: c64 $(OBJS) $(CXX_OBJS) $(UTILOBJS) ct2util ct $(TARGET)

release: all
	strip ccutter$(EXE)
	strip ct2util$(EXE)

dist:	release
	tar --transform 's,^\.,cheesecutter-$(VERSION),' -cvf cheesecutter-$(VERSION)-linux-x86.tar.gz $(DIST_FILES)

clean: 
	rm -f *.o *~ resid/*.o resid-fp/*.o ccutter ct2util \
		$(C64OBJS) $(OBJS) $(CTOBJS) $(CXX_OBJS) $(UTILOBJS) $(C_OBJS)

dclean: clean
	rm cheesecutter-$(VERSION)-linux-x86.tar.gz

tar:
	git archive master --prefix=cheesecutter-$(VERSION)/ | bzip2 > cheesecutter-$(VERSION)-src.tar.bz2
# --------------------------------------------------------------------------------

src/c64/player.bin: src/c64/player_v4.acme
	acme -f cbm --outfile $@ $<

src/c64/custplay.bin: src/c64/custplay.acme
	acme -f cbm --outfile $@ $<


src/ct/base.o: src/c64/player.bin
src/ui/ui.o: src/ui/help.o

%.o: %.d
	$(COMPILE.d) $(OUTPUT_OPTION) $<



