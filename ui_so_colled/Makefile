# Makefile for macOS ARM64 Password Generator (multi-file build)

AS      = as
LD      = ld
LDFLAGS = -lSystem -syslibroot $(shell xcrun --show-sdk-path) -e _start -arch arm64

OBJS    = main.o ui.o prng.o
TARGET  = password_gen

all: $(TARGET)

$(TARGET): $(OBJS)
	$(LD) -o $@ $^ $(LDFLAGS)

%.o: %.asm
	$(AS) -o $@ $<

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
