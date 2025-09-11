# AVR Assembly Projects

---

## Delay ms function

The first project is focused on creating a function that will be usefull for other projects.
The easy way to create a delay would be to just execute a set ammount of instructions that do nothing, taking into account the speed of each clock cycle.

For ATmega2560 development board (Arduino Mega), the cristal has a frequency of 16MHz, and, with the RICS architecture, we assume
that most instructions take one clock cycle instead of the typical 4 cycles.

That way, assuming that each instruction takes around 62,5ns to be executed, we can reach 1ms delay if we execute 16.000 instructions. However, that is obviously very ineficient. The best way to create a delay, is with Timer/Counters (T/Cs).

### Timer/Counters

ATmega2560 has 2 types of T/Cs: those with 8-bit resolution(T/C 0 and 2) and those with 16-bit resolution (T/Cs 1, 3, 4 and 5).
The 0, 1, 3, 4 and 5 T/C share the same prescaler module, but they can have diffrent prescaler settings. One of four taps from the prescaler can be used as a clock source. The prescaled clock has a frequency of either f_clk/8, f_clk/64, f_clk/256, or f_clk/1024. This is fundamental, since the 16MHz clock is too quick for a delay in milliseconds.

T/Cs 1, 3, 4 and 5 have 5 different modes of operation: Normal. Clear Timer on Compare Match (CTC), Fast PWM Mode, Phase Correct PWM Mode and Phase and Frequency Correct PWM Mode. The one we want is the CTC mode because, onde we stablished the frequency of the timer/counter, we can adjust the OCRnX to create 1ms cycle for the counter.

The user may get confused when reading the datasheet, because the CTC mode (where OCRnX Register is used to manipulate the counter
resolution) is commonly used for waveform generation, not to create a delay. That means the timer must count up to OCRnA and reset 2 times to determine the frequency of the waveform (f_OCnA = f_clk/2). This relation is then used to determine the formula for the f_OC1X = f_clk/(2*N*(1+OCRnX)).

However, like previously stated, that formula is used to calculate the frequency of the generated waveform (which takes 2 counter cycles to complete). Since we will count each cycle, then the correct formula to use is just f_OCnX = f_clk/(N*(1+OCRnX)).

If TCNTn equals OCRnX the comparator signals a match. A match will set the Output Compare Flag (OCFnX) at the next timer clock
cycle. If enabled (OCIEnX = 1), the Output Compare Flag generates an Output Compare interrupt. The OCFnX Flag is automatically cleared when the interrupt is executed.

### The algorithm

#### Initial configuration

*LED Configuration*

First, in order to see the actual delay happening, the L LED in the board is used. For that, we need to configure the I/O port for it, located in the Port B. So, we need to configure the data direction register as output for bit 7 (where the LED is connected):

**DDRB:**

| Bit | 7 (DDB7) | 6 (DDB6) | 5 (DDB5) | 4 (DDB4) | 3 (DDB3) | 2 (DDB2) | 1 (DDB1) | 0 (DDB0) |
|-----|----------|----------|----------|----------|----------|----------|----------|----------|
| Val |    1     |    0     |    0     |    0     |    0     |    0     |    0     |    0     |

*Timer Configuration*

As previously stated, the CTC can also be used to create a delay function by counting how many times the the Timer counter register is equal to the output compare register, which is how many times 1ms has passed.

Using T/C 1, the control registers A, B and C need to be configured as follows:

TCCR1A:

     7        6        5        4        3        2        1        0
-------------------------------------------------------------------------
| COM1A1 | COM1A0 | COM1B1 | COM1B0 | COM1C1 | COM1C0 | WGM11  | WGM10  |
-------------------------------------------------------------------------
|    0   |    0   |    0   |    0   |    0   |    0   |    0   |    0   |
-------------------------------------------------------------------------

The output compare pins don't need to be used, but the first 2 bits of the WGM need to be 0.

TCCR1B:

     7        6        5        4        3        2        1        0
-------------------------------------------------------------------------
| ICNC1  | ICES1  |    -   | WGM11  | WGM12  |  CS12  |  CS11  |  CS10  |
-------------------------------------------------------------------------
|    0   |    0   |    -   |    0   |    1   |    0   |    1   |    1   |
-------------------------------------------------------------------------

The input capture noice canceler and input capture edge select functionalities don't need to be used. WGM10:3 = 4 sets the OCR1A register to be used for counter resolution, not ICR1, and CS1:3 = 3 uses a 64 prescale.

TCCR1B:

     7        6        5        4        3        2        1        0
-------------------------------------------------------------------------
| FOC1A  | FOC1B  | FOC1C  |    -   |    -   |    -   |    -   |    -   |
-------------------------------------------------------------------------
|    0   |    0   |    0   |    -   |    -   |    -   |    -   |    -   |
-------------------------------------------------------------------------

There is no need to force the output compare in the code, so those bits can be set to zero

As for the OCR1A, the decimal value 249 is stored in the 16-bit register. Notice that this register uses 2 8-bit registers (hence OCR1AH and OCR1AL). By following the previously presented formula, we get that the frequency in which the output compare matches is f_OC1A = 16.000.000/(64*(1+249)) = 1.000Hz => T_OC1A = 1ms

We also need to enable the interrupt for the output compare A match by setting OCIEnA bit to 1 in the TIMSK1 register:

TIMSK1:

     7        6        5        4        3        2        1        0
-------------------------------------------------------------------------
|    -   |    -   |  ICIE1 |    -   | OCIE1C | OCIE1B | OCIE1A |  TOIE1 |
-------------------------------------------------------------------------
|    -   |    -   |    0   |    -   |    0   |    0   |    1   |    0   |
-------------------------------------------------------------------------

*Status Register*

The interrupt setup in the timer will be useless unless we set bit 7 (I) in the status register (SREG). This bit sets the global interruptions.

SREG:

     7        6        5        4        3        2        1        0
-------------------------------------------------------------------------
|    I   |    T   |    H   |    S   |    V   |    N   |    Z   |    C   |
-------------------------------------------------------------------------
|    1   |    x   |    x   |    x   |    x   |    x   |    x   |    x   |
-------------------------------------------------------------------------

#### Blink loop and delay ms functions

General-purpose registers 24 and 25 are used to store a 16-bit decimal value. For the purposes of this project, the LED will toggle each 250ms, so we stored this value on those registers, then we call the actual delay function (delay_ms).

The delay function will check to see if the value is higher than 0 by performint an AND operation on the lower half register (r24) (which will always result on 1, unless all the bits in the register are 0s). If the lower half is zero, then this operation will set the Z bit in the status register. When that happens, we do the same check on the higher half of the value (r25) and, if that is also zero, we can skip the rest of the function and go back to the blink loop. Essentially, that will only take a couple of hundreds of nanoseconds, so basically no delay when the amount of milliseconds is set to 0.

When the value is higher than zero, the value is stored in an previously allocated space defined in the .data section (called delay cound), which will be used to cound the amount of milliseconds. After that, the delay function will stay in polling mode, checking to see if the delay count is equal to zero. When it is, it goes back to the blink loop routine. This delay count is decresed by one each time the interrupt is called.

#### Timer/Counter output compare interrupt routine

The interrupt needs to be as quick as possible to not add any further delay due to the time it takes to complete an instruction. Basically, what the routine does is, at first, save the state of the registers we were using and the status register. After that, we load the value stored in the delay count (which was stored when the ), decrease it by one, and store it back. If the delay count is already zero, then we can just skip to the end of the interruption service routine, but not before restoring the status register back to the previous value (which sets the interrupt bit, since the hardware clears that bit anytime an interrupt occurs).
