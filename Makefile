# ---------- Project ----------
MCU   := atmega2560
F_CPU := 16000000UL
TARGET:= main

# ---------- Upload ----------
PROG  ?= wiring
BAUD  ?= 115200

# OS-specific defaults
ifeq ($(OS),Windows_NT)
  # Windows
  PORT   ?= COM3
  RM      = del /Q /F
  NULDEV  = NUL
else
  # Linux/macOS
  PORT   ?= /dev/ttyACM0
  RM      = rm -f
  NULDEV  = /dev/null
endif

# ---------- Tools ----------
CC       := avr-gcc
OBJCOPY  := avr-objcopy
CFLAGS   := -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os
ASFLAGS  := -mmcu=$(MCU) -x assembler-with-cpp

# ---------- Files ----------
SRC      := src/$(TARGET).S

# ---------- Targets ----------
.PHONY: build flash clean size

build: $(TARGET).hex

$(TARGET).elf: $(SRC)
	$(CC) $(ASFLAGS) -o $@ $<

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -j .text -j .data -O ihex $< $@

# Use -D to skip full chip erase (matches what worked in your VM)
flash: $(TARGET).hex
	avrdude -v -c $(PROG) -p m2560 -P $(PORT) -b $(BAUD) -D -U flash:w:$<:i

size: $(TARGET).elf
	avr-size --mcu=$(MCU) --format=avr $<

clean:
	-$(RM) *.elf 2>$(NULDEV)
	-$(RM) *.hex 2>$(NULDEV)
