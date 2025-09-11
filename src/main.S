;---------------------------------------------------------------------------------------
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
;---------------------------------------------------------------------------------------

#include <avr/io.h>

.global main
.global TIMER1_COMPA_vect
;---------------------------------------------------------------------------------------
; --------------------------- Macros ---------------------------------------------------
.macro DelayMs value
    ldi  r24, lo8(\value)
    ldi  r25, hi8(\value)
    rcall delay_ms
.endm
;---------------------------------------------------------------------------------------
; --------------------------- Definitions ----------------------------------------------
; On Arduino Mega, the "L" LED is on PB7 (Arduino D13).
.equ    LED_DDR_IO , (DDRB-0x20)   ; I/O-space address for OUT.
.equ    LED_PORT_IO, (PORTB-0x20)  ; I/O-space address for SBI/CBI.
.equ    LED_BIT    , 7
.equ    SREG_IO    , (SREG-0x20)   ; I/O-space address for IN/OUT.
.equ    DELAY_MS   , 1000          ; Delay in milliseconds.
;---------------------------------------------------------------------------------------
; --------------------------- “variables” in SRAM --------------------------------------
.data

; We use a 16-bit delay_count so we can support up to 65535 ms (65.535 s).
; Alternatively you can define just one byte but the max delay would be 255 ms (0,255s).
delay_count:    .byte 2
;---------------------------------------------------------------------------------------
; --------------------------- Code section ---------------------------------------------
.text
;---------------------------------------------------------------------------------------
; --------------------------- Timer1 COMPA ISR (1 ms) ----------------------------------
TIMER1_COMPA_vect:
    ; We need to save the context of the registers we use in the ISR even if we don't
    ; use them in the main code. This is a good practice, specially for the SREG.
    in      r0, SREG_IO
    push    r0
    push    r20
    push    r21
    push    r22

    ; Load delay_count from .data section and use or operation to check if it's zero.
    lds     r20, delay_count
    lds     r21, delay_count+1
    ; Don't do the or operation using r20 and r21 directly.
    ; The result would be stored in r20, modifying its value.
    mov     r22, r20
    or      r22, r21
    ; If zero, skip decrement
    breq    1f 

    ; Decrement delay_count (16-bit)
    subi    r20, 1
    sbci    r21, 0
    sts     delay_count,   r20
    sts     delay_count+1, r21
    
1:  ; Restore context
    pop     r22
    pop     r21
    pop     r20
    out     SREG_IO, r0
    pop     r0
    reti
;---------------------------------------------------------------------------------------
; --------------------------- init: GPIO + Timer1 + IRQs -------------------------------
init:
    ; --- LED pin set as output ---
    ldi     r16, (1<<LED_BIT)
    out     LED_DDR_IO, r16

    ; --- Timer1 in CTC mode, 1 ms period ---
    ; TCCR1A: WGM11=0, WGM10=0 (CTC mode)
    ; We want to disable COMnX bits so we can use OCR1A for compare match only
    ldi     r16, 0
    sts     TCCR1A, r16

    ; TCCR1C: FOC1A=0, FOC1B=0 (no forced compare)
    sts     TCCR1C, r16

    ; TCCR1B: WGM12=1 (CTC usinng OCRnX, not ICRn).
    ; Prescale = /64 → CS12=0, CS11=1, CS10=1
    ldi     r16, (1<<WGM12) | (1<<CS11) | (1<<CS10)
    sts     TCCR1B, r16

    ; OCR1A = 249 (0x00F9) → f_clk/(prescale * (1 + OCR1A)) = 1.000 Hz = 1 ms
    ldi     r16, hi8(249)
    sts     OCR1AH, r16
    ldi     r16, lo8(249)
    sts     OCR1AL, r16

    ; Enable Timer1 Compare A interrupt (OCIE1A)
    ldi     r16, (1<<OCIE1A)
    sts     TIMSK1, r16

    ; Clear software counters
    ldi     r16, 0
    sts     delay_count,   r16
    sts     delay_count+1, r16

    ; set I-bit in SREG → IRQs enabled
    sei
    ret

;---------------------------------------------------------------------------------------
; --------------------------- delay_ms(n) ----------------------------------------------
delay_ms:
    ; Check to see if the input n (in r25:r24) is zero.
    tst     r24
    ; If the low byte is non-zero, we can already proceed to store it
    brne    1f
    tst     r25
    breq    3f

1:  ; Store n into the storage variable delay_count (16-bit)
    cli
    sts     delay_count,   r24
    sts     delay_count+1, r25
    sei

2:  ; The program will stay in this loop until the ISR decrements delay_count to 0
    cli
    lds     r18, delay_count
    lds     r19, delay_count+1
    sei
    or      r18, r19
    brne    2b

3:  ret

;---------------------------------------------------------------------------------------
; --------------------------- main -----------------------------------------------------
main:
    rcall init

;---------------------------------------------------------------------------------------
; --------------------------- Blink LED loop -------------------------------------------
blink_loop:

    ; LED on
    sbi     LED_PORT_IO, LED_BIT
    DelayMs(DELAY_MS)

    ; LED off
    cbi     LED_PORT_IO, LED_BIT
    DelayMs(DELAY_MS)

    rjmp    blink_loop