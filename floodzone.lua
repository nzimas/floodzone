-- THRINE - FLOODZONE
-- based on Twine by: @cfd90
-- extended by @nzimas
-- 
-- Load 3 samples, set long transition
-- long-press k1
-- watch the magic happen

engine.name = "Glut"

-- These globals are used for our UI metro and LFO/random seek metros:
local ui_metro
local lfo_metros = {nil, nil, nil}
local random_seek_metros = {nil, nil, nil}

-- Global variable to keep track of which sample slot is active.
-- By default, slot 1 is active.
local active_slot = 1

local function setup_ui_metro()
  ui_metro = metro.init()
  ui_metro.time = 1/15
  ui_metro.event = function()
    redraw()
  end  
  ui_metro:start()
end

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

local function smooth_transition(param_name, new_val, duration)
  clock.run(function()
    local start_val = params:get(param_name)
    local steps = 60              -- 60 steps (for roughly 30 fps)
    local dt = duration / steps   -- time per step
    for i = 1, steps do
      local t = i / steps
      local interpolated = start_val + (new_val - start_val) * t
      params:set(param_name, interpolated)
      clock.sleep(dt)
    end
    params:set(param_name, new_val)
  end)
end

-- New function for volume fade out using an ease–in curve.
local function volume_fade_out(slot, duration)
  clock.run(function()
    local start_db = params:get(tostring(slot) .. "volume")  -- should be 0 dB
    local end_db = -60
    local steps = 60
    local dt = duration / steps
    for i = 1, steps do
      local t = i / steps
      local factor = t^2  -- ease–in: slower start, then faster
      local new_db = start_db + (end_db - start_db) * factor
      params:set(tostring(slot) .. "volume", new_db)
      clock.sleep(dt)
    end
    params:set(tostring(slot) .. "volume", end_db)
  end)
end

-- New function for volume fade in using an ease–out curve.
local function volume_fade_in(slot, duration)
  clock.run(function()
    local start_db = params:get(tostring(slot) .. "volume")  -- should be -60 dB
    local end_db = 0
    local steps = 60
    local dt = duration / steps
    for i = 1, steps do
      local t = i / steps
      local factor = 1 - (1 - t)^2  -- ease–out: fast rise initially
      local new_db = start_db + (end_db - start_db) * factor
      params:set(tostring(slot) .. "volume", new_db)
      clock.sleep(dt)
    end
    params:set(tostring(slot) .. "volume", end_db)
  end)
end


local transition_time_options = {}
for t = 100, 1000, 100 do
  table.insert(transition_time_options, t)
end
for t = 1500, 45000, 500 do
  table.insert(transition_time_options, t)
end

