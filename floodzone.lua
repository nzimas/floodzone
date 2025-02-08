-- FLOODZONE
-- by @nzimas
-- based on Twine by: @cfd90
-- Long-press K2 to trig transition
-- Short-press K2 to rnd slot 1
-- Short-press K3 to rnd slot 2
-- Long-press K1 to rnd slot 3
-- Loads of params in EDIT menu

engine.name = "Glut"

----------------------------------------------------------------
-- 1) GLOBALS & HELPERS
----------------------------------------------------------------

-- Visual fill levels for each slot: 1 is fully filled, 0 is empty.
local fill_levels = {1, 0, 0}

local function file_dir_name(fullpath)
  local dir = string.match(fullpath, "^(.*)/[^/]*$")
  return dir or fullpath
end

-- We'll store the user-chosen folder here (so transition_to_new_state() can see it)
local sample_dir = _path.audio

-- Geometry for squares
local square_size = 30
local square_y = 15
local square_x = {10, 49, 88}

local ui_metro
local lfo_metros = {nil, nil, nil}
local random_seek_metros = {nil, nil, nil}
local active_slot = 1

local scale_options = {"dorian", "natural minor", "harmonic minor", "melodic minor", "major", "locrian", "phrygian"}
local scales = {
  dorian         = {0, 2, 3, 5, 7, 9, 10},
  ["natural minor"]  = {0, 2, 3, 5, 7, 8, 10},
  ["harmonic minor"] = {0, 2, 3, 5, 7, 8, 11},
  ["melodic minor"]  = {0, 2, 3, 5, 7, 9, 11},
  major          = {0, 2, 4, 5, 7, 9, 11},
  locrian        = {0, 1, 3, 5, 6, 8, 10},
  phrygian       = {0, 1, 3, 5, 7, 8, 10}
}

local function setup_ui_metro()
  ui_metro = metro.init()
  ui_metro.time = 1/15
  ui_metro.event = function()
    redraw()
  end  
  ui_metro:start()
end

local function smooth_transition(param_name, new_val, duration)
  clock.run(function()
    local start_val = params:get(param_name)
    local steps = 60
    local dt = duration / steps
    for i = 1, steps do
      local t = i / steps
      local interpolated = start_val + (new_val - start_val) * t
      params:set(param_name, interpolated)
      clock.sleep(dt)
    end
    params:set(param_name, new_val)
  end)
end

-- Volume fade utilities
local function volume_fade_out(slot, duration)
  clock.run(function()
    local start_db = params:get(slot .. "volume")
    local end_db = -60
    local steps = 60
    local dt = duration / steps
    for i = 1, steps do
      local t = i / steps
      local factor = t^2
      local new_db = start_db + (end_db - start_db) * factor
      params:set(slot .. "volume", new_db)
      clock.sleep(dt)
    end
    params:set(slot .. "volume", end_db)
  end)
end

local function volume_fade_in(slot, duration)
  clock.run(function()
    local start_db = params:get(slot .. "volume")
    local end_db = 0
    local steps = 60
    local dt = duration / steps
    for i = 1, steps do
      local t = i / steps
      local factor = 1 - (1 - t)^2
      local new_db = start_db + (end_db - start_db) * factor
      params:set(slot .. "volume", new_db)
      clock.sleep(dt)
    end
    params:set(slot .. "volume", end_db)
  end)
end

-- Option lists for transition times
local transition_time_options = {}
for t = 100, 1000, 100 do
  table.insert(transition_time_options, t)
end
for t = 1500, 90000, 500 do
  table.insert(transition_time_options, t)
end

----------------------------------------------------------------
-- 2) PARAMS
----------------------------------------------------------------

