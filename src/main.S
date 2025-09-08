; AVR Assembly Projects - Basic Template
; This includes the necessary definitions for an AVR microcontroller.
#include <avr/io.h>

    .global main

main:
    ; The basic setup for an AVR microcontroller    

loop:
    ; The equivalent of while(1) in C
    rjmp  loop