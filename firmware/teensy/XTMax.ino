//
//
//  File Name   :  XTMax.ino
//  Used on     : 
//  Authors     :  Ted Fried, MicroCore Labs
//                 Matthieu Bucchianeri
//  Creation    :  9/7/2024
//
//   Description:
//   ============
//   
//  Multi-function 8-bit ISA card using a Teensy 4.1.
//
//------------------------------------------------------------------------
//
// Modification History:
// =====================
//
// Revision 1 9/7/2024
// Initial revision
//
// Revision 2 10/5/2024
// Added support for SD to Parallel interface
//
// Revision 3 10/11/2024
// Added variable wait states for Expanded RAM
//  - For 4.77 Mhz, can be changed to zero wait states for Write cycles and two for Read cycles
//
// Revision 4 11/11/2024
// - Updated MicroSD support and conventional memory to 640 KB
//
// Revision 5 11/26/2024
// - XTMax automatically configured addition to conventional memory to 640 KB
//
// Revision 6 12/14/2024
// - Made SD LPT base a # define
//
// Revision 7 01/12/2025
// - Refactor SD card I/O
// - Add support for 16-bit EMS page offsets
//
// Revision 8 01/20/2025
// - Added chip select for a second PSRAM to allow access to 16 MB of Expanded RAM
//
// Revision 9 01/26/2025
// - Add support for BIOS ROM extension (Boot ROM)
// - Add scrach registers for Boot ROM hooking
//
// Revision 10 02/17/2025
// - Use a lookup table for the memory map
//
// Revision 11 03/01/2025
// - Refactor lookup table and add support for UMBs
//
// Revision 12 03/30/2026
// - IBM 5155 / 640KB planar: optional conventional memmap off, timing #defines,
//   DontRespond read GPIO, EMS window guard, documentation
//
// Revision 13 03/30/2026
// - Default XTMAX_DISABLE_CONVENTIONAL_RAM_MAP=1 so POST finds full motherboard RAM (640K)
//
// Revision 14 03/30/2026
// - Faster SD SPI, tighter IO/mux delays, shorter PSRAM reset delay, early CHRDY on PSRAM EMS
//
// Revision 15 03/30/2026
// - XTMAX_DISABLE_BOOTROM_MAP: skip option ROM + SD MMIO decode (blank screen after RAM test workaround)
//
// Revision 16 03/30/2026
// - Default XTMAX_DISABLE_BOOTROM_MAP=1 (option ROM was still on unless user edited)
// - Optional XTMAX_SKIP_PSRAM_INIT for boards without PSRAM / EMS
//
//------------------------------------------------------------------------
//
// Copyright (c) 2024 Ted Fried
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//------------------------------------------------------------------------
                                                 


#include <stdint.h>
#include <stdio.h>

#include "bootrom.h"
#include "xtmax_core.h"


// Teensy 4.1 pin assignments
//
#define PIN_BCLK            34     
#define PIN_BALE            5
#define PIN_AEN             29     
#define PIN_CHRDY_OE_n      28
#define PIN_CHRDY_OUT       6
#define PIN_REFRESH         32     
#define PIN_MEMWR_n         33 
#define PIN_MEMRD_n         4
#define PIN_IOWR_n          3
#define PIN_IORD_n          2
   
#define PIN_MUX_DATA_n      31     
#define PIN_DATA_OE_n       30     
#define PIN_MUX_ADDR_n      9
#define PIN_TRIG_OUT        35
 
#define PIN_ADDR19          27
#define PIN_ADDR18          26
#define PIN_ADDR17          39
#define PIN_ADDR16          38
#define PIN_ADDR15          21
#define PIN_ADDR14          20
#define PIN_ADDR13          23
#define PIN_ADDR12          22
#define PIN_ADDR11          16
#define PIN_ADDR10          17
#define PIN_ADDR9           41
#define PIN_ADDR8           40
#define PIN_AD7             15
#define PIN_AD6             14
#define PIN_AD5             18
#define PIN_AD4             19
#define PIN_AD3             25
#define PIN_AD2             24
#define PIN_AD1             0
#define PIN_AD0             1

#define PIN_DOUT7           37
#define PIN_DOUT6           36
#define PIN_DOUT5           7
#define PIN_DOUT4           8
#define PIN_DOUT3           13
#define PIN_DOUT2           11  // temp spi_mosi
#define PIN_DOUT1           12  // temp spi_cs
#define PIN_DOUT0           10  // temp spi clk

