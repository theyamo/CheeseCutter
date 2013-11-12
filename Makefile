DEBUG=0

#LIBS=/opt/ldc/build/lib/libphobos-ldc.a /opt/ldc/build/lib/libdruntime-ldc.a -lstdc++ -framework Foundation -framework SDL 
LIBS=-ldl -lstdc++
#COMFLAGS= -mmacosx-version-min=10.7
DLINK=$(COMFLAGS)
VERSION=$(shell cat Version)
DFLAGS=-I./src -I./src/derelict/util -I./src/derelict/sdl -I./src/resid -I./src/player -I./src/font -J./src/c64 -J./src/font
CFLAGS=$(COMFLAGS) 
CXXFLAGS=$(CFLAGS) -I./src -O2
COMPILE.d = $(DC) $(DFLAGS) -c -o $@
OUTPUT_OPTION = 
DC=gdc-4.6
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

ct2util: $(C64OBJS) $(UTILOBJS) $(C_OBJS)
	$(DC) $(DLINK) -o $@ $(UTILOBJS) $(C_OBJS) $(LIBS) 

c64: $(C64OBJS)

all: c64 $(OBJS) $(CXX_OBJS) ct2util ct $(TARGET)

release: all
	strip ccutter$(EXE)
	strip ct2util$(EXE)

	rm -rf CheeseCutter.app
	mkdir -p CheeseCutter.app/Contents/Frameworks
	cp -r arch/MacOs/Contents CheeseCutter.app
	cp -r /Library/Frameworks/SDL.framework CheeseCutter.app/Contents/Frameworks
	cp $(TARGET) CheeseCutter.app/Contents/MacOS
	cp ct2util CheeseCutter.app/Contents/MacOS

dist:	release
	rm -rf dist
	rm -rf CheeseCutter_$(VERSION).dmg
	arch/makedmg.sh

clean: 
	rm -f *.o *~ resid/*.o resid-fp/*.o ccutter ct2util \
		$(C64OBJS) $(OBJS) $(CTOBJS) $(CXX_OBJS) $(UTILOBJS) $(C_OBJS)

dclean: clean
	rm -rf dist
	rm -rf CheeseCutter.app
	rm -rf CheeseCutter_$(VERSION).dmg


tar:
	git archive master --prefix=cheesecutter-$(VERSION)/ | bzip2 > cheesecutter-$(VERSION)-src.tar.bz2
# --------------------------------------------------------------------------------

src/c64/player.bin: src/c64/player_v400.acme
	acme -f cbm --outfile $@ $<

src/c64/custplay.bin: src/c64/custplay.acme
	acme -f cbm --outfile $@ $<


src/ct/base.o: src/c64/player.bin
src/ui/ui.o: src/ui/help.o

%.o: %.d
	$(COMPILE.d) $(OUTPUT_OPTION) $<



