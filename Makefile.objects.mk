
OBJS= \
	src/derelict/sdl2/internal/sdl_types.o \
	src/audio/audio.o \
	src/audio/player.o \
	src/audio/timer.o \
	src/audio/callback.o \
	src/ct/purge.o \
	src/ct/base.o \
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
	src/ct/purge.o \
	src/ct/dump.o \
	src/ct/build.o \
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
