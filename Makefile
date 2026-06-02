# Makefile for macOS ARM64 GUI Password Generator (Cocoa in Assembly)

AS      = as
LD      = ld
SYSROOT = $(shell xcrun -sdk macosx --show-sdk-path)
LDFLAGS = -lSystem -framework Cocoa -syslibroot $(SYSROOT) -arch arm64 -e _main

all: gui_final

gui_stage1: gui_stage1.o
	$(LD) -o $@ $^ $(LDFLAGS)

gui_stage2: gui_stage2.o
	$(LD) -o $@ $^ $(LDFLAGS)

gui_stage3: gui_stage3.o
	$(LD) -o $@ $^ $(LDFLAGS)

gui_final: gui_final.o
	$(LD) -o $@ $^ $(LDFLAGS)

%.o: %.asm
	$(AS) -o $@ $<

clean:
	rm -f *.o gui_stage1 gui_stage2 gui_stage3 gui_final

.PHONY: all clean