#define PIN_PSRAM_D3        54    // GPIO9-29
#define PIN_PSRAM_D2        50    // GPIO9-28
#define PIN_PSRAM_D1        49    // GPIO9-27
#define PIN_PSRAM_D0        52    // GPIO9-26
#define PIN_PSRAM_CLK       53    // GPIO9-25
#define PIN_PSRAM_CS_n      48    // GPIO9-24
#define PIN_PSRAM_CS1_n     51    // GPIO9-22

#define PIN_SD_CS_n         46    // GPIO8-17
#define PIN_SD_MOSI         45    // GPIO8-12
#define PIN_SD_CLK          44    // GPIO8-13
#define PIN_SD_MISO         43    // GPIO8-14



#define ADDRESS_DATA_GPIO6_UNSCRAMBLE   ( ((gpio6_int&0xFFFF0000)>>12) | ((gpio6_int&0x3000)>>10) | ((gpio6_int&0xC)>>2) )

#define GPIO7_DATA_OUT_UNSCRAMBLE        ( ( (isa_data_out&0xF0)<<12) | (isa_data_out&0x0F) )


#define DATA_OE_n_LOW      0x0
#define DATA_OE_n_HIGH     0x00800000
 
#define TRIG_OUT_LOW       0x0
#define TRIG_OUT_HIGH      0x10000000
                           
#define MUX_DATA_n_LOW     0x0
#define MUX_DATA_n_HIGH    0x00400000
                           
#define CHRDY_OUT_LOW      0x0
#define CHRDY_OUT_HIGH     0x00000400
                           
#define CHRDY_OE_n_LOW     0x0
#define CHRDY_OE_n_HIGH    0x00040000
                           
#define MUX_ADDR_n_LOW     0x0
#define MUX_ADDR_n_HIGH    0x00000800

#define PSRAM_RESET_VALUE  0x01400000
#define PSRAM_CLK_HIGH     0x02000000

#define MMAN_BASE          0x260   // Must be a multiple of 16.
#define EMS_MAX_SIZE       (16*1024*1024)

#define SD_BASE            0x280    // Must be a multiple of 8.
#define SD_CONFIG_BYTE     0

// Set to 1 so XTMax does NOT decode 0x00000-0x9FFFF (motherboard RAM owns POST + DOS conventional).
// Default 1: avoids POST/memory-count errors (e.g. 192K/256K instead of 640K) when XTMax would otherwise
// respond during the BIOS RAM test. Set to 0 only if XTMax must emulate conventional RAM (holes / no planar RAM).
#ifndef XTMAX_DISABLE_CONVENTIONAL_RAM_MAP
#define XTMAX_DISABLE_CONVENTIONAL_RAM_MAP 1
#endif

// ISA timing for 4.77 MHz class machines; increase delays if autodetect/EMS/SD are unstable.
#define AUTODETECT_READ_DELAY_NS  800
#define IO_WRITE_SETTLE_NS        32
#define MUX_DATA_SWITCH_NS        6
#define SD_SPI_BIT_TIME_NS        4
#define PSRAM_EDGE_DELAY_NS       1
#ifndef PSRAM_CONFIGURE_DELAY_US
#define PSRAM_CONFIGURE_DELAY_US  120
#endif
// Set 0 if EMS/PSRAM reads fail on your ISA bus (restores long CHRDY hold during PSRAM quad read/write).
#ifndef XTMAX_PSRAM_EARLY_CHRDY
#define XTMAX_PSRAM_EARLY_CHRDY  1
#endif
// Set 1 to NOT map bootrom.h at BOOTROM_ADDR or the SD register page in memmap. Use if the BIOS hangs or the
// screen goes blank right after the RAM test: the option ROM still runs SD/init code even with no card inserted.
// When set, use XTSD.SYS from floppy for SD and skip ROM-based boot until you fix SD or ROM behavior.
#ifndef XTMAX_DISABLE_BOOTROM_MAP
#define XTMAX_DISABLE_BOOTROM_MAP  0
#endif
// Set 1 to skip PSRAM quad-mode init at boot (faster; use if no PSRAM chip or EMS-only issues).
#ifndef XTMAX_SKIP_PSRAM_INIT
#define XTMAX_SKIP_PSRAM_INIT  0
#endif

    
// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

uint32_t  trigger_out = 0;
uint32_t  gpio6_int = 0;
uint32_t  gpio9_int = 0;
uint32_t  isa_address = 0;
uint32_t  psram_address = 0;
uint32_t  sd_pin_outputs = 0;
uint32_t  databit_out = 0;

