# AVR Assembly Projects

---

## Delay ms function

The first project is focused on creating a function that will be usefull for other projects.
The easy way to create a delay would be to just execute a set ammount of instructions that do nothing, taking into account the speed of each clock cycle.
For ATmega2560 development board (Arduino Mega), the cristal has a frequency of 16MHz, and, with the RICS architecture, we assume
that most instructions take one clock cycle instead of the typical 4 cycles.
That way, assuming that each instruction takes around 62,5ns to be executed, we can reach 1ms delay if we execute 16.000 instructions. However, that is obviously very ineficient. The best way to create a delay, is with Timer/Counters

### Timer/Counters

ATmega2560 has 2 types of T/C: those with 8-bit resolution(T/C 0 and 2) and those with 16-bit resolution (T/C 1, 3, 4 and 5).
The 0, 1, 3, 4 and 5 T/C share the same prescaler module, but they can have diffrent prescaler settings.
One of four taps from the prescaler can be used as a clock source. The prescaled clock has a fre-
quency of either fCLK_I/O/8, fCLK_I/O/64, fCLK_I/O/256, or fCLK_I/O/1024.

This is fundamental, since the 16MHz clock is too quick for a delay in microsseconds. With a prescale equal to 1024, the clock source is now 15,625kHz (0,064ms to increase the Timer Counter).
If we use the Output Compare Register A (16-bit) and set it to decimal 16, then the 16-bit comparator continuously compares TCNTn with the Output Compare Register (OCRnx).
If TCNT equals OCRnx the comparator signals a match. A match will set the Output Compare Flag (OCFnx) at the next timer clock
cycle. If enabled (OCIEnx = 1), the Output Compare Flag generates an Output Compare interrupt. The OCFnx Flag is automatically cleared when the interrupt is executed.

This interrupt will be used to jump the routine back to where it left before the delay was called. Alternativelly, we can also define a label (named DELAY) with multiples of 16 as its value to set how many millisseconds would you like the delay to wait.