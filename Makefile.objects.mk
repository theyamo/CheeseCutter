OBJS=   src/derelict/util/compat$(OBJ_EXT) \
	src/derelict/util/sharedlib$(OBJ_EXT) \
	src/derelict/util/exception$(OBJ_EXT) \
        src/derelict/util/loader$(OBJ_EXT) \
        src/derelict/util/wintypes$(OBJ_EXT) \
        src/derelict/util/xtypes$(OBJ_EXT) \
        src/derelict/sdl/sdl$(OBJ_EXT) \
        src/derelict/sdl/net$(OBJ_EXT) \
        src/derelict/sdl/ttf$(OBJ_EXT) \
        src/derelict/sdl/mixer$(OBJ_EXT) \
        src/derelict/sdl/image$(OBJ_EXT) \
        src/derelict/sdl/sdlfuncs$(OBJ_EXT) \
        src/derelict/sdl/sdltypes$(OBJ_EXT) \
        src/derelict/sdl/macinit/CoreFoundation$(OBJ_EXT) \
        src/derelict/sdl/macinit/DerelictSDLMacLoader$(OBJ_EXT) \
        src/derelict/sdl/macinit/ID$(OBJ_EXT) \
        src/derelict/sdl/macinit/MacTypes$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSApplication$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSArray$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSAutoreleasePool$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSDictionary$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSEnumerator$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSEvent$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSGeometry$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSMenu$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSMenuItem$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSNotification$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSObject$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSProcessInfo$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSString$(OBJ_EXT) \
        src/derelict/sdl/macinit/NSZone$(OBJ_EXT) \
        src/derelict/sdl/macinit/runtime$(OBJ_EXT) \
        src/derelict/sdl/macinit/SDLMain$(OBJ_EXT) \
        src/derelict/sdl/macinit/selectors$(OBJ_EXT) \
        src/derelict/sdl/macinit/string$(OBJ_EXT) \
	src/audio/audio$(OBJ_EXT) \
	src/audio/player$(OBJ_EXT) \
	src/audio/timer$(OBJ_EXT) \
	src/audio/callback$(OBJ_EXT) \
	src/ct/purge$(OBJ_EXT) \
	src/ct/base$(OBJ_EXT) \
	src/ct/dump$(OBJ_EXT) \
	src/com/fb$(OBJ_EXT) \
	src/com/cpu$(OBJ_EXT) \
	src/com/kbd$(OBJ_EXT) \
	src/com/session$(OBJ_EXT) \
	src/com/util$(OBJ_EXT) \
	src/main$(OBJ_EXT) \
	src/ui/tables$(OBJ_EXT) \
	src/ui/dialogs$(OBJ_EXT) \
	src/ui/ui$(OBJ_EXT) \
	src/ui/input$(OBJ_EXT) \
	src/ui/help$(OBJ_EXT) \
	src/seq/seqtable$(OBJ_EXT) \
	src/seq/tracktable$(OBJ_EXT) \
	src/seq/trackmap$(OBJ_EXT) \
	src/seq/fplay$(OBJ_EXT) \
	src/seq/sequencer$(OBJ_EXT) \
	src/audio/resid/filter$(OBJ_EXT)

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

CXX_OBJS = $(CXX_SRCS:.cpp=$(OBJ_EXT))

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

C_OBJS	= $(C_SRCS:.c=$(OBJ_EXT))

UTILOBJS = src/ct2util$(OBJ_EXT) \
	src/ct/base$(OBJ_EXT) \
	src/com/cpu$(OBJ_EXT) \
	src/com/util$(OBJ_EXT) \
	src/ct/purge$(OBJ_EXT) \
	src/ct/dump$(OBJ_EXT) \
	src/ct/build$(OBJ_EXT) \
	$(C_OBJS)

C64OBJS = src/c64/player.bin

CTOBJS	=

DIST_FILES = \
	./ChangeLog \
	./LICENSE.md \
	./README.md \
	./ccutter$(EXE) \
	./ct2util$(EXE) \
	./tunes/*