uint8_t   data_in = 0;
uint8_t   isa_data_out = 0;
uint8_t   nibble_in =0;
uint8_t   nibble_out =0;
uint8_t   read_byte =0;
uint8_t   spi_shift_out =0;
uint8_t   sd_spi_datain =0;
uint32_t  sd_spi_cs_n = 0x0;
uint32_t  sd_spi_dataout =0;
uint8_t   sd_scratch_register[6] = {0, 0, 0, 0, 0, 0};
uint16_t  sd_requested_timeout = 0;
elapsedMillis sd_timeout;

DMAMEM  uint8_t  internal_RAM1[0x7A000];  /*   0 - 488KB */
        uint8_t  internal_RAM2[0x76000];  /* 488 - 640KB + 320KB UMB */

uint8_t psram_cs =0;

XtmaxState xtmax;
MemResponse (&XTMax_MEM_Response_Array)[16] = xtmax.mem_response;

// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

// Setup Teensy 4.1 IO's
//
void setup() {
 
  pinMode(PIN_BCLK,           INPUT);   
  pinMode(PIN_BALE,           INPUT);
  pinMode(PIN_AEN,            INPUT);   
  pinMode(PIN_CHRDY_OE_n,     OUTPUT);
  pinMode(PIN_CHRDY_OUT,      OUTPUT);
  pinMode(PIN_REFRESH,        INPUT);   
  pinMode(PIN_MEMWR_n,        INPUT);
  pinMode(PIN_MEMRD_n,        INPUT);
  pinMode(PIN_IOWR_n,         INPUT);
  pinMode(PIN_IORD_n,         INPUT);
 
  pinMode(PIN_MUX_DATA_n,     OUTPUT);   
  pinMode(PIN_DATA_OE_n,      OUTPUT);   
  pinMode(PIN_MUX_ADDR_n,     OUTPUT);
  pinMode(PIN_TRIG_OUT,       OUTPUT);
 
  pinMode(PIN_ADDR19,         INPUT);
  pinMode(PIN_ADDR18,         INPUT);
  pinMode(PIN_ADDR17,         INPUT);
  pinMode(PIN_ADDR16,         INPUT);
  pinMode(PIN_ADDR15,         INPUT);
  pinMode(PIN_ADDR14,         INPUT);
  pinMode(PIN_ADDR13,         INPUT);
  pinMode(PIN_ADDR12,         INPUT);
  pinMode(PIN_ADDR11,         INPUT);
  pinMode(PIN_ADDR10,         INPUT);
  pinMode(PIN_ADDR9,          INPUT);
  pinMode(PIN_ADDR8,          INPUT);
  pinMode(PIN_AD7,            INPUT);
  pinMode(PIN_AD6,            INPUT);
  pinMode(PIN_AD5,            INPUT);
  pinMode(PIN_AD4,            INPUT);
  pinMode(PIN_AD3,            INPUT);
  pinMode(PIN_AD2,            INPUT);
  pinMode(PIN_AD1,            INPUT);
  pinMode(PIN_AD0,            INPUT);
 
  pinMode(PIN_DOUT7,          OUTPUT);
  pinMode(PIN_DOUT6,          OUTPUT);
  pinMode(PIN_DOUT5,          OUTPUT);
  pinMode(PIN_DOUT4,          OUTPUT);
  pinMode(PIN_DOUT3,          OUTPUT);
  pinMode(PIN_DOUT2,          OUTPUT);
  pinMode(PIN_DOUT1,          OUTPUT);
  pinMode(PIN_DOUT0,          OUTPUT);
 
  pinMode(PIN_PSRAM_CLK,      OUTPUT);                   
  pinMode(PIN_PSRAM_CS_n,     OUTPUT);                   
  pinMode(PIN_PSRAM_CS1_n,    OUTPUT);                   
  pinMode(PIN_PSRAM_D3,       INPUT);                   
  pinMode(PIN_PSRAM_D2,       INPUT);
  pinMode(PIN_PSRAM_D1,       INPUT);
  pinMode(PIN_PSRAM_D0,       OUTPUT);
 
 
  pinMode(PIN_SD_CLK,         OUTPUT);
  pinMode(PIN_SD_CS_n,        OUTPUT);
  pinMode(PIN_SD_MOSI,        OUTPUT);
  pinMode(PIN_SD_MISO,        INPUT_PULLUP);


  GPIO9_DR = PSRAM_RESET_VALUE;  // Set CLK=0, CSx_n=1, DATA=0
 
  digitalWriteFast(PIN_CHRDY_OE_n,   0x1);
  digitalWriteFast(PIN_CHRDY_OUT,    0x0);
 
  digitalWriteFast(PIN_DATA_OE_n,    0x1);
  digitalWriteFast(PIN_MUX_ADDR_n,   0x0);
  digitalWriteFast(PIN_MUX_DATA_n,   0x1);
  digitalWriteFast(PIN_TRIG_OUT,     0x1);
 

  //noInterrupts();                                   // Disable Teensy interupts
 
  //Serial.begin(9600);

  // Patch the memory map (optional ROM + SD MMIO at end of ROM window).
  static_assert((BOOTROM_ADDR & 0x7FF) == 0);
  static_assert((sizeof(BOOTROM) % 2048) == 0, "BootROM must be in blocks of 2KB");
  XTMax_InitState(&xtmax,
                  XTMAX_DISABLE_CONVENTIONAL_RAM_MAP,
                  XTMAX_DISABLE_BOOTROM_MAP,
                  BOOTROM_ADDR,
                  sizeof(BOOTROM));
}


// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void SD_SPI_TXRXBit()  {
   
    // Drive CLK low and MOSI
    //
    GPIO7_DR = GPIO7_DR & 0xE0000000;  // Trigger out
    sd_pin_outputs = (sd_spi_cs_n<<17) | (0x0<<13) | databit_out;                      // SD_CS_n - SD_CLK - SD_MOSI
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_LOW + DATA_OE_n_HIGH;
    delayNanoseconds(SD_SPI_BIT_TIME_NS);
   
    // Drive CLK high
    //
    GPIO7_DR = GPIO7_DR | 0x10000000;  // Trigger out
    sd_pin_outputs = (sd_spi_cs_n<<17) | (0x1<<13) | databit_out;                      // SD_CS_n - SD_CLK - SD_MOSI
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_LOW + DATA_OE_n_HIGH;
    delayNanoseconds(SD_SPI_BIT_TIME_NS);
    sd_spi_datain = sd_spi_datain << 1;
    if ((GPIO8_DR&0x00004000)!=0) {sd_spi_datain = sd_spi_datain | 0x01; }             // Shift in MISO data

    // Drive CLK and MOSI low
    //
    sd_pin_outputs = (sd_spi_cs_n<<17) | (0x0<<13) | 0x0;                              // SD_CS_n - SD_CLK - SD_MOSI
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_LOW + DATA_OE_n_HIGH;
   
    return;
}

// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void SD_SPI_Cycle()  {
   
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_LOW + DATA_OE_n_HIGH ;  // Assert CHRDY_n=0 to begin wait states

    databit_out = ((sd_spi_dataout&0x80)<<5 );  SD_SPI_TXRXBit();  // Bit 7
    databit_out = ((sd_spi_dataout&0x40)<<6 );  SD_SPI_TXRXBit();  // Bit 6
    databit_out = ((sd_spi_dataout&0x20)<<7 );  SD_SPI_TXRXBit();  // Bit 5
    databit_out = ((sd_spi_dataout&0x10)<<8 );  SD_SPI_TXRXBit();  // Bit 4
    databit_out = ((sd_spi_dataout&0x08)<<9 );  SD_SPI_TXRXBit();  // Bit 3
    databit_out = ((sd_spi_dataout&0x04)<<10);  SD_SPI_TXRXBit();  // Bit 2
    databit_out = ((sd_spi_dataout&0x02)<<11);  SD_SPI_TXRXBit();  // Bit 1
    databit_out = ((sd_spi_dataout&0x01)<<12);  SD_SPI_TXRXBit();  // Bit 0

    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;  // De-assert CHRDY


  return;
}

// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void PSRAM_Write_Clk_Cycle() {
    
       if (psram_cs==7) GPIO9_DR = ((nibble_out&0xF) << 26) | 0x00000000;      // Drive nibble data , CLK=0 , CSx_n=0
  else if (psram_cs==0) GPIO9_DR = ((nibble_out&0xF) << 26) | 0x00400000;      // Drive nibble data , CLK=0 , CS_n=0
  else                  GPIO9_DR = ((nibble_out&0xF) << 26) | 0x01000000;      // Drive nibble data , CLK=0 , CS1_n=0
    
  delayNanoseconds(PSRAM_EDGE_DELAY_NS);
  GPIO9_DR = GPIO9_DR | PSRAM_CLK_HIGH;    // Drive nibble data and CLK=1
  delayNanoseconds(PSRAM_EDGE_DELAY_NS);
 
  return;
}

// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void PSRAM_Read_Clk_Cycle() {
 
       if (psram_cs==7) GPIO9_DR = 0x00000000;      // Drive CLK=0 , CSx_n=0
  else if (psram_cs==0) GPIO9_DR = 0x00400000;      // Drive CLK=0 , CS_n=0
  else                  GPIO9_DR = 0x01000000;      // Drive CLK=0 , CS1_n=0
    
  delayNanoseconds(PSRAM_EDGE_DELAY_NS);
  GPIO9_DR = GPIO9_DR | PSRAM_CLK_HIGH;             // Drive  CLK=1
  delayNanoseconds(PSRAM_EDGE_DELAY_NS);
  nibble_in = (GPIO9_DR>>26) & 0xF;                 // Sample nibble data 
 
  return;
}


// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void PSRAM_Configure() {

  delayMicroseconds(PSRAM_CONFIGURE_DELAY_US);

  psram_cs=7;

  nibble_out = 0x0;    PSRAM_Write_Clk_Cycle();     // Set PSRAM to Quad Mode 0x35
  nibble_out = 0x0;    PSRAM_Write_Clk_Cycle(); 
  nibble_out = 0x1;    PSRAM_Write_Clk_Cycle(); 
  nibble_out = 0x1;    PSRAM_Write_Clk_Cycle(); 
 
  nibble_out = 0x0;    PSRAM_Write_Clk_Cycle(); 
  nibble_out = 0x1;    PSRAM_Write_Clk_Cycle(); 
  nibble_out = 0x0;    PSRAM_Write_Clk_Cycle(); 
  nibble_out = 0x1;    PSRAM_Write_Clk_Cycle(); 
 
  GPIO9_DR = PSRAM_RESET_VALUE;                     // Drive  CLK=0 , CS_n=1

 
  GPIO9_GDIR = 0x3F400000;                          // Change Data[3:0] to outputs quickly

 
  return;
}

// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline uint8_t PSRAM_Read(uint32_t address_in) {
    
  if (address_in >= EMS_MAX_SIZE) {
      return 0xff;
  }  
  if (address_in >= 0x7FFFFF)  psram_cs=1; else psram_cs=0;  

  // Send Command = Quad Read = 0x0B
  //
  nibble_out = 0x0;    PSRAM_Write_Clk_Cycle(); 
  nibble_out = 0xB;    PSRAM_Write_Clk_Cycle(); 


  // Send 24-bit address in six clock cycles
  //
  nibble_out = address_in >> 20;   PSRAM_Write_Clk_Cycle();
  nibble_out = address_in >> 16;   PSRAM_Write_Clk_Cycle();
  nibble_out = address_in >> 12;   PSRAM_Write_Clk_Cycle();
  nibble_out = address_in >> 8;    PSRAM_Write_Clk_Cycle();
  nibble_out = address_in >> 4;    PSRAM_Write_Clk_Cycle();
  nibble_out = address_in;         PSRAM_Write_Clk_Cycle();

#if XTMAX_PSRAM_EARLY_CHRDY
  GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_LOW;
#endif

 
 // Four clocks of hi-Z - Make PSRAM Data signals hi-Z during this time
 //
 GPIO9_GDIR = 0x03400000;                               // Change Data[3:0] to inputs quickly
 PSRAM_Write_Clk_Cycle(); 
 PSRAM_Write_Clk_Cycle();   
 PSRAM_Write_Clk_Cycle();   
 PSRAM_Write_Clk_Cycle(); 


  // Clock in the data
  //                  
  PSRAM_Read_Clk_Cycle();  read_byte = nibble_in;
  PSRAM_Read_Clk_Cycle();  read_byte = (read_byte<<4) | nibble_in;

  GPIO9_DR = PSRAM_RESET_VALUE;                       // Drive  CLK=0 , CS_n=1
  GPIO9_GDIR = 0x3F400000;                            // Change Data[3:0] to outputs quickly

  return read_byte;
}

 
// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void PSRAM_Write(uint32_t address_in , int8_t local_data) {
  if (address_in >= EMS_MAX_SIZE) {
    return;
  }
  if (address_in >= 0x7FFFFF)  psram_cs=1; else psram_cs=0;  


  // Send Command = Quad Write = 0x02
  //
  nibble_out = 0x0;    PSRAM_Write_Clk_Cycle();
  nibble_out = 0x2;    PSRAM_Write_Clk_Cycle();


  // Send 24-bit address in six clock cycles
  //
  nibble_out = address_in >> 20;   PSRAM_Write_Clk_Cycle();
  nibble_out = address_in >> 16;   PSRAM_Write_Clk_Cycle();
  nibble_out = address_in >> 12;   PSRAM_Write_Clk_Cycle();
  nibble_out = address_in >> 8;    PSRAM_Write_Clk_Cycle();
  nibble_out = address_in >> 4;    PSRAM_Write_Clk_Cycle();
  nibble_out = address_in;         PSRAM_Write_Clk_Cycle();