local function setup_params()
  params:add_separator("random sample")
  
  -- random sample on/off
  params:add_option("random_sample", "random sample?", {"no", "yes"}, 1)

  -- user picks a file, we strip it to the folder
  params:add_file("sample_dir", "sample directory")
  params:set_action("sample_dir", function(file)
    if file ~= "" then
      local folder = file_dir_name(file)
      if folder ~= nil then
        sample_dir = folder
        print("sample_dir set to: " .. sample_dir)
      end
    end
  end)

  params:add_separator("samples")
  for i=1,3 do
    params:add_file(i .. "sample", i .. " sample")
    params:set_action(i .. "sample", function(file) engine.read(i, file) end)

    params:add_taper(i .. "volume", i .. " volume", -60, 20, 0, 0, "dB")
    params:set_action(i .. "volume", function(value) engine.volume(i, math.pow(10, value / 20)) end)

    params:add_taper(i .. "speed", i .. " speed", -400, 400, 0, 0, "%")
    params:set_action(i .. "speed", function(value) engine.speed(i, value / 100) end)

    params:add_taper(i .. "jitter", i .. " jitter", 0, 2000, 0, 5, "ms")
    params:set_action(i .. "jitter", function(value) engine.jitter(i, value / 1000) end)

    params:add_taper(i .. "size", i .. " size", 1, 500, 100, 5, "ms")
    params:set_action(i .. "size", function(value) engine.size(i, value / 1000) end)

    params:add_taper(i .. "density", i .. " density", 0, 512, 20, 6, "hz")
    params:set_action(i .. "density", function(value) engine.density(i, value) end)

    params:add_taper(i .. "pitch", i .. " pitch", -48, 48, 0, 0, "st")
    params:set_action(i .. "pitch", function(value) engine.pitch(i, math.pow(0.5, -value / 12)) end)

    params:add_taper(i .. "spread", i .. " spread", 0, 100, 0, 0, "%")
    params:set_action(i .. "spread", function(value) engine.spread(i, value / 100) end)

    params:add_taper(i .. "fade", i .. " att / dec", 1, 9000, 1000, 3, "ms")
    params:set_action(i .. "fade", function(value) engine.envscale(i, value / 1000) end)

    params:add_control(i .. "seek", i .. " seek", controlspec.new(0, 100, "lin", 0.1, (i == 3) and 100 or 0, "%", 0.1/100))
    params:set_action(i .. "seek", function(value) engine.seek(i, value / 100) end)

    params:add_option(i .. "random_seek", i .. " randomize seek", {"off", "on"}, 1)
    params:set_action(i .. "random_seek", function(val)
      if val == 2 then
        if random_seek_metros[i] == nil then
          random_seek_metros[i] = metro.init()
          random_seek_metros[i].event = function()
            params:set(i .. "seek", math.random() * 100)
          end
        end
        random_seek_metros[i]:start(params:get(i .. "random_seek_freq") / 1000)
      else
        if random_seek_metros[i] ~= nil then
          random_seek_metros[i]:stop()
        end
      end
    end)

    params:add_control(i .. "random_seek_freq", i .. " random seek freq", controlspec.new(100, 90000, "lin", 100, 1000, "ms", 100/90000))
    params:set_action(i .. "random_seek_freq", function(value)
      if params:get(i .. "random_seek") == 2 and random_seek_metros[i] ~= nil then
        random_seek_metros[i].time = value / 1000
        random_seek_metros[i]:start()
      end
    end)

    -- LFO automation
    params:add_option(i .. "automate_density", i .. " automate density", {"off", "on"}, 1)
    params:add_option(i .. "automate_size", i .. " automate size", {"off", "on"}, 1)
    params:set_action(i .. "automate_density", function(val)
      if val == 2 then
        if lfo_metros[i] == nil then
          lfo_metros[i] = metro.init()
          lfo_metros[i].event = function()
            if params:get(i.."automate_density") == 2 then
              local min_d = params:get("min_density")
              local max_d = params:get("max_density")
              local lfo_v = (math.sin(util.time() * params:get(i.."density_lfo") * 2 * math.pi) + 1) / 2
              local d = min_d + (max_d - min_d) * lfo_v
              params:set(i.."density", d)
            end
            if params:get(i.."automate_size") == 2 then
              local min_s = params:get("min_size")
              local max_s = params:get("max_size")
              local lfo_v = (math.sin(util.time() * params:get(i.."size_lfo") * 2 * math.pi) + 1) / 2
              local s = min_s + (max_s - min_s) * lfo_v
              params:set(i.."size", s)
            end
          end
        end
        lfo_metros[i]:start(1/30)
      else
        if lfo_metros[i] ~= nil then
          lfo_metros[i]:stop()
        end
      end
    end)

    params:set_action(i .. "automate_size", function(val)
      if val == 2 then
        if lfo_metros[i] == nil then
          lfo_metros[i] = metro.init()
          lfo_metros[i].event = function()
            local min_s = params:get("min_size")
            local max_s = params:get("max_size")
            local lfo_v = (math.sin(util.time() * params:get(i.."size_lfo") * 2 * math.pi) + 1) / 2
            local s = min_s + (max_s - min_s) * lfo_v
            params:set(i.."size", s)
          end
        end
        lfo_metros[i]:start(1/30)
      else
        if lfo_metros[i] ~= nil then
          lfo_metros[i]:stop()
        end
      end
    end)

    params:add_control(i.."density_lfo", i.." density lfo", controlspec.new(0.01, 10, "lin", 0.01, 0.5, "hz", 0.01/10))
    params:add_control(i.."size_lfo", i.." size lfo", controlspec.new(0.01, 10, "lin", 0.01, 0.5, "hz", 0.01/10))
    params:set_action(i.."density_lfo", function()
      if params:get(i.."automate_density") == 2 and lfo_metros[i] ~= nil then
        lfo_metros[i]:start()
      end
    end)
  end

  params:add_separator("key & scale")
  local note_names = {"C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B"}
  params:add_option("pitch_root", "root note", note_names, 1)
  params:add_option("pitch_scale", "scale", scale_options, 1)

  params:add_separator("transition")
  params:add_option("transition_time", "transition time (ms)", transition_time_options, 10)

  params:add_separator("reverb")
  params:add_taper("reverb_mix", "* mix", 0, 100, 50, 0, "%")
  params:set_action("reverb_mix", function(v) engine.reverb_mix(v / 100) end)
  params:add_taper("reverb_room", "* room", 0, 100, 50, 0, "%")
  params:set_action("reverb_room", function(v) engine.reverb_room(v / 100) end)
  params:add_taper("reverb_damp", "* damp", 0, 100, 50, 0, "%")
  params:set_action("reverb_damp", function(v) engine.reverb_damp(v / 100) end)

  params:add_separator("randomizer")
  params:add_taper("min_jitter",  "jitter (min)",  0, 2000, 0,   5, "ms")
  params:add_taper("max_jitter",  "jitter (max)",  0, 2000, 500, 5, "ms")
  params:add_taper("min_size",    "size (min)",    1, 500, 1,   5, "ms")
  params:add_taper("max_size",    "size (max)",    1, 500, 500, 5, "ms")
  params:add_taper("min_density", "density (min)", 0, 512, 0,   6, "hz")
  params:add_taper("max_density", "density (max)", 0, 512, 40,  6, "hz")
  params:add_taper("min_spread",  "spread (min)",  0, 100, 0,   0, "%")
  params:add_taper("max_spread",  "spread (max)",  0, 100, 100, 0, "%")
  params:add_taper("pitch_1", "pitch (1)", -48, 48, -12, 0, "st")
  params:add_taper("pitch_2", "pitch (2)", -48, 48, -5, 0, "st")
  params:add_taper("pitch_3", "pitch (3)", -48, 48, 0,  0, "st")
  params:add_taper("pitch_4", "pitch (4)", -48, 48, 7,  0, "st")
  params:add_taper("pitch_5", "pitch (5)", -48, 48, 12, 0, "st")

  params:bang()
