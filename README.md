# AVR Assembly Projects

This repository contains educational **low-level assembly projects** for **Atmel (AVR) microcontrollers**, such as the ATmega2560 (Arduino Mega).

The goal is to demonstrate how microcontrollers work **at the hardware level**, and to teach processor architecture, memory-mapped I/O, registers, peripherals, and how digital machines execute instructions.

---

## Why Assembly?

Assembly teaches:
- How instructions manipulate CPU state and memory
- How peripherals are controlled at the register level
- How high-level abstractions like C translate to machine code
- How timing, memory layout, and I/O work inside microcontrollers

---

## 🖥️ Supported Platforms

- ✅ **Windows 10/11**
- ✅ **Linux (Debian/Ubuntu-based)**

---

## ⚙️ Toolchain Setup

---

### 🔧 Linux Setup

Based on: https://gitlab.com/jjchico-edc/avr-bare#user-content-toolchain-install

```bash
sudo apt update
sudo apt install -y build-essential binutils-avr gcc-avr gdb-avr avr-libc avrdude make git
sudo snap install code --classic
sudo usermod -aG dialout $USER
```
"sudo usermod -aG dialout $USER" is used to allow user access USB ports. Also, if you're using a VM, remember to enable USB 2.0 control and add a filter for your Arduino board.

After that check the dependencies in the terminal:

```bash
avr-gcc --version
avr-objcopy --version
avrdude -v
make --version
```

---

### 🔧 Windows Setup

Install VS Code C/C++ setup:
https://code.visualstudio.com/docs/cpp/config-mingw

Install MSYS2:
https://www.msys2.org/

Make sure to add "C:\msys64\ucrt64\bin" to the PATH

Open MSYS2 MINGW64 and install avr dependencies and avrdude:

```bash
pacman -S \
  mingw-w64-x86_64-avr-gcc \
  mingw-w64-x86_64-avr-binutils \
  mingw-w64-x86_64-avr-libc \
  mingw-w64-x86_64-avrdude \
```

Make sure to add "C:\msys64\mingw64\bin" to the PATH

Run Powershell as an administrator and install make:
```bash
choco install make
```

After that, verify the install via CMD:

```bash
avr-gcc --version
avr-objcopy --version
avrdude -v
make --version
```
---

## 📁 Project Structure

The repository follows the following structure:

avr-assembly-projects/
├── src/
│   └── main.S         # AVR Assembly source
├── Makefile
└── README.md

---

## 🧰 Makefile Template

```make
# ---------- Project ----------
MCU     := atmega2560
F_CPU   := 16000000UL
TARGET  := main

# ---------- Upload ----------
PROG    := wiring
BAUD    := 115200

# Auto-port fallback
ifeq ($(OS),Windows_NT)
  PORT ?= COM3
  RM   := del /Q /F
  NUL  := NUL
else
  PORT ?= /dev/ttyACM0
  RM   := rm -f
  NUL  := /dev/null
endif

# ---------- Tools ----------
CC       := avr-gcc
OBJCOPY  := avr-objcopy
CFLAGS   := -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os
ASFLAGS  := -mmcu=$(MCU) -x assembler-with-cpp

SRC := src/$(TARGET).S

# ---------- Targets ----------
.PHONY: build flash clean

build: $(TARGET).hex

$(TARGET).elf: $(SRC)
	$(CC) $(ASFLAGS) -o $@ $<

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -j .text -j .data -O ihex $< $@

flash: $(TARGET).hex
	avrdude -v -c $(PROG) -p $(MCU) -P $(PORT) -b $(BAUD) -D -U flash:w:$<:i

clean:
	-$(RM) *.hex *.elf 2>$(NUL)
```

The Makefile detects if the program is being run on either Windows or Linux and create the files accordingly. Please check the port COMx for windows in the device management.
For Linux, run "dmesg | grep tty" and you'll see something like "[ 1294.123456] cdc_acm 1-1.2:1.0: ttyACM0: USB ACM device", which would mean your device is abailable as: /dev/ttyACM0

The projects of this repository will change according to those parameters, also according to the board, CPU clock frequency and programmer. Please keep that in check if you're going to use other
boards.

---

## ✅ Everything should be ready to go!

With this, you should be able to start programming in assembly using any AVR board. I'll keep this document updated for future changes and/or corrections.