#if XTMAX_PSRAM_EARLY_CHRDY
  GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_LOW;
#endif

 
  // Send byte data in two clock cycles
  //
  nibble_out = local_data >> 4;   PSRAM_Write_Clk_Cycle();
  nibble_out = local_data;        PSRAM_Write_Clk_Cycle();

  GPIO9_DR = PSRAM_RESET_VALUE;                       // Drive  CLK=0 , CS_n=1
}
 
 
// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline uint8_t Internal_RAM_Read() {
    if (isa_address<sizeof(internal_RAM1))    return internal_RAM1[isa_address];
    else                                      return internal_RAM2[isa_address-sizeof(internal_RAM1)];
}

inline void Internal_RAM_Write() {
    if (isa_address<sizeof(internal_RAM1))    internal_RAM1[isa_address]                       = 0xFF & ADDRESS_DATA_GPIO6_UNSCRAMBLE;
    else                                      internal_RAM2[isa_address-sizeof(internal_RAM1)] = 0xFF & ADDRESS_DATA_GPIO6_UNSCRAMBLE;
}

// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void Mem_Read_Cycle()
{
  isa_address = ADDRESS_DATA_GPIO6_UNSCRAMBLE;

  Region region = XTMax_GetRegion(&xtmax, isa_address);
  switch (region) {
    case EmsWindow:
      if (!XTMax_ResolveEmsAddress(&xtmax, isa_address, &psram_address)) {
        GPIO7_DR = MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
        GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
        while ( (gpio9_int&0xF0) != 0xF0 ) { gpio9_int = GPIO9_DR; }
        break;
      }

      GPIO7_DR = MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_LOW + DATA_OE_n_LOW ;  // Assert CHRDY_n=0 to begin wait states

      isa_data_out = PSRAM_Read(psram_address);
      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;  // Output data
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_LOW;  // De-assert CHRDY

      while ( (gpio9_int&0xF0) != 0xF0 ) { gpio9_int = GPIO9_DR; }  // Wait here until cycle is complete

      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
      break;

    case Ram:
      isa_data_out = Internal_RAM_Read();
      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;

      // If XTMax has not seen a read access to this 64 KB page yet, add wait states to give physical RAM (if present) a chance to respond
      if (XTMax_MEM_Response_Array[(isa_address>>16)] == Respond) {
        GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_LOW;   // Physical RAM is NOT present at this page so XTMax will respond
      }
      else if (XTMax_MEM_Response_Array[(isa_address>>16)] == AutoDetect) {
        GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_LOW + DATA_OE_n_HIGH;   // Assert CHRDY_n=0 to begin wait states
        delayNanoseconds(AUTODETECT_READ_DELAY_NS);
        GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;  // De-assert CHRDY

        gpio6_int = GPIO6_DR;                                //  Read the data bus value currently on the ISA bus
        data_in = 0xFF & ADDRESS_DATA_GPIO6_UNSCRAMBLE;

        if (data_in == isa_data_out) {
          XTMax_MEM_Response_Array[(isa_address>>16)] = DontRespond;   // Physical RAM is present at this page so XTMax should not respond
        }
        else {
          XTMax_MEM_Response_Array[(isa_address>>16)] = Respond;
          GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_LOW;    // Physical RAM is NOT present at this page so XTMax will respond
        }
      }
      else if (XTMax_MEM_Response_Array[(isa_address>>16)] == DontRespond) {
        GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
      }

      while ( (gpio9_int&0xF0) != 0xF0 ) { gpio9_int = GPIO9_DR; }  // Wait here until cycle is complete

      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
      break;

    case BootRom:
      isa_data_out = BOOTROM[isa_address-BOOTROM_ADDR];
      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW + CHRDY_OUT_LOW + trigger_out;
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_LOW;

      while ( (gpio9_int&0xF0) != 0xF0 ) { gpio9_int = GPIO9_DR; }  // Wait here until cycle is complete

      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
      break;

    case SdCard:
      GPIO7_DR = MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_LOW + DATA_OE_n_LOW ;  // Assert CHRDY_n=0 to begin wait states

      // Receive a byte to the SD Card
      sd_spi_dataout = 0xff; SD_SPI_Cycle(); isa_data_out = sd_spi_datain;
      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;  // Output data
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_LOW;  // De-assert CHRDY

      while ( (gpio9_int&0xF0) != 0xF0 ) { gpio9_int = GPIO9_DR; }  // Wait here until cycle is complete

      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
      break;

    default:
      break;
  }
}


// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void Mem_Write_Cycle()
{
  isa_address = ADDRESS_DATA_GPIO6_UNSCRAMBLE;

  Region region = XTMax_GetRegion(&xtmax, isa_address);
  switch (region) {
    case EmsWindow:
      if (!XTMax_ResolveEmsAddress(&xtmax, isa_address, &psram_address)) {
        GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
        GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
        while ( (gpio9_int&0xF0) != 0xF0 ) { gpio6_int = GPIO6_DR; gpio9_int = GPIO9_DR; }
        break;
      }

      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_HIGH  + CHRDY_OUT_LOW + trigger_out;
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_LOW + CHRDY_OE_n_LOW + DATA_OE_n_HIGH;    // Steer data mux to Data[7:0] and Assert CHRDY_n=0 to begin wait states

      delayNanoseconds(MUX_DATA_SWITCH_NS);  // Wait some time for buffers to switch from address to data

      gpio6_int = GPIO6_DR;
      data_in = 0xFF & ADDRESS_DATA_GPIO6_UNSCRAMBLE;
      PSRAM_Write(psram_address , data_in);
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_LOW + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;  // De-assert CHRDY
     
      while ( (gpio9_int&0xF0) != 0xF0 ) {   // Wait here until cycle is complete
        gpio6_int = GPIO6_DR;     
        gpio9_int = GPIO9_DR;
      }

      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
      break;

    case Ram:
      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_HIGH  + CHRDY_OUT_LOW + trigger_out;
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_LOW + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;

      while ( (gpio9_int&0xF0) != 0xF0 ) {   // Wait here until cycle is complete
        gpio6_int = GPIO6_DR;
        gpio9_int = GPIO9_DR;
      }

      Internal_RAM_Write();

      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
      break;

    case SdCard:
      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_HIGH  + CHRDY_OUT_LOW + trigger_out;
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_LOW + CHRDY_OE_n_LOW + DATA_OE_n_HIGH;    // Steer data mux to Data[7:0] and Assert CHRDY_n=0 to begin wait states

      delayNanoseconds(MUX_DATA_SWITCH_NS);  // Wait some time for buffers to switch from address to data

      gpio6_int = GPIO6_DR;
      data_in = 0xFF & ADDRESS_DATA_GPIO6_UNSCRAMBLE;

      // Send a byte to the SD Card
      sd_spi_dataout = data_in;  SD_SPI_Cycle();
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_LOW + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;  // De-assert CHRDY

      while ( (gpio9_int&0xF0) != 0xF0 ) {   // Wait here until cycle is complete
        gpio6_int = GPIO6_DR;
        gpio9_int = GPIO9_DR;
      }

      GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
      GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
      break;

    default:
      break;
  }
}


// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void IO_Read_Cycle()
{
  isa_address = 0xFFFF & ADDRESS_DATA_GPIO6_UNSCRAMBLE;

  if ((isa_address&0x0FF0)==MMAN_BASE) {   // Location of Memory MANager registers
    isa_data_out = XTMax_ReadMmanRegister(&xtmax, isa_address);

    GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_LOW;

    while ( (gpio9_int&0xF0) != 0xF0 ) { gpio9_int = GPIO9_DR; }  // Wait here until cycle is complete

    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
  }
  else if ((isa_address&0x0FF8)==SD_BASE) {   // Location of SD Card registers
    switch (isa_address)  {
      case SD_BASE+0:  sd_spi_dataout = 0xff; SD_SPI_Cycle(); isa_data_out = sd_spi_datain; break;
      case SD_BASE+1:  isa_data_out = SD_CONFIG_BYTE; break;
      case SD_BASE+2:  isa_data_out = sd_scratch_register[0]; break;
      case SD_BASE+3:  isa_data_out = sd_scratch_register[1]; break;
      case SD_BASE+4:  isa_data_out = sd_scratch_register[2]; break;
      case SD_BASE+5:  isa_data_out = sd_scratch_register[3]; break;
      case SD_BASE+6:  isa_data_out = sd_scratch_register[4]; break;
      case SD_BASE+7:  isa_data_out = sd_timeout >= sd_requested_timeout; break;
      default:         isa_data_out = 0xff; break;
    }

    GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_LOW;

    while ( (gpio9_int&0xF0) != 0xF0 ) { gpio9_int = GPIO9_DR; }  // Wait here until cycle is complete

    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
  }
}
   

