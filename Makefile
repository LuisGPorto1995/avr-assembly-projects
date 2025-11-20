# ======================= Project =======================
MCU    := atmega2560
F_CPU  := 16000000UL
TARGET := main

# ======================= Upload ========================
PROG ?= wiring
BAUD ?= 115200

ifeq ($(OS),Windows_NT)
  PORT   ?= COM3
else
  PORT   ?= /dev/ttyACM0
endif
RM      = rm -rf

# ======================= Tools =========================
ASM      := avra
AVRDUDE  := avrdude
AVRA_INC ?= include

# ======================= Files =========================
SRC    := src/$(TARGET).asm
OUTDIR := build

# ======================= Targets =======================
.PHONY: all flash clean

all: hex
hex: $(OUTDIR)/$(TARGET).hex

$(OUTDIR)/$(TARGET).hex: $(SRC)
	@mkdir -p $(@D)
	$(ASM) -I "$(AVRA_INC)" -l "$(@D)/$(TARGET).lst" -o "$@" "$<"

flash: $(OUTDIR)/$(TARGET).hex
	$(AVRDUDE) -v -c $(PROG) -p m2560 -P "$(PORT)" -b $(BAUD) -D -U flash:w:$<:i

clean:
	-$(RM) "$(OUTDIR)"