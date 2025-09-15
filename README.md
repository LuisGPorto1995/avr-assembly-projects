# AVR Assembly Projects — 28BYJ-48 + ULN2003 + ATmega2560

Drive a **28BYJ-48** stepper motor using a **ULN2003** driver board and **AVR assembly** (AVRA/AVRASM2 syntax) on an **ATmega2560 (Arduino Mega)**.  
This README explains the hardware, stepping modes, precise steps-per-revolution math, speed configuration, the full code structure, and how to build/flash.

> Code file: `src/main.asm` (the README refers to labels/sections inside this file).

---

## 1) Hardware overview

### 28BYJ-48 stepper (5 V, geared, unipolar)
- Internally a 4-phase **unipolar** stepper (two windings, each with a center tap).  
  The **red** wire is the common +5 V center tap; the other four wires go to the coil ends.
- A reduction **gearbox** between the rotor and the output shaft gives high torque and fine resolution at low voltage.

### ULN2003 driver board
- A 7-channel **NPN Darlington** array used here as **low-side drivers** (sinks current from each coil end to GND).
- Each channel has a **flyback diode**; all diodes share **COM**. On the stepper board, **COM must go to +5 V** (same supply feeding the coil center-tap). This safely absorbs the inductive kick when coils turn off.
- Inputs IN1..IN4 go to the MCU pins; OUT1..OUT4 go to the motor coil wires; motor red wire → +5 V.

> **Power tip:** Use a dedicated 5 V supply for the motor (hundreds of mA headroom). **Common GND is mandatory** between motor PSU, ULN2003 board, and the Mega.

### Wiring used by this project
- **ATmega2560 PD0..PD3 → ULN2003 IN1..IN4** (drives coils A..D).
- **ULN2003 COM → +5 V** (motor supply).  
- **Motor red → +5 V**, four colored coil wires → ULN2003 OUT1..OUT4.  
- **PB7** (on-board LED “L”) is used as a step activity indicator.

---

## 2) Steps-per-revolution (SPR) — precise formula

Let:
- `internal_steps_per_rev` = rotor full steps per motor revolution (commonly **32** steps, i.e., 11.25°/step).
- `gear_ratio` = gearbox reduction (nominal ≈ **64:1**; many units measure ≈ **63.68395:1**).
- `mode_factor` = **1** for 4-step two-phase full-step, **2** for 8-step half-step.

**Output-shaft SPR:**

SPR = internal_steps_per_rev × gear_ratio × mode_factor

Examples:
- Nominal: `32 × 64 × 2 = 4096` steps/rev (half-step) or `32 × 64 = 2048` (two-phase full-step).
- Measured gear ~63.68395: `32 × 63.68395 × 2 ≈ 4076` (half-step) or `≈ 2038` (two-phase).

> **Calibrate for precision:** Command steps at a slow speed until the **output shaft** makes exactly 1 turn. The number you issued is your true `SPR` for that mode. (You can back-solve `gear_ratio = SPR / (32 × mode_factor)` if you care.)

---

## 3) Speed math (RPM ↔ delay)

This code advances **one step** per table entry. The main loop uses **two equal delays per step** (LED on-delay + LED off-delay).

Let:
- `SPR` = your chosen/measured steps per revolution (see §2).
- `RPM` = desired shaft speed.

**Steps per second:** `pps = SPR × RPM / 60`  
**ms per step:** `ms_per_step = 60000 / (SPR × RPM)`

Because there are **two delays per step**, the compile-time constant should be:
    *DELAY_COUNT_MS ≈ (60000 / (SPR × RPM)) / 2*


Examples (half-step, nominal `SPR=4096`):
- 1 RPM → `ms/step ≈ 14.65` → `DELAY_COUNT_MS ≈ 7–8`
- 5 RPM → `ms/step ≈ 2.93`  → `DELAY_COUNT_MS ≈ 1–2`

> Start slow and increase speed once motion is reliable; sudden high step rates can cause missed steps.

---

## 4) Code structure (what each part does)

### Toolchain & syntax
- Written for **AVRA/AVRASM2** syntax (not GAS).  
- Uses `m2560def.inc` for register names and vector symbols (e.g., `OC1Aaddr`).

### Vector table
- Reset vector → `RESET`.  
- Timer1 Compare-A vector → `TIM1_OC1A_ISR`.

### Delay infrastructure
- **Timer1 CTC @ 1 kHz** (1 ms tick): prescaler `/64`, `OCR1A=249`.  
- **ISR**: only decrements a 16-bit **`delay_count`** if it’s non-zero.  
- **DELAY_MS(n)**: stores `n` into `delay_count` atomically, then busy-waits until the ISR counts it down to zero.

### Step generation (PORTD low nibble)
- A **step table** in FLASH is walked cyclically with `LPM r16, Z+`.  
- Only **PD3..PD0** are updated (mask preserves PD7..PD4).  
- The on-board LED (PB7) is set during the first delay and cleared during the second delay for a visual “on/off per step”.

### Two supported step modes in `steps:` (switch by commenting)
- **4-step two-phase full-step** (active by default): max torque, fewer states.  
  Table entries energize two adjacent coils at once (pairs like AB, BC, CD, DA); your file’s table is equivalent but permuted to match your wiring order.
- **8-step half-step** (commented): higher resolution and smoother motion.  
  Alternates 1-phase and 2-phase states (A, AB, B, BC, …).

---

## 5) Configuration knobs (what to change)

In `src/main.asm`:

- **Stepping mode:**  
  *Two-phase full-step* (4 entries) is enabled by default.
  - To use **half-step**, comment the 4-entry table, **uncomment** the 8-entry table, and set `PATTERN_COUNT = 8`. Recompute `SPR` for half-step.
- **Speed (RPM):**  
  Set `SPR` and `RPM`, then compute `DELAY_COUNT_MS` with  
  `DELAY_COUNT_MS ≈ (60000 / (SPR × RPM)) / 2` (two delays per step).  
  AVRA supports arithmetic in `.equ`, but if your assembler balks, precompute the integer and paste it in.
- **Direction:**  
  Reverse either by walking the table **backwards** (decrement Z and wrap) or by reversing the byte order in the table.