
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
	src/com/kbd.o \
	src/com/session.o \
	src/com/util.o \
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

C_SRCS	= \
	src/asm/acme.c \
	src/asm/alu.c \
	src/asm/basics.c \
	src/asm/cpu.c \
	src/asm/dynabuf.c \
	src/asm/encoding.c \
	src/asm/flow.c \
	src/asm/global.c \
	src/asm/input.c src/asm/label.c \
	src/asm/macro.c \
	src/asm/mnemo.c \
	src/asm/output.c \
	src/asm/platform.c \
	src/asm/section.c \
	src/asm/tree.c

C_OBJS	= $(C_SRCS:.c=.o)

UTILOBJS = src/ct2util.o \
	src/ct/base.o \
	src/com/cpu.o \
	src/com/util.o \
	src/com/asm.o \
	src/ct/pack.o \
	src/ct/purge.o \
	src/ct/dump.o \
	$(C_OBJS)

C64OBJS = src/c64/player.bin \
	src/c64/custplay.bin

CTOBJS	=

DIST_FILES = \
	./ChangeLog \
	./COPYING \
	./README \
	./ccutter$(EXE) \
	./ct2util$(EXE) \
	./tunes/*
