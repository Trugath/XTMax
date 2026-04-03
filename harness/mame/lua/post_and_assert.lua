local result_path = emu.subst_env("$XTMAX_MAME_ASSERT_FILE")
local expected_raw = string.upper(emu.subst_env("$XTMAX_MAME_EXPECT_TEXT"))
local startup_wait = tonumber(emu.subst_env("$XTMAX_MAME_ASSERT_STARTUP_WAIT")) or 0
local timeout = tonumber(emu.subst_env("$XTMAX_MAME_ASSERT_TIMEOUT")) or 60
local post_after = tonumber(emu.subst_env("$XTMAX_MAME_POST_AFTER")) or 0
local post_text = emu.subst_env("$XTMAX_MAME_POST_CODED")
local post_when_text = string.upper(emu.subst_env("$XTMAX_MAME_POST_WHEN_TEXT"))
local post2_after = tonumber(emu.subst_env("$XTMAX_MAME_POST2_AFTER")) or 0
local post2_text = emu.subst_env("$XTMAX_MAME_POST2_CODED")
local post2_when_text = string.upper(emu.subst_env("$XTMAX_MAME_POST2_WHEN_TEXT"))

local function decode_escapes(text)
  return text
    :gsub("\\r", "\r")
    :gsub("\\n", "\n")
    :gsub("\\t", "\t")
    :gsub("\\\\", "\\")
end

post_text = decode_escapes(post_text)
post2_text = decode_escapes(post2_text)

local function split_expected(raw)
  local values = {}
  for part in string.gmatch(raw, "[^|]+") do
    values[#values + 1] = part
  end
  return values
end

local expected = split_expected(expected_raw)

local function find_program_space()
  local cpu = manager.machine.devices[":maincpu"]
  if cpu and cpu.spaces and cpu.spaces["program"] then
    return cpu.spaces["program"], ":maincpu"
  end

  for tag, device in pairs(manager.machine.devices) do
    if device.spaces and device.spaces["program"] then
      return device.spaces["program"], tag
    end
  end

  return nil, nil
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

local function contains_all(haystack, needles)
  for _, needle in ipairs(needles) do
    if needle ~= "" and not string.find(haystack, needle, 1, true) then
      return false
    end
  end
  return true
end

local function write_result(status, detail)
  if result_path == "" then
    emu.print_error("XTMax MAME assert file path is empty\n")
    return
  end

  local handle, err = io.open(result_path, "w")
  if not handle then
    emu.print_error("XTMax MAME assert failed to open result file: " .. tostring(err) .. "\n")
    return
  end

  handle:write(status, "\n")
  handle:write(detail)
  handle:close()
end

local function main()
  local space, cpu_tag = find_program_space()
  if not space then
    write_result("FAIL", "Could not locate a CPU program address space.\n")
    manager.machine:exit()
    return
  end

  local natkbd = manager.machine.natkeyboard
  if natkbd then
    natkbd.in_use = true
  end

  if startup_wait > 0 and not emu.wait(startup_wait) then
    write_result("FAIL", "Emulation stopped before startup wait completed.\n")
    return
  end

  local started = manager.machine.time
  local posted = false
  local posted2 = false

  while (manager.machine.time - started).seconds < timeout do
    local combined = capture_text(space)
    local elapsed = (manager.machine.time - started).seconds

    if not posted and post_text ~= "" and natkbd and natkbd.can_post then
      if elapsed >= post_after and (post_when_text == "" or string.find(combined, post_when_text, 1, true)) then
        natkbd:post_coded(post_text)
        posted = true
      end
    end

    if posted and not posted2 and post2_text ~= "" and natkbd and natkbd.can_post then
      if elapsed >= post2_after and (post2_when_text == "" or string.find(combined, post2_when_text, 1, true)) then
        natkbd:post_coded(post2_text)
        posted2 = true
      end
    end

    if contains_all(combined, expected) then
      write_result(
        "PASS",
        "CPU: " .. tostring(cpu_tag) .. "\n\n" ..
        "Expected: " .. expected_raw .. "\n\n" ..
        combined .. "\n"
      )
      manager.machine:exit()
      return
    end

    if not emu.wait(0.5) then
      write_result(
        "FAIL",
        "CPU: " .. tostring(cpu_tag) .. "\n\n" ..
        "Expected: " .. expected_raw .. "\n\n" ..
        "Emulation stopped before text assertions completed.\n\n" ..
        combined .. "\n"
      )
      return
    end
  end

  local combined = capture_text(space)
  write_result(
    "FAIL",
    "CPU: " .. tostring(cpu_tag) .. "\n\n" ..
    "Expected: " .. expected_raw .. "\n\n" ..
    combined .. "\n"
  )
  manager.machine:exit()
end

main()
