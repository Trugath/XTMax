#pragma once

#include <stddef.h>
#include <stdint.h>

enum MemResponse {
  AutoDetect,
  DontRespond,
  Respond,
};

enum Region {
  Unused,
  Ram,
  EmsWindow,
  BootRom,
  SdCard
};

struct XtmaxState {
  MemResponse mem_response[16];
  Region memmap[512];
  uint16_t ems_frame_pointer[4];
  uint16_t ems_base_segment;
  uint16_t umb_base_segment;
};

// XT-visible card state and decode rules that can be reused by host tests or emulators.
void XTMax_InitState(XtmaxState* state,
                     bool disable_conventional_ram_map,
                     bool disable_bootrom_map,
                     uint32_t bootrom_addr,
                     size_t bootrom_size);

Region XTMax_GetRegion(const XtmaxState* state, uint32_t address);
bool XTMax_ResolveEmsAddress(const XtmaxState* state,
                             uint32_t isa_address,
                             uint32_t* psram_address);
uint8_t XTMax_ReadMmanRegister(const XtmaxState* state, uint16_t io_address);
void XTMax_WriteMmanRegister(XtmaxState* state, uint16_t io_address, uint8_t value);
