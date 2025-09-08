;------------------------------------------------------------------------------
; ATmega2560 (Arduino Mega) — Timer1 1 ms tick + delay_ms, blinking LED on PB7
; Build (Makefile does this): avr-gcc -mmcu=atmega2560 -x assembler-with-cpp ...
;
; WHY THIS WORKS (hardware path)
; - Timer1 is 16-bit and can run in CTC mode (WGM12=1). With /64 prescale, the
;   timer clock is 16 MHz / 64 = 250 kHz (4 µs per tick). OCR1A=249 → 250 ticks
;   → 1 ms. On compare match A, hardware sets OCF1A; if OCIE1A=1 and I=1, CPU
;   vectors to the Timer1 COMPA vector (program address $0022 in the table).
;   The avr-libc startup maps that vector to our label TIMER1_COMPA_vect.
;
; WHAT THE CODE DOES (software path)
; - ISR every 1 ms: tick_ms++ and, if delay_count != 0, delay_count--.
; - delay_ms(n): writes n to delay_count and busy-waits until it reaches 0.
; - main: configures LED pin PB7 as output and blinks it 250 ms on/off.
;
; NOTES ON AVR I/O VS DATA SPACE
; - IN/OUT/SBI/CBI use the 0..0x3F I/O space → use (REG - 0x20).
; - LDS/STS target data space → use the register name directly.
;------------------------------------------------------------------------------

#include <avr/io.h>

    .global main
    .global TIMER1_COMPA_vect

; --------------------------- LED selection ---------------------------
; On Arduino Mega, the "L" LED is on PB7 (Arduino D13).
.equ LED_DDR_IO , (DDRB-0x20)   ; I/O-space address for OUT
.equ LED_PORT_IO, (PORTB-0x20)  ; I/O-space address for SBI/CBI
.equ LED_BIT    , 7

; --------------------------- “variables” in SRAM ---------------------------
    .data
tick_ms:       .byte 2          ; 16-bit free-running ms counter (LSB first)
delay_count:   .byte 2          ; 16-bit countdown for delay_ms

; --------------------------- Timer1 COMPA ISR (1 ms) ------------------------
    .text
TIMER1_COMPA_vect:
    ; Prologue: save caller context + flags
    push r16
    push r17
    in   r16, (SREG-0x20)
    push r16

    ; tick_ms++
    lds  r16, tick_ms           ; LSB
    lds  r17, tick_ms+1         ; MSB
    inc  r16
    brne 1f
    inc  r17
1:  sts  tick_ms,   r16
    sts  tick_ms+1, r17

    ; if (delay_count != 0) delay_count--
    lds  r16, delay_count
    lds  r17, delay_count+1
    or   r16, r17
    breq 2f
    subi r16, 1                 ; LSB--
    sbci r17, 0                 ; borrow into MSB
    sts  delay_count,   r16
    sts  delay_count+1, r17
2:
    ; Epilogue: restore flags + regs, then RETI (re-enables I)
    pop  r16
    out  (SREG-0x20), r16
    pop  r17
    pop  r16
    reti


; --------------------------- init: GPIO + Timer1 ----------------------------
; Sets PB7 as output. Configures Timer1 → 1 ms tick. Enables global interrupts.
init:
    ; PB7 = output
    ldi  r16, (1<<LED_BIT)
    out  LED_DDR_IO, r16

    ; --- Timer1 in CTC mode, 1 ms period ---
    ; Clear TCCR1A (WGM11:0 = 0)
    ldi  r16, 0
    sts  TCCR1A, r16

    ; OCR1A = 249 (0x00F9) → 250 counts * 4 µs = 1 ms
    ldi  r16, hi8(249)
    sts  OCR1AH, r16
    ldi  r16, lo8(249)
    sts  OCR1AL, r16

    ; TCCR1B: WGM12=1 (CTC), prescaler CS11|CS10 = /64
    ldi  r16, (1<<WGM12) | (1<<CS11) | (1<<CS10)
    sts  TCCR1B, r16

    ; Enable Timer1 Compare A interrupt (OCIE1A)
    ldi  r16, (1<<OCIE1A)
    sts  TIMSK1, r16

    ; Clear software counters
    ldi  r16, 0
    sts  tick_ms,   r16
    sts  tick_ms+1, r16
    sts  delay_count,   r16
    sts  delay_count+1, r16

    sei                         ; set I-bit in SREG → IRQs enabled
    ret

; --------------------------- delay_ms(n) ------------------------------------
; API: pass n in r25:r24 (LSB in r24). Blocks until n ms elapsed.
    .global delay_ms
delay_ms:
    ; If n == 0 → return
    tst  r24
    brne 1f
    tst  r25
    breq 3f

1:  ; Store n into shared countdown (ISR decrements every 1 ms)
    sts  delay_count,   r24
    sts  delay_count+1, r25

2:  ; Poll until delay_count == 0
    lds  r18, delay_count
    lds  r19, delay_count+1
    or   r18, r19
    brne 2b
3:  ret

; --------------------------- main -------------------------------------------
; Called by avr-libc’s startup (which also builds the vector table).
; Blink the onboard "L" LED (PB7) at ~2 Hz: 250 ms ON, 250 ms OFF.
main:
    rcall init

blink_loop:
    sbi  LED_PORT_IO, LED_BIT   ; LED on
    ldi  r24, lo8(250)
    ldi  r25, hi8(250)
    rcall delay_ms

    cbi  LED_PORT_IO, LED_BIT   ; LED off
    ldi  r24, lo8(250)
    ldi  r25, hi8(250)
    rcall delay_ms

    rjmp blink_loop