// --------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------

inline void IO_Write_Cycle()
{
  isa_address = 0xFFFF & ADDRESS_DATA_GPIO6_UNSCRAMBLE;

  if ((isa_address&0x0FF0)==MMAN_BASE) {   // Location of Memory MANager registers
    GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_HIGH  + CHRDY_OUT_LOW + trigger_out;
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_LOW + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;

    delayNanoseconds(IO_WRITE_SETTLE_NS); // Give some time for write data to be available after IOWR_n goes low
    gpio6_int = GPIO6_DR;
    data_in = 0xFF & ADDRESS_DATA_GPIO6_UNSCRAMBLE;

    XTMax_WriteMmanRegister(&xtmax, isa_address, data_in);

    while ( (gpio9_int&0xF0) != 0xF0 ) {   // Wait here until cycle is complete
      gpio6_int = GPIO6_DR;
      gpio9_int = GPIO9_DR;
    }

    GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
  }
  else if ((isa_address&0x0FF8)==SD_BASE) {   // Location of SD Card registers
    GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_HIGH  + CHRDY_OUT_LOW + trigger_out;
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_LOW + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;

    delayNanoseconds(IO_WRITE_SETTLE_NS); // Give some time for write data to be available after IOWR_n goes low
    gpio6_int = GPIO6_DR;
    data_in = 0xFF & ADDRESS_DATA_GPIO6_UNSCRAMBLE;

    switch (isa_address)  {
      case SD_BASE+0:  sd_spi_dataout = data_in;  SD_SPI_Cycle(); break;
      case SD_BASE+1:  sd_spi_cs_n    = data_in&0x1; break;
      case SD_BASE+2:  sd_scratch_register[0] = data_in; break;
      case SD_BASE+3:  sd_scratch_register[1] = data_in; break;
      case SD_BASE+4:  sd_scratch_register[2] = data_in; break;
      case SD_BASE+5:  sd_scratch_register[3] = data_in; break;
      case SD_BASE+6:  sd_scratch_register[4] = data_in; break;
      case SD_BASE+7:  sd_timeout = 0; sd_requested_timeout = data_in * 10; break;
    }

    //gpio9_int = GPIO9_DR;
    while ( (gpio9_int&0xF0) != 0xF0 ) {   // Wait here until cycle is complete
      gpio6_int = GPIO6_DR;
      gpio9_int = GPIO9_DR;
    }

    sd_pin_outputs = (sd_spi_cs_n<<17);   // SD_CS_n - SD_CLK - SD_MOSI

    GPIO7_DR = GPIO7_DATA_OUT_UNSCRAMBLE + MUX_ADDR_n_LOW  + CHRDY_OUT_LOW + trigger_out;
    GPIO8_DR = sd_pin_outputs + MUX_DATA_n_HIGH + CHRDY_OE_n_HIGH + DATA_OE_n_HIGH;
  }
}


   
// -------------------------------------------------
//
// Main loop
//
// -------------------------------------------------
void loop() {


  // Give Teensy 4.1 a moment
  //
  //delay (1000);
 
#if !XTMAX_SKIP_PSRAM_INIT
  PSRAM_Configure();
#endif

  while (1) {
     
      gpio6_int = GPIO6_DR;
      gpio9_int = GPIO9_DR;
           if ((gpio9_int&0x80000010)==0)  IO_Read_Cycle();  // Isolate and check AEN and IO Rd/Wr
      else if ((gpio9_int&0x80000020)==0)  IO_Write_Cycle();
      else if ((gpio9_int&0x00000040)==0)  Mem_Read_Cycle();
      else if ((gpio9_int&0x00000080)==0)  Mem_Write_Cycle();
  }
}
