local result_path = emu.subst_env("$XTMAX_MAME_ASSERT_FILE")
local startup_wait = tonumber(emu.subst_env("$XTMAX_MAME_ASSERT_STARTUP_WAIT")) or 25
local timeout = tonumber(emu.subst_env("$XTMAX_MAME_ASSERT_TIMEOUT")) or 10
local expected_cs = emu.subst_env("$XTMAX_MAME_EXPECT_CS")
local expected_ip = emu.subst_env("$XTMAX_MAME_EXPECT_IP")
local expected_halt = emu.subst_env("$XTMAX_MAME_EXPECT_HALT")

local function find_cpu()
  local cpu = manager.machine.devices[":maincpu"]
  if cpu and cpu.state then
    return cpu, ":maincpu"
  end

  for tag, device in pairs(manager.machine.devices) do
    if device.state then
      return device, tag
    end
  end

  return nil, nil
end

local function get_state_value(cpu, name)
  local ok, value = pcall(function()
    local entry = cpu.state[name]
    if entry == nil then
      return nil
    end
    return entry.value
  end)
  if ok then
    return value
  end
  return nil
end

local function fmt_state(cpu)
  local parts = {}
  for _, name in ipairs({ "PC", "CS", "IP", "AX", "BX", "CX", "DX", "DS", "ES", "SS", "SP", "FLAGS", "HALT" }) do
    local value = get_state_value(cpu, name)
    if value ~= nil then
      parts[#parts + 1] = string.format("%s=%s", name, tostring(value))
    end
  end
  return table.concat(parts, " ")
end

local function matches(cpu)
  local cs = get_state_value(cpu, "CS")
  local ip = get_state_value(cpu, "IP")
  local halt = get_state_value(cpu, "HALT")

  if expected_cs ~= "" and cs ~= tonumber(expected_cs) then
    return false
  end
  if expected_ip ~= "" and ip ~= tonumber(expected_ip) then
    return false
  end
  if expected_halt ~= "" and halt ~= tonumber(expected_halt) then
    return false
  end
  return true
end

local function write_result(status, detail)
  local handle, err = io.open(result_path, "w")
  if not handle then
    emu.print_error("XTMax CPU-state assert failed to open result file: " .. tostring(err) .. "\n")
    return
  end
  handle:write(status, "\n")
  handle:write(detail)
  handle:close()
end

local function main()
  local cpu, cpu_tag = find_cpu()
  if not cpu then
    write_result("FAIL", "Could not locate a CPU with readable state.\n")
    manager.machine:exit()
    return
  end

  if not emu.wait(startup_wait) then
    write_result("FAIL", "Emulation stopped before startup wait completed.\n")
    return
  end

  local started = manager.machine.time
  local latest_state = fmt_state(cpu)

  while (manager.machine.time - started).seconds < timeout do
    latest_state = fmt_state(cpu)
    if matches(cpu) then
      write_result(
        "PASS",
        "CPU: " .. tostring(cpu_tag) .. "\n\n" ..
        latest_state .. "\n"
      )
      manager.machine:exit()
      return
    end

    if not emu.wait(0.5) then
      break
    end
  end

  write_result(
    "FAIL",
    "CPU: " .. tostring(cpu_tag) .. "\n\n" ..
    latest_state .. "\n"
  )
  manager.machine:exit()
end

main()