end

----------------------------------------------------------------
-- 3) PICK RANDOM FILE
----------------------------------------------------------------

local function random_float(l, h)
  return l + math.random() * (h - l)
end

-- pick_random_file(dir) returns a random .wav/.aif/.aiff/.flac from dir or nil
local function pick_random_file(dir)
  if not dir or dir == "" then
    return nil
  end
  local files = util.scandir(dir)
  if not files then
    return nil
  end
  local audio_files = {}
  for _, f in ipairs(files) do
    local lower_f = string.lower(f)
    if string.match(lower_f, "%.wav$") or
       string.match(lower_f, "%.aif$") or
       string.match(lower_f, "%.aiff$") or
       string.match(lower_f, "%.flac$") then
      table.insert(audio_files, dir.."/"..f)
    end
  end
  if #audio_files > 0 then
    return audio_files[math.random(#audio_files)]
  else
    return nil
  end
end

----------------------------------------------------------------
-- 4) RANDOMIZE + TRANSITION
----------------------------------------------------------------

local function randomize(n)
  local transition_duration = transition_time_options[params:get("transition_time")] / 1000

  local new_jitter  = random_float(params:get("min_jitter"),  params:get("max_jitter"))
  local new_size    = random_float(params:get("min_size"),    params:get("max_size"))
  local new_density = random_float(params:get("min_density"), params:get("max_density"))
  local new_spread  = random_float(params:get("min_spread"),  params:get("max_spread"))

  local root_offset = params:get("pitch_root") - 1
  local scale_index = params:get("pitch_scale")
  local selected_scale = scale_options[scale_index]
  local base_intervals = scales[selected_scale]

  local allowed = {}
  for _, iv in ipairs(base_intervals) do
    table.insert(allowed, iv - 12)
    table.insert(allowed, iv)
    if iv == 0 then
      table.insert(allowed, iv + 12)
    end
  end
  local random_interval = allowed[math.random(#allowed)]
  local new_pitch = root_offset + random_interval

  smooth_transition(n.."jitter",  new_jitter,  transition_duration)
  smooth_transition(n.."size",    new_size,    transition_duration)
  smooth_transition(n.."density", new_density, transition_duration)
  smooth_transition(n.."spread",  new_spread,  transition_duration)

  params:set(n.."pitch", new_pitch)
end

local function transition_to_new_state()
  local transition_duration = transition_time_options[params:get("transition_time")] / 1000

  -- 1) pick a new slot
  local old_slot = active_slot
  local candidates = {}
  for i = 1, 3 do
    if i ~= old_slot then
      table.insert(candidates, i)
    end
  end
  local new_slot = candidates[math.random(#candidates)]

  -- 2) if random_sample == yes, pick & load
  if params:get("random_sample") == 2 then
    local rnd_file = pick_random_file(sample_dir)
    if rnd_file then
      print("Loading random file into slot "..new_slot..": "..rnd_file)
      engine.read(new_slot, rnd_file)
      -- also set the param so the UI shows the file
      params:set(tostring(new_slot).."sample", rnd_file)
    else
      print("No valid files found in "..sample_dir)
    end
  end

  -- gate on the new slot @ -60 dB
  engine.gate(new_slot, 1)
  params:set(new_slot.."volume", -60)

  -- copy old slot's granular params
  local granular_params = {"jitter", "size", "density", "spread"}
  for _, p in ipairs(granular_params) do
    local cur_val = params:get(old_slot..p)
    params:set(new_slot..p, cur_val)
  end

  -- compute new random target values
  local new_jitter  = random_float(params:get("min_jitter"),  params:get("max_jitter"))
  local new_size    = random_float(params:get("min_size"),    params:get("max_size"))
  local new_density = random_float(params:get("min_density"), params:get("max_density"))
  local new_spread  = random_float(params:get("min_spread"),  params:get("max_spread"))

  -- pick new pitch immediately
  local root_offset    = params:get("pitch_root") - 1
  local scale_index    = params:get("pitch_scale")
  local selected_scale = scale_options[scale_index]
  local base_intervals = scales[selected_scale]
  local allowed = {}
  for _, iv in ipairs(base_intervals) do
    table.insert(allowed, iv - 12)
    table.insert(allowed, iv)
    if iv == 0 then
      table.insert(allowed, iv + 12)
    end
  end
  local random_interval = allowed[math.random(#allowed)]
  local new_pitch       = root_offset + random_interval
  params:set(new_slot.."pitch", new_pitch)

  -- crossfade the granular params for new_slot
  smooth_transition(new_slot.."jitter",  new_jitter,  transition_duration)
  smooth_transition(new_slot.."size",    new_size,    transition_duration)
  smooth_transition(new_slot.."density", new_density, transition_duration)
  smooth_transition(new_slot.."spread",  new_spread,  transition_duration)

  -- volume crossfade in two phases
  local phase1_time = transition_duration * 0.2
  local phase2_time = transition_duration - phase1_time

  clock.run(function()
    local start_db = -60
    local mid_db   = -7
    local steps    = 30
    local dt       = phase1_time / steps

    for i = 1, steps do
      local t = i / steps
      local factor = 1 - (1 - t)^2
      local new_db = start_db + (mid_db - start_db) * factor
      params:set(new_slot.."volume", new_db)
      clock.sleep(dt)
    end
    params:set(new_slot.."volume", mid_db)

    -- once new_slot is -7 dB, fade out old_slot & fade in new_slot the rest
    clock.run(function()
      local start_db_out = 0
      local end_db_out   = -60
      local steps2       = 30
      local dt2          = phase2_time / steps2
      for j = 1, steps2 do
        local t2 = j / steps2
        local factor2 = t2^2
        local new_db_out = start_db_out + (end_db_out - start_db_out) * factor2
        params:set(old_slot.."volume", new_db_out)
        clock.sleep(dt2)
      end
      params:set(old_slot.."volume", end_db_out)
    end)

    clock.run(function()
      local start_db_in = -7
      local end_db_in   = 0
      local steps2      = 30
      local dt2         = phase2_time / steps2
      for j = 1, steps2 do
        local t2 = j / steps2
        local factor2 = 1 - (1 - t2)^2
        local new_db_in = start_db_in + (end_db_in - start_db_in) * factor2
        params:set(new_slot.."volume", new_db_in)
        clock.sleep(dt2)
      end
      params:set(new_slot.."volume", end_db_in)
    end)
  end)

  active_slot = new_slot

  -- VISUAL FADE for squares
  clock.run(function()
    local steps = 60
    local dt = transition_duration / steps
    for i = 1, steps do
      local t = i / steps
      fill_levels[old_slot] = 1 - t
      fill_levels[new_slot] = t
      clock.sleep(dt)
    end
    fill_levels[old_slot] = 0
    fill_levels[new_slot] = 1
  end)

  -- gate off old slot after some time
  clock.run(function()
    clock.sleep(transition_duration + 2)
    engine.gate(old_slot, 0)
  end)
end

----------------------------------------------------------------
-- 5) ENGINE / KEYS / REDRAW
----------------------------------------------------------------

local function setup_engine()
  engine.seek(1, 0)
  engine.gate(1, 1)
  params:set("1volume", 0)

  engine.seek(2, 0)
  engine.gate(2, 1)
  params:set("2volume", -60)

  engine.seek(3, 1)
  engine.gate(3, 1)
  params:set("3volume", -60)

  randomize(1)
  randomize(2)
  randomize(3)

  active_slot = 1
end

-- For distinguishing short vs. long press:
local key1_hold = false
local key2_hold = false

function key(n, z)
  if n == 1 then
    if z == 1 then
      -- pressed K1
      key1_hold = true
      clock.run(function()
        clock.sleep(1) -- if we hold K1 for ≥1s
        if key1_hold then
          randomize(3)  -- K1 long-press => randomize slot 3
        end
      end)
    else
      -- released K1
      key1_hold = false
    end

  elseif n == 2 then
    if z == 1 then
      -- pressed K2
      key2_hold = true
      clock.run(function()
        clock.sleep(1) -- if we hold K2 for ≥1s
        if key2_hold then
          transition_to_new_state() -- K2 long-press => transition
        end
      end)
    else
      -- released K2
      if key2_hold then
        -- If we release K2 before 1s => short-press => randomize slot 1
        key2_hold = false
        randomize(1)
      end
    end

  elseif n == 3 then
    -- immediate single-press => randomize slot 2
    if z == 1 then
      randomize(2)
    end
  end
end

function enc(n, d)
  if n == 1 then
    params:delta("1volume", d)
    params:delta("2volume", d)
    params:delta("3volume", d)
  elseif n == 2 then
    params:delta("1seek", d)
  elseif n == 3 then
    params:delta("2seek", d)
    params:delta("3seek", -d)
  end
end

function redraw()
  screen.clear()
  for i = 1, 3 do
    local fill = fill_levels[i]
    -- outline
    screen.level(15)
    screen.rect(square_x[i], square_y, square_size, square_size)
    screen.stroke()
    -- fill
    if fill > 0 then
      screen.level(10)
      local fill_height = square_size * fill
      local fill_y = square_y + (square_size - fill_height)
      screen.rect(square_x[i], fill_y, square_size, fill_height)
      screen.fill()
    end
  end
  screen.update()
end

function init()
  setup_ui_metro()
  setup_params()
  setup_engine()
  fill_levels = {1, 0, 0}
end
