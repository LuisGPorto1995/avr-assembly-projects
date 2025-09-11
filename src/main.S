;------------------------------------------------------------------------------
; AVR Assembly Projects | ATmega2560 (Arduino Mega) — Delay milliseconds with Timer1
;
; WHY THIS WORKS (hardware path)
; - Timer1 is 16-bit and can run in CTC mode (WGM12=1). With /64 prescale, the
;   timer clock is 16 MHz / 64 = 250 kHz (4 µs per tick). OCR1A=249 → 250 ticks
;   → 1 ms. On compare match A, hardware sets OCF1A; if OCIE1A=1 and I=1, CPU
;   vectors to the Timer1 COMPA vector (program address $0022 in the table).
;   The avr-libc startup maps that vector to our label TIMER1_COMPA_vect.
;
; WHAT THE CODE DOES (software path)
; - ISR every 1 ms: if delay_count != 0, delay_count--.
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
    .global delay_ms ; so we can call it from C code if needed.

; --------------------------- LED selection ---------------------------
; On Arduino Mega, the "L" LED is on PB7 (Arduino D13).
.equ LED_DDR_IO ,   (DDRB-0x20)   ; I/O-space address for OUT.
.equ LED_PORT_IO,   (PORTB-0x20)  ; I/O-space address for SBI/CBI.
.equ LED_BIT    ,   7
.equ SREG_IO    ,   (SREG-0x20)   ; I/O-space address for IN/OUT.

; --------------------------- “variables” in SRAM ---------------------------
    .data

; We use a 16-bit delay_count so we can support up to 65535 ms (65.535 s).
; Alternatively you can define just one byte but the max delay would be 255 ms (0,255s).
delay_count:   .byte 2          ; 16-bit countdown for delay_ms

; --------------------------- Timer1 COMPA ISR (1 ms) ------------------------
    .text
TIMER1_COMPA_vect:
    ; Prologue: save the context of the registers we use + SREG (to re-enable I).
    push r16
    push r17
    in   r16, SREG_IO
    push r16

    ; Load delay_count from .data section and use or operation to check if it's zero.
    lds  r16, delay_count
    lds  r17, delay_count+1
    or   r16, r17
    breq 1f                     ; If zero, skip the decrement

    ; Decrement delay_count (16-bit)
    subi r16, 1                 ; LSB--
    sbci r17, 0                 ; borrow into MSB
    sts  delay_count,   r16
    sts  delay_count+1, r17
    
1:  ; Epilogue: restore flags + regs, then RETI (re-enables I)
    pop  r16                    ; Restore SREG, which re-enables interrupts
    out  SREG_IO, r16
    pop  r17                    ; Restore the caller's registers
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
    ; In CTC mode the counter is cleared to zero when the counter value (TCNT1) matches either the OCR1A (WGM1 bits 3:0 = 4) or the ICRn (WGM1 bits 3:0 = 12).
    ldi r16, 0
    sts TCCR1A, r16 ; We want to disable COMnX bits so we can use OCR1A for compare match only
    sts TCCR1C, r16 ; No forced compare

    ; TCCR1B: WGM12=1 (CTC), prescaler CS11|CS10 = /64
    ldi  r16, (1<<WGM12) | (1<<CS11) | (1<<CS10)
    sts  TCCR1B, r16

    ; OCR1A = 249 (0x00F9) → f_clk/(prescale * (1 + OCR1A)) = 1.000 Hz = 1 ms
    ; The value stored in OCR1A is the value to be compared with the counter value (TCNT1) when the WGM1 bits 3:0 = 4.
    ldi  r16, hi8(249)
    sts  OCR1AH, r16
    ldi  r16, lo8(249)
    sts  OCR1AL, r16

    ; Enable Timer1 Compare A interrupt (OCIE1A)
    ldi  r16, (1<<OCIE1A)
    sts  TIMSK1, r16

    ; Clear software counters
    ldi  r16, 0
    sts  delay_count,   r16
    sts  delay_count+1, r16

    sei                         ; set I-bit in SREG → IRQs enabled
    ret

; --------------------------- delay_ms(n) ------------------------------------
delay_ms:
    ; r24 and r25 represent an 16-bit integer that specifies the number of milliseconds
    ; The first check is on r24 because it's the lower byte and, if it's zero, then 
    tst  r24    
    brne 1f     ; If the low byte is non-zero, we can already proceed to store it
    tst  r25    
    breq 3f     

1:  ; Store n into shared countdown (ISR decrements every 1 ms)
    sts  delay_count,   r24
    sts  delay_count+1, r25

2:  ; The program will stay in this loop until the ISR decrements delay_count to 0
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
    ; Storing 250 in a 16-bit register pair
    ldi  r24, lo8(250)
    ldi  r25, hi8(250)
    rcall delay_ms

    cbi  LED_PORT_IO, LED_BIT   ; LED off
    ldi  r24, lo8(250)
    ldi  r25, hi8(250)
    rcall delay_ms

    rjmp blink_loop