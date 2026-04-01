#include "xtmax_core.h"

namespace {

constexpr uint16_t kMmanBase = 0x260;
constexpr uint32_t k2KiBPageShift = 11;
constexpr uint32_t k2KiBPageCount = 512;
constexpr uint32_t k64KiBPageCount = 16;
constexpr uint32_t k64KiBConventionalLimit = 10;
constexpr uint32_t k64KiBUpperMemoryLimit = 15;
constexpr uint32_t k2KiBPer64KiB = 32;

}  // namespace

void XTMax_InitState(XtmaxState* state,
                     bool disable_conventional_ram_map,
                     bool disable_bootrom_map,
                     uint32_t bootrom_addr,
                     size_t bootrom_size) {
  for (uint32_t i = 0; i < k64KiBPageCount; ++i) {
    if (i < k64KiBConventionalLimit) {
      state->mem_response[i] = AutoDetect;
    } else if (i < k64KiBUpperMemoryLimit) {
      state->mem_response[i] = Respond;
    } else {
      state->mem_response[i] = DontRespond;
    }
  }

  for (uint32_t i = 0; i < k2KiBPageCount; ++i) {
    const bool conventional_page = i < (k64KiBConventionalLimit * k2KiBPer64KiB);
    state->memmap[i] = (!disable_conventional_ram_map && conventional_page) ? Ram : Unused;
  }

  for (uint32_t i = 0; i < 4; ++i) {
    state->ems_frame_pointer[i] = 0xFFFF;
  }
  state->ems_base_segment = 0;
  state->umb_base_segment = 0;

  if (!disable_bootrom_map) {
    const uint32_t start = bootrom_addr >> k2KiBPageShift;
    const uint32_t end = (bootrom_addr + static_cast<uint32_t>(bootrom_size)) >> k2KiBPageShift;
    for (uint32_t i = start; i < end && i < k2KiBPageCount; ++i) {
      state->memmap[i] = BootRom;
    }
    if (end < k2KiBPageCount) {
      state->memmap[end] = SdCard;
    }
  }
}

Region XTMax_GetRegion(const XtmaxState* state, uint32_t address) {
  const uint32_t index = address >> k2KiBPageShift;
  if (index >= k2KiBPageCount) {
    return Unused;
  }
  return state->memmap[index];
}

bool XTMax_ResolveEmsAddress(const XtmaxState* state,
                             uint32_t isa_address,
                             uint32_t* psram_address) {
  const uint32_t frame_base = static_cast<uint32_t>(state->ems_base_segment) << 4;
  const uint32_t page_base = isa_address & 0xFC000;

  if (page_base < frame_base) {
    return false;
  }

  uint32_t frame_index = 0;
  switch (page_base - frame_base) {
    case 0x0000:
      frame_index = 0;
      break;
    case 0x4000:
      frame_index = 1;
      break;
    case 0x8000:
      frame_index = 2;
      break;
    case 0xC000:
      frame_index = 3;
      break;
    default:
      return false;
  }

  *psram_address = (static_cast<uint32_t>(state->ems_frame_pointer[frame_index]) << 14)
                 | (isa_address & 0x03FFF);
  return true;
}

uint8_t XTMax_ReadMmanRegister(const XtmaxState* state, uint16_t io_address) {
  switch (io_address) {
    case kMmanBase + 0:
      return state->ems_frame_pointer[0] & 0xFF;
    case kMmanBase + 1:
      return state->ems_frame_pointer[0] >> 8;
    case kMmanBase + 2:
      return state->ems_frame_pointer[1] & 0xFF;
    case kMmanBase + 3:
      return state->ems_frame_pointer[1] >> 8;
    case kMmanBase + 4:
      return state->ems_frame_pointer[2] & 0xFF;
    case kMmanBase + 5:
      return state->ems_frame_pointer[2] >> 8;
    case kMmanBase + 6:
      return state->ems_frame_pointer[3] & 0xFF;
    case kMmanBase + 7:
      return state->ems_frame_pointer[3] >> 8;
    case kMmanBase + 15: {
      const uint32_t index = state->umb_base_segment >> 7;
      return index < k2KiBPageCount ? state->memmap[index] : 0xFF;
    }
    default:
      return 0xFF;
  }
}

void XTMax_WriteMmanRegister(XtmaxState* state, uint16_t io_address, uint8_t value) {
  switch (io_address) {
    case kMmanBase + 0:
      state->ems_frame_pointer[0] = (state->ems_frame_pointer[0] & 0xFF00) | value;
      break;
    case kMmanBase + 1:
      state->ems_frame_pointer[0] = (state->ems_frame_pointer[0] & 0x00FF) | (static_cast<uint16_t>(value) << 8);
      break;
    case kMmanBase + 2:
      state->ems_frame_pointer[1] = (state->ems_frame_pointer[1] & 0xFF00) | value;
      break;
    case kMmanBase + 3:
      state->ems_frame_pointer[1] = (state->ems_frame_pointer[1] & 0x00FF) | (static_cast<uint16_t>(value) << 8);
      break;
    case kMmanBase + 4:
      state->ems_frame_pointer[2] = (state->ems_frame_pointer[2] & 0xFF00) | value;
      break;
    case kMmanBase + 5:
      state->ems_frame_pointer[2] = (state->ems_frame_pointer[2] & 0x00FF) | (static_cast<uint16_t>(value) << 8);
      break;
    case kMmanBase + 6:
      state->ems_frame_pointer[3] = (state->ems_frame_pointer[3] & 0xFF00) | value;
      break;
    case kMmanBase + 7:
      state->ems_frame_pointer[3] = (state->ems_frame_pointer[3] & 0x00FF) | (static_cast<uint16_t>(value) << 8);
      break;
    case kMmanBase + 10:
      state->ems_base_segment = (state->ems_base_segment & 0xFF00) | value;
      break;
    case kMmanBase + 11:
      state->ems_base_segment = (state->ems_base_segment & 0x00FF) | (static_cast<uint16_t>(value) << 8);
      break;
    case kMmanBase + 12:
      if (state->ems_base_segment >= 0xA000
          && state->ems_base_segment + (value << 10) <= 0xF000) {
        const uint32_t base = state->ems_base_segment >> 7;
        const uint32_t count = static_cast<uint32_t>(value) << 3;
        for (uint32_t i = 0; i < count && (base + i) < k2KiBPageCount; ++i) {
          state->memmap[base + i] = EmsWindow;
        }
      }
      break;
    case kMmanBase + 13:
      state->umb_base_segment = (state->umb_base_segment & 0xFF00) | value;
      break;
    case kMmanBase + 14:
      state->umb_base_segment = (state->umb_base_segment & 0x00FF) | (static_cast<uint16_t>(value) << 8);
      break;
    case kMmanBase + 15:
      if (state->umb_base_segment >= 0xA000
          && state->umb_base_segment + (value << 7) <= 0xF000) {
        const uint32_t base = state->umb_base_segment >> 7;
        for (uint32_t i = 0; i < value && (base + i) < k2KiBPageCount; ++i) {
          state->memmap[base + i] = Ram;
        }
      }
      break;
    default:
      break;
  }
}
