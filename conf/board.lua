-- board specific stuff, mostly wiring and device addresses
brd_led_inv=1      -- led inverted (connected to vcc)
brd_led=PIN_GP2    gpio.mode(brd_led, gpio.OUTPUT) gpio.write(brd_led, brd_led_inv)
brd_sda=PIN_GP4    gpio.mode(brd_sda, gpio.OUTPUT) gpio.write(brd_sda, 0)
brd_scl=PIN_GP5    gpio.mode(brd_scl, gpio.OUTPUT) gpio.write(brd_scl, 0)
brd_dht=PIN_GP0
brd_btn1=PIN_GP2   gpio.mode(brd_btn1, gpio.INPUT, gpio.PULLUP)

--brd_pwm=PIN_GP14   gpio.mode(brd_pwm, gpio.OUTPUT) gpio.write(brd_pwm, 0)
--brd_btn2=PIN_GP13  gpio.mode(brd_btn2, gpio.INPUT, gpio.PULLUP)

-- OLED display
brd_oled_addr=0x3c
brd_oled_d="ssd1306_i2c_128x64_noname"
brd_oled_w=128
brd_oled_h=64
brd_oled_r=1

-- measured ADC settings for ~0..5V input
brd_adc_a=4.869
brd_adc_b=-39.0
