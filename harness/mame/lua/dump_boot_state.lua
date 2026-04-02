local result_path = emu.subst_env("$XTMAX_MAME_ASSERT_FILE")
local startup_wait = tonumber(emu.subst_env("$XTMAX_MAME_ASSERT_STARTUP_WAIT")) or 25
local timeout = tonumber(emu.subst_env("$XTMAX_MAME_ASSERT_TIMEOUT")) or 10

local function find_program_space()
  local cpu = manager.machine.devices[":maincpu"]
  if cpu and cpu.spaces and cpu.spaces["program"] then
    return cpu, cpu.spaces["program"], ":maincpu"
  end

  for tag, device in pairs(manager.machine.devices) do
    if device.spaces and device.spaces["program"] then
      return device, device.spaces["program"], tag
    end
  end

  return nil, nil, nil
end

local function read_text_buffer(space, base)
  local rows = {}
  for row = 0, 24 do
    local chars = {}
    local row_base = base + (row * 160)
    for col = 0, 79 do
      local value = space:read_u8(row_base + (col * 2))
      if value < 32 or value > 126 then
        value = 32
      end
      chars[#chars + 1] = string.char(value)
    end
    rows[#rows + 1] = table.concat(chars)
  end
  return table.concat(rows, "\n")
end

local function capture_text(space)
  local color = string.upper(read_text_buffer(space, 0xB8000))
  local mono = string.upper(read_text_buffer(space, 0xB0000))
  return color .. "\n----\n" .. mono
end

local function read_bootrom_bytes(space)
  local bytes = {}
  for i = 0, 31 do
    bytes[#bytes + 1] = string.format("%02X", space:read_u8(0xCE000 + i))
  end
  return table.concat(bytes, " ")
end

local function dump_cpu_state(cpu)
  local lines = {}
  if not cpu or not cpu.state then
    return "state unavailable"
  end

  for _, name in ipairs({ "PC", "CS", "IP", "AX", "BX", "CX", "DX", "DS", "ES", "SS", "SP", "FLAGS", "HALT" }) do
    local ok, value = pcall(function()
      local entry = cpu.state[name]
      if entry == nil then
        return nil
      end
      return entry.value
    end)
    if ok and value ~= nil then
      lines[#lines + 1] = string.format("%s=%s", name, tostring(value))
    end
  end

  if #lines == 0 then
    return "state unavailable"
  end

  return table.concat(lines, " ")
end

local function write_result(detail)
  local handle, err = io.open(result_path, "w")
  if not handle then
    emu.print_error("XTMax boot-state dump failed to open result file: " .. tostring(err) .. "\n")
    return
  end
  handle:write(detail)
  handle:close()
end

local function main()
  local cpu, space, cpu_tag = find_program_space()
  if not space then
    write_result("No CPU program space found.\n")
    manager.machine:exit()
    return
  end

  if not emu.wait(startup_wait) then
    write_result("Emulation stopped before startup wait.\n")
    return
  end

  local checkpoints = {}
  checkpoints[#checkpoints + 1] = "CPU: " .. tostring(cpu_tag)
  checkpoints[#checkpoints + 1] = "BOOTROM: " .. read_bootrom_bytes(space)
  checkpoints[#checkpoints + 1] = "STATE0: " .. dump_cpu_state(cpu)
  checkpoints[#checkpoints + 1] = capture_text(space)

  local started = manager.machine.time
  local sample = 1
  while (manager.machine.time - started).seconds < timeout do
    if not emu.wait(1.0) then
      break
    end
    sample = sample + 1
    checkpoints[#checkpoints + 1] = string.format("STATE%d: %s", sample, dump_cpu_state(cpu))
  end

  write_result(table.concat(checkpoints, "\n\n") .. "\n")
  manager.machine:exit()
end

main()
