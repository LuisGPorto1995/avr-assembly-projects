# ======================= Project =======================
MCU    := atmega2560
F_CPU  := 16000000UL
TARGET := main

# ======================= Upload ========================
PROG ?= wiring
BAUD ?= 115200

ifeq ($(OS),Windows_NT)
  PORT   ?= COM3
  RM      = del /Q /F
  NULDEV  = NUL
else
  PORT   ?= /dev/ttyACM0
  RM      = rm -f
  NULDEV  = /dev/null
endif

# ======================= Tools =========================
ASM      := avra
AVRDUDE  := avrdude
AVRA_INC ?= /usr/local/share/avra   # <- use the path you installed

# ======================= Files =========================
SRC    := src/$(TARGET).asm
OUTDIR := build

# ======================= Targets =======================
.PHONY: all hex flash clean size print-config

all: hex
hex: $(OUTDIR)/$(TARGET).hex

$(OUTDIR)/$(TARGET).hex: $(SRC)
	@mkdir -p $(@D)
	$(ASM) -I "$(AVRA_INC)" -l "$(@D)/$(TARGET).lst" -o "$@" "$<"

flash: $(OUTDIR)/$(TARGET).hex
	$(AVRDUDE) -v -c $(PROG) -p m2560 -P "$(PORT)" -b $(BAUD) -D -U flash:w:$<:i

size:
	@echo "No ELF with AVRA; see $(OUTDIR)/$(TARGET).lst for sizes."

print-config:
	@echo "MCU      = $(MCU)"
	@echo "F_CPU    = $(F_CPU)"
	@echo "PORT     = $(PORT)"
	@echo "PROG     = $(PROG)"
	@echo "BAUD     = $(BAUD)"
	@echo "ASM      = $(ASM)"
	@echo "AVRA_INC = $(AVRA_INC)"
	@echo "SRC      = $(SRC)"
	@echo "OUTDIR   = $(OUTDIR)"

clean:
	-$(RM) "$(OUTDIR)/$(TARGET).hex" 2>$(NULDEV)
	-$(RM) "$(OUTDIR)/$(TARGET).cof" 2>$(NULDEV)
	-$(RM) "$(OUTDIR)/$(TARGET).lst" 2>$(NULDEV)