local function setup_params()
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
    
    params:add_control(i .. "seek", i .. " seek", controlspec.new(0, 100, "lin", 0.1, i == 3 and 100 or 0, "%", 0.1/100))
    params:set_action(i .. "seek", function(value) engine.seek(i, value / 100) end)
    
    params:add_option(i .. "random_seek", i .. " randomize seek", {"off", "on"}, 1)
    params:set_action(i .. "random_seek", function(value)
      if value == 2 then
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
    
    params:add_control(i .. "random_seek_freq", i .. " random seek freq", controlspec.new(100, 45000, "lin", 100, 1000, "ms", 100/45000))
    params:set_action(i .. "random_seek_freq", function(value)
      if params:get(i .. "random_seek") == 2 and random_seek_metros[i] ~= nil then
        random_seek_metros[i].time = value / 1000
        random_seek_metros[i]:start()
      end
    end)

    params:add_option(i .. "automate_density", i .. " automate density", {"off", "on"}, 1)
    params:add_option(i .. "automate_size", i .. " automate size", {"off", "on"}, 1)
    params:set_action(i .. "automate_density", function(value)
      if value == 2 then
        if lfo_metros[i] == nil then
          lfo_metros[i] = metro.init()
          lfo_metros[i].event = function()
            if params:get(i .. "automate_density") == 2 then
              local min_density = params:get("min_density")
              local max_density = params:get("max_density")
              local lfo_value = (math.sin(util.time() * params:get(i .. "density_lfo") * 2 * math.pi) + 1) / 2
              local density = min_density + (max_density - min_density) * lfo_value
              params:set(i .. "density", density)
            end
            if params:get(i .. "automate_size") == 2 then
              local min_size = params:get("min_size")
              local max_size = params:get("max_size")
              local lfo_value = (math.sin(util.time() * params:get(i .. "size_lfo") * 2 * math.pi) + 1) / 2
              local size = min_size + (max_size - min_size) * lfo_value
              params:set(i .. "size", size)
            end
          end
        end
        lfo_metros[i]:start(1 / 30)
      else
        if lfo_metros[i] ~= nil then
          lfo_metros[i]:stop()
        end
      end
    end)
    
    params:set_action(i .. "automate_size", function(value)
      if value == 2 then
        if lfo_metros[i] == nil then
          lfo_metros[i] = metro.init()
          lfo_metros[i].event = function()
            local min_size = params:get("min_size")
            local max_size = params:get("max_size")
            local lfo_value = (math.sin(util.time() * params:get(i .. "size_lfo") * 2 * math.pi) + 1) / 2
            local size = min_size + (max_size - min_size) * lfo_value
            params:set(i .. "size", size)
          end
        end
        lfo_metros[i]:start(1 / 30)
      else
        if lfo_metros[i] ~= nil then
          lfo_metros[i]:stop()
        end
      end
    end)

    params:add_control(i .. "density_lfo", i .. " density lfo", controlspec.new(0.01, 10, "lin", 0.01, 0.5, "hz", 0.01/10))
    params:add_control(i .. "size_lfo", i .. " size lfo", controlspec.new(0.01, 10, "lin", 0.01, 0.5, "hz", 0.01/10))
    params:set_action(i .. "density_lfo", function(value)
      if params:get(i .. "automate_density") == 2 and lfo_metros[i] ~= nil then
        lfo_metros[i]:start()
      end
    end)
    
    params:hide(i .. "speed")
    params:hide(i .. "jitter")
    params:hide(i .. "size")
    params:hide(i .. "density")
    params:hide(i .. "pitch")
    params:hide(i .. "spread")
    params:hide(i .. "fade")
  end
  
  -- Define the pitch root and scale parameters.
  local note_names = {"C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B"}
  params:add_option("pitch_root", "pitch root", note_names, 1)
  params:add_option("pitch_scale", "pitch scale", scale_options, 1)

  params:add_separator("transition")
  params:add_option("transition_time", "transition time (ms)", transition_time_options, 10)
  
  params:add_separator("reverb")
  params:add_taper("reverb_mix", "* mix", 0, 100, 50, 0, "%")
  params:set_action("reverb_mix", function(value) engine.reverb_mix(value / 100) end)
  params:add_taper("reverb_room", "* room", 0, 100, 50, 0, "%")
  params:set_action("reverb_room", function(value) engine.reverb_room(value / 100) end)
  params:add_taper("reverb_damp", "* damp", 0, 100, 50, 0, "%")
  params:set_action("reverb_damp", function(value) engine.reverb_damp(value / 100) end)
  
  params:add_separator("randomizer")
  params:add_taper("min_jitter", "jitter (min)", 0, 2000, 0, 5, "ms")
  params:add_taper("max_jitter", "jitter (max)", 0, 2000, 500, 5, "ms")
  params:add_taper("min_size", "size (min)", 1, 500, 1, 5, "ms")
  params:add_taper("max_size", "size (max)", 1, 500, 500, 5, "ms")
  params:add_taper("min_density", "density (min)", 0, 512, 0, 6, "hz")
  params:add_taper("max_density", "density (max)", 0, 512, 40, 6, "hz")
  params:add_taper("min_spread", "spread (min)", 0, 100, 0, 0, "%")
  params:add_taper("max_spread", "spread (max)", 0, 100, 100, 0, "%")
  params:add_taper("pitch_1", "pitch (1)", -48, 48, -12, 0, "st")
  params:add_taper("pitch_2", "pitch (2)", -48, 48, -5, 0, "st")
  params:add_taper("pitch_3", "pitch (3)", -48, 48, 0, 0, "st")
  params:add_taper("pitch_4", "pitch (4)", -48, 48, 7, 0, "st")
  params:add_taper("pitch_5", "pitch (5)", -48, 48, 12, 0, "st")
  
  params:bang()
end

local function random_float(l, h)
    return l + math.random()  * (h - l);
end

local function randomize(n)
  local transition_duration = transition_time_options[ params:get("transition_time") ] / 1000
  
  local new_jitter  = random_float(params:get("min_jitter"), params:get("max_jitter"))
  local new_size    = random_float(params:get("min_size"), params:get("max_size"))
  local new_density = random_float(params:get("min_density"), params:get("max_density"))
  local new_spread  = random_float(params:get("min_spread"), params:get("max_spread"))
  
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
  
  local random_interval = allowed[ math.random(#allowed) ]
  local new_pitch = root_offset + random_interval
  
  smooth_transition(n .. "jitter", new_jitter, transition_duration)
  smooth_transition(n .. "size", new_size, transition_duration)
  smooth_transition(n .. "density", new_density, transition_duration)
  smooth_transition(n .. "spread", new_spread, transition_duration)
  
  params:set(n .. "pitch", new_pitch)
end

local function transition_to_new_state()
  local transition_duration = transition_time_options[ params:get("transition_time") ] / 1000
  
  -- Choose a new slot that is not the active one.
  local candidates = {}
  for i = 1, 3 do
    if i ~= active_slot then
      table.insert(candidates, i)
    end
  end
  local new_slot = candidates[ math.random(#candidates) ]
  
  -- Ensure the new slot is gated on and force its volume to -60 dB.
  engine.gate(new_slot, 1)
  params:set(tostring(new_slot) .. "volume", -60)
  
  local granular_params = {"jitter", "size", "density", "spread"}
  for _, pname in ipairs(granular_params) do
    local cur_val = params:get(tostring(active_slot) .. pname)
    params:set(tostring(new_slot) .. pname, cur_val)
  end
  
  -- Compute new random target values for the granular parameters.
  local new_jitter  = random_float(params:get("min_jitter"), params:get("max_jitter"))
  local new_size    = random_float(params:get("min_size"), params:get("max_size"))
  local new_density = random_float(params:get("min_density"), params:get("max_density"))
  local new_spread  = random_float(params:get("min_spread"), params:get("max_spread"))
  
  -- Compute the new pitch target immediately.
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
  local random_interval = allowed[ math.random(#allowed) ]
  local new_pitch = root_offset + random_interval
  
  -- Crossfade the granular parameters (excluding pitch) in the new slot.
  smooth_transition(tostring(new_slot) .. "jitter", new_jitter, transition_duration)
  smooth_transition(tostring(new_slot) .. "size", new_size, transition_duration)
  smooth_transition(tostring(new_slot) .. "density", new_density, transition_duration)
  smooth_transition(tostring(new_slot) .. "spread", new_spread, transition_duration)
  
  -- Immediately update pitch (no transition).
  params:set(tostring(new_slot) .. "pitch", new_pitch)
  
  -- Define phase durations: phase 1 (fast fade–in up to –7 dB) and phase 2 (the remaining time).
  local phase1_time = transition_duration * 0.2
  local phase2_time = transition_duration - phase1_time
  
  -- Phase 1: Fade new slot from -60 dB to -7 dB using an ease–out curve.
  clock.run(function()
    local start_db = -60
    local mid_db = -7
    local steps = 30
    local dt = phase1_time / steps
    for i = 1, steps do
      local t = i / steps
      local factor = 1 - (1 - t)^2  -- ease–out
      local new_db = start_db + (mid_db - start_db) * factor
      params:set(tostring(new_slot) .. "volume", new_db)
      clock.sleep(dt)
    end
    params:set(tostring(new_slot) .. "volume", mid_db)
    
    -- Once the new slot reaches -7 dB, trigger Phase 2 concurrently:
    -- Phase 2a: Fade out the active slot from 0 dB to -60 dB (ease–in).
    clock.run(function()
      local start_db_out = 0
      local end_db_out = -60
      local steps2 = 30
      local dt2 = phase2_time / steps2
      for j = 1, steps2 do
        local t2 = j / steps2
        local factor2 = t2^2  -- ease–in
        local new_db_out = start_db_out + (end_db_out - start_db_out) * factor2
        params:set(tostring(active_slot) .. "volume", new_db_out)
        clock.sleep(dt2)
      end
      params:set(tostring(active_slot) .. "volume", end_db_out)
    end)
    -- Phase 2b: Continue fading in the new slot from -7 dB to 0 dB (ease–out).
    clock.run(function()
      local start_db_in = -7
      local end_db_in = 0
      local steps2 = 30
      local dt2 = phase2_time / steps2
      for j = 1, steps2 do
        local t2 = j / steps2
        local factor2 = 1 - (1 - t2)^2  -- ease–out
        local new_db_in = start_db_in + (end_db_in - start_db_in) * factor2
        params:set(tostring(new_slot) .. "volume", new_db_in)
        clock.sleep(dt2)
      end
      params:set(tostring(new_slot) .. "volume", end_db_in)
    end)
  end)
  
  -- Save the current active slot into a local variable, then update active_slot.
  local old_slot = active_slot
  active_slot = new_slot
  
  -- After the full transition, gate off the old slot.
  clock.run(function()
    clock.sleep(transition_duration)
    engine.gate(old_slot, 0)
  end)
end


local function setup_engine()
  engine.seek(1, 0)
  engine.gate(1, 1)
  params:set("1volume", 0)    -- Slot 1 is active (0 dB)

  engine.seek(2, 0)
  engine.gate(2, 1)
  params:set("2volume", -60)  -- Inactive

  engine.seek(3, 1)
  engine.gate(3, 1)
  params:set("3volume", -60)  -- Inactive

  randomize(1)
  randomize(2)
  randomize(3)

  active_slot = 1
end

local key1_hold = false
local key2_hold = false

function key(n, z)
  if z == 0 then
    if n == 1 then key1_hold = false end
    if n == 2 then key2_hold = false end
    return
  end

  if n == 1 then
    key1_hold = true
    clock.run(function()
      clock.sleep(1) -- long press for key 1
      if key1_hold then
        randomize(3)
      end
    end)
  elseif n == 2 then
    key2_hold = true
    clock.run(function()
      clock.sleep(1) -- long press for key 2
      if key2_hold then
        transition_to_new_state()
      end
    end)
  elseif n == 3 then
    randomize(2)
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
  elseif n == 4 then
    params:delta("3seek", d)
  end
end

function redraw()
  screen.clear()
  screen.move(0, 10)
  screen.level(15)
  screen.text("J:")
  screen.level(5)
  screen.text(params:string("1jitter"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2jitter"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3jitter"))
  screen.move(0, 20)
  screen.level(15)
  screen.text("Sz:")
  screen.level(5)
  screen.text(params:string("1size"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2size"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3size"))
  screen.move(0, 30)
  screen.level(15)
  screen.text("D:")
  screen.level(5)
  screen.text(params:string("1density"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2density"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3density"))
  screen.move(0, 40)
  screen.level(15)
  screen.text("Sp:")
  screen.level(5)
  screen.text(params:string("1spread"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2spread"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3spread"))
  screen.move(0, 50)
  screen.level(15)
  screen.text("P:")
  screen.level(5)
  screen.text(params:string("1pitch"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2pitch"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3pitch"))
  screen.move(0, 60)
  screen.level(15)
  screen.text("Sk:")
  screen.level(5)
  screen.text(params:string("1seek"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("2seek"))
  screen.level(1)
  screen.text(" / ")
  screen.level(5)
  screen.text(params:string("3seek"))
  screen.update()
end

function init()
  setup_ui_metro()
  setup_params()
  setup_engine()
end
