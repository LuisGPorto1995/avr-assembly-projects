; =============================================================================
; AVR Assembly Projects — 28BYJ-48 + ULN2003 (ATmega2560, AVRA/AVRASM2 syntax)
; -----------------------------------------------------------------------------
; - Half-step (8-state) sequence outputs on PD3..PD0
; - Timer1 CTC at 1 kHz (1 ms tick); ISR only decrements delay_count
; - Busy-wait delay DELAY_MS(n) uses that 1 ms tick
; - In MAIN, one step = LED on + delay + LED off + delay (two delays per step)
; -----------------------------------------------------------------------------
; SPR FORMULA (use nominal or measured gear ratio):
; internal_steps_per_rev = 360° / rotor_stride_angle
; SPR_fullstep  ≈ internal_steps_per_rev * gear_ratio
; SPR_halfstep  ≈ internal_steps_per_rev * gear_ratio * 2
; Nominal:  internal_steps=32, gear_ratio=64  → SPR_halfstep=4096
; Measured: internal_steps=32, gear_ratio≈63.68395 → SPR_halfstep≈4076
; =============================================================================

.include "m2560def.inc"
.list

; ----------------------------- VECTORS ---------------------------------------
.cseg
.org 0x0000
    rjmp RESET
.org OC1Aaddr                         ; Timer1 Compare Match A vector
    rjmp TIM1_OC1A_ISR

; ----------------------------- Macros/Equates --------------------------------
.macro DelayMs
    ldi  r24, low(@0)
    ldi  r25, high(@0)
    rcall DELAY_MS
.endmacro

.equ    COIL_A          = 0         ; PD0
.equ    COIL_B          = 1         ; PD1
.equ    COIL_C          = 2         ; PD2
.equ    COIL_D          = 3         ; PD3

; Rotations per minute (change as you wish)
.equ    RPM             = 1
; The little motor inside is 32 full steps per motor rev (11.25° per step).
; The gear train is nominally 64:1, but many units measure at ≈ 63.68395:1
; SPR = 32*63.68395 ≈ 2038 (for 4-step, double it for the 8-step).
.equ    SPR             = 2038
; Steps per rotation (gear ratio is 63.68395:1, therefore SPR is 2038)
; One delay "slot" length in ms. (There are 2 delays per step.)
; For target RPM: DELAY_COUNT_MS ≈ (60000 / (SPR * RPM)) / 2
.equ    DELAY_COUNT_MS  = (60000 / (SPR * RPM)) / 2

; ----------------------------- SRAM (.dseg) ----------------------------------
.dseg
delay_count:    .byte 2             ; 16-bit countdown used by DELAY_MS()

; ----------------------------- FLASH (.cseg) ---------------------------------
.cseg
; 4-step two-phase (max torque, lower resolution).
; Energize two adjacent coils at a time.
steps:
    .db (1<<COIL_B)|(1<<COIL_C), \
        (1<<COIL_B)|(1<<COIL_D), \
        (1<<COIL_A)|(1<<COIL_C), \
        (1<<COIL_A)|(1<<COIL_D)

.equ PATTERN_COUNT = 4

; 8-step half-step (higher resolution, smoother, slightly less peak torque)
; Alternates 1-phase and 2-phase states to halve the step angle.
;steps:
;    .db (1<<COIL_A), \
;        (1<<COIL_A)|(1<<COIL_B), \
;        (1<<COIL_B), \
;        (1<<COIL_B)|(1<<COIL_C), \
;        (1<<COIL_C), \
;        (1<<COIL_C)|(1<<COIL_D), \
;        (1<<COIL_D), \
;        (1<<COIL_D)|(1<<COIL_A)
;
;.equ PATTERN_COUNT = 8

; LPM needs byte addresses (labels in .cseg are word-addressed → shift left by 1)
.equ STEPS_BEGIN = (steps << 1)
.equ STEPS_END   = (steps << 1) + PATTERN_COUNT

