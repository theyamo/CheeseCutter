DEBUG=0

#LIBS=/opt/ldc/build/lib/libphobos-ldc.a /opt/ldc/build/lib/libdruntime-ldc.a -lstdc++ -framework Foundation -framework SDL 
LIBS=-ldl -lstdc++
#COMFLAGS= -mmacosx-version-min=10.7
DLINK=$(COMFLAGS)
DFLAGS=-I./src -I./src/derelict/util -I./src/derelict/sdl -I./src/resid -I./src/player -I./src/font -J./src/c64 -J./src/font
CFLAGS=$(COMFLAGS) 
CXXFLAGS=$(CFLAGS) -I./src -O2
COMPILE.d = $(DC) $(DFLAGS) -c -o $@
OUTPUT_OPTION = 
DC=gdc-4.6
EXE=
TARGET=ccutter
OBJCOPY=objcopy

OBJS=   src/derelict/util/compat.o \
	src/derelict/util/sharedlib.o \
	src/derelict/util/exception.o \
        src/derelict/util/loader.o \
        src/derelict/util/wintypes.o \
        src/derelict/util/xtypes.o \
        src/derelict/sdl/sdl.o \
        src/derelict/sdl/net.o \
        src/derelict/sdl/ttf.o \
        src/derelict/sdl/mixer.o \
        src/derelict/sdl/image.o \
        src/derelict/sdl/sdlfuncs.o \
        src/derelict/sdl/sdltypes.o \
        src/derelict/sdl/macinit/CoreFoundation.o \
        src/derelict/sdl/macinit/DerelictSDLMacLoader.o \
        src/derelict/sdl/macinit/ID.o \
        src/derelict/sdl/macinit/MacTypes.o \
        src/derelict/sdl/macinit/NSApplication.o \
        src/derelict/sdl/macinit/NSArray.o \
        src/derelict/sdl/macinit/NSAutoreleasePool.o \
        src/derelict/sdl/macinit/NSDictionary.o \
        src/derelict/sdl/macinit/NSEnumerator.o \
        src/derelict/sdl/macinit/NSEvent.o \
        src/derelict/sdl/macinit/NSGeometry.o \
        src/derelict/sdl/macinit/NSMenu.o \
        src/derelict/sdl/macinit/NSMenuItem.o \
        src/derelict/sdl/macinit/NSNotification.o \
        src/derelict/sdl/macinit/NSObject.o \
        src/derelict/sdl/macinit/NSProcessInfo.o \
        src/derelict/sdl/macinit/NSString.o \
        src/derelict/sdl/macinit/NSZone.o \
        src/derelict/sdl/macinit/runtime.o \
        src/derelict/sdl/macinit/SDLMain.o \
        src/derelict/sdl/macinit/selectors.o \
        src/derelict/sdl/macinit/string.o \
	src/audio/audio.o \
	src/audio/player.o \
	src/audio/timer.o \
	src/audio/callback.o \
	src/ct/purge.o \
	src/ct/base.o \
	src/ct/pack.o \
	src/ct/dump.o \
	src/com/fb.o \
	src/com/cpu.o \
	src/main.o \
	src/ui/tables.o \
	src/ui/dialogs.o \
	src/ui/ui.o \
	src/ui/input.o \
	src/ui/help.o \
	src/seq/seqtable.o \
	src/seq/tracktable.o \
	src/seq/trackmap.o \
	src/seq/fplay.o \
	src/seq/sequencer.o \
	src/audio/resid/filter.o

CXX_SRCS = src/audio/resid/residctrl.cpp \
	src/resid/envelope.cpp \
	src/resid/extfilt.cpp \
	src/resid/filter.cpp \
	src/resid/w6_ps_.cpp \
	src/resid/w6_pst.cpp \
	src/resid/w6_p_t.cpp \
	src/resid/w6__st.cpp \
	src/resid/w8_ps_.cpp \
	src/resid/w8_pst.cpp \
	src/resid/w8_p_t.cpp \
	src/resid/w8__st.cpp \
	src/resid/pot.cpp \
	src/resid/sid.cpp \
	src/resid/voice.cpp \
	src/resid/wave.cpp \
	src/resid-fp/envelopefp.cpp \
	src/resid-fp/extfiltfp.cpp \
	src/resid-fp/filterfp.cpp \
	src/resid-fp/potfp.cpp \
	src/resid-fp/sidfp.cpp \
	src/resid-fp/versionfp.cpp \
	src/resid-fp/voicefp.cpp \
	src/resid-fp/wavefp.cpp 

CXX_OBJS = $(CXX_SRCS:.cpp=.o)

UTILOBJS = src/ct2util.o src/ct/base.o src/com/cpu.o src/ct/pack.o src/ct/purge.o src/ct/dump.o

C64OBJS = src/c64/player.bin \
	src/c64/custplay.bin

CTOBJS	=

$(TARGET): $(C64OBJS) $(OBJS) $(CXX_OBJS)
	$(DC) $(DLINK) -o $(TARGET) $(OBJS) $(CXX_OBJS) $(LIBS)

.cpp.o : $(CXX_SRCS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

ct: $(C64OBJS) $(CTOBJS)

ct2util: $(C64OBJS) $(UTILOBJS)
	$(DC) $(DLINK) -o $@ $(UTILOBJS) $(LIBS)

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
	rm -rf CheeseCutter_2.5.1.dmg
	arch/makedmg.sh

clean: 
	rm -f *.o *~ resid/*.o resid-fp/*.o ccutter ct2util \
		$(C64OBJS) $(OBJS) $(CTOBJS) $(CXX_OBJS) $(UTILOBJS)

dclean: clean
	rm -rf dist
	rm -rf CheeseCutter.app
	rm -rf CheeseCutter_2.5.1.dmg


tar:
	git archive master --prefix=cheesecutter-2.5.1/ | bzip2 > cheesecutter-2.5.1-macosx-src.tar.bz2
# --------------------------------------------------------------------------------

src/c64/player.bin: src/c64/player.acme
	acme -f cbm --outfile $@ $<

src/c64/custplay.bin: src/c64/custplay.acme
	acme -f cbm --outfile $@ $<


src/ct/base.o: src/c64/player.bin
src/ui/ui.o: src/ui/help.o

%.o: %.d
	$(COMPILE.d) $(OUTPUT_OPTION) $<