; =============================================================================
; RESET: clocks, GPIO, Timer1 1 kHz tick, counters
; =============================================================================
RESET:
    ; --- stack & ABI ---
    ldi     r16, high(RAMEND)
    out     SPH, r16
    ldi     r16, low(RAMEND)
    out     SPL, r16
    clr     r1                                      ; keep r1 = 0 (ABI)

    ; --- PB7 (board LED) as output, start LOW ---
    ldi     r16, (1<<PB7)
    out     DDRB, r16
    cbi     PORTB, PB7

    ; --- PD3..PD0 as outputs (to ULN2003 IN1..IN4) ---
    ldi     r16, (1<<PD0)|(1<<PD1)|(1<<PD2)|(1<<PD3)
    out     DDRD, r16
    out     PORTD, r16                              ; optional: pull-ups for other bits if inputs

    ; --- Timer1: CTC @ 1 kHz (1 ms) ---
    ldi     r16, 0
    sts     TCCR1A, r16
    sts     TCCR1C, r16
    ldi     r16, (1<<CS10)|(1<<CS11)|(1<<WGM12)     ; prescale /64, CTC (OCR1A)
    sts     TCCR1B, r16
    ldi     r16, high(249)                          ; 16 MHz / 64 / (249+1) = 1000 Hz
    sts     OCR1AH, r16
    ldi     r16, low(249)
    sts     OCR1AL, r16
    ldi     r16, (1<<OCIE1A)                        ; enable Compare A interrupt
    sts     TIMSK1, r16

    ; --- clear delay counter ---
    ldi     r16, 0
    sts     delay_count+0, r16
    sts     delay_count+1, r16

    sei
    rjmp    MAIN

; =============================================================================
; Timer1 Compare A ISR (fires every 1 ms)
; - ONLY decrements delay_count if non-zero (do not touch PORTs here)
; =============================================================================
TIM1_OC1A_ISR:
    ; prologue
    push    r0
    in      r0, SREG
    push    r0
    push    r16
    push    r17
    push    r18

    ; read 16-bit delay_count and test if zero
    lds     r16, delay_count+0
    lds     r17, delay_count+1
    mov     r18, r16
    or      r18, r17
    breq    count_zero

    ; decrement and store back
    subi    r16, 1
    sbci    r17, 0
    sts     delay_count+0, r16
    sts     delay_count+1, r17

count_zero:
    ; epilogue
    pop     r18
    pop     r17
    pop     r16
    pop     r0
    out     SREG, r0
    pop     r0
    reti

; =============================================================================
; Busy-wait delay in milliseconds using the 1 ms ISR
; r25:r24 = milliseconds (0..65535)
; =============================================================================
DELAY_MS:
    ; early-out if n == 0
    tst     r24
    brne    store
    tst     r25
    breq    return

store:
    ; atomically store 16-bit value
    cli
    sts     delay_count+0, r24
    sts     delay_count+1, r25
    sei

keep_loop:
    ; wait until ISR decrements to zero
    cli
    lds     r19, delay_count+0
    lds     r20, delay_count+1
    sei
    or      r19, r20
    brne    keep_loop

return:
    ret

; =============================================================================
; MAIN: read half-step pattern from FLASH and drive PD3..PD0 forever
; Each step = LED on + Delay + LED off + Delay  (two delays per step)
; =============================================================================
MAIN:
    ; Z → start of table, r18:r19 hold end address for wrap
    ldi     ZL, low(STEPS_BEGIN)
    ldi     ZH, high(STEPS_BEGIN)
    ldi     r18, low(STEPS_END)
    ldi     r19, high(STEPS_END)

step_loop:
    ; --- LED ON ---
    sbi     PORTB, PB7

    ; --- fetch next half-step pattern and output on PD3..PD0 only ---
    lpm     r16, Z+                             ; r16 = 1,3,2,6,4,12,8,9 ...
    in      r17, PORTD
    andi    r17, 0xF0                           ; keep PD7..PD4
    or      r17, r16                            ; apply pattern to PD3..PD0
    out     PORTD, r17

    ; --- two-part step delay (on-time then off-time) ---
    DelayMs DELAY_COUNT_MS
    cbi     PORTB, PB7
    DelayMs DELAY_COUNT_MS

    ; --- wrap Z to table start when end is reached ---
    cp      ZL, r18
    cpc     ZH, r19
    brne    step_loop
    ldi     ZL, low(STEPS_BEGIN)
    ldi     ZH, high(STEPS_BEGIN)
    rjmp    step_loop
