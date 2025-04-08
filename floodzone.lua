-- FLOODZONE
-- v.20250408
-- by @nzimas
-- based on Twine by: @cfd90
--
-- Long-press K2 to trig trans
-- Short-press K2 to rnd slot 1
-- Short-press K3 to rnd slot 2
-- Long-press K1 to rnd slot 3
-- Tweak loads of rnd params in EDIT menu
-- Hold K3 to trig harmonies

engine.name = "GlutXtd"

----------------------------------------------------------------
-- 1) GLOBALS & HELPERS
----------------------------------------------------------------

local function file_dir_name(fullpath)
  local dir = string.match(fullpath, "^(.*)/[^/]*$")
  return dir or fullpath
end

local fill_levels = {1,0,0} -- fill states for UI squares
local sample_dir  = _path.audio  -- user-chosen folder
local last_old_slot_for_k2 = 1   -- used if we randomize the "old slot" on K2 release

-- For "ping-pong" direction, we'll maintain a small Metro that toggles speed
local pingpong_metros = {nil, nil, nil}  -- one for each of the 3 main slots
-- We'll store the current sign (+1 or -1) for each slot if it's in ping-pong mode
local pingpong_sign   = {1,1,1}

-- Square geometry
local square_size = 30
local square_y    = 15
local square_x    = {10, 49, 88}

local ui_metro
local random_seek_metros = {nil, nil, nil}
local active_slot = 1

-- For short vs long press logic
local key1_hold = false
local key2_hold = false
local key3_hold = false

local scale_options = {"dorian", "natural minor", "harmonic minor", "melodic minor",
                       "major", "locrian", "phrygian"}
local scales = {
  dorian         = {0, 2, 3, 5, 7, 9, 10},
  ["natural minor"]  = {0, 2, 3, 5, 7, 8, 10},
  ["harmonic minor"] = {0, 2, 3, 5, 7, 8, 11},
  ["melodic minor"]  = {0, 2, 3, 5, 7, 9, 11},
  major          = {0, 2, 4, 5, 7, 9, 11},
  locrian        = {0, 1, 3, 5, 6, 8, 10},
  phrygian       = {0, 1, 3, 5, 7, 8, 10}
}

-- Transition time (ms) options
local transition_time_options = {}
for t = 100, 1000, 100 do
  table.insert(transition_time_options, t)
end
for t = 1500, 90000, 500 do
  table.insert(transition_time_options, t)
end

-- Morph time (ms) options
local morph_time_options = {}
for t = 0, 90000, 500 do
  table.insert(morph_time_options, t)
end

----------------------------------------------------------------
-- 2) UI METRO & UTILS
----------------------------------------------------------------

local function setup_ui_metro()
  ui_metro = metro.init()
  ui_metro.time = 1/15
  ui_metro.event = function()
    redraw()
  end
  ui_metro:start()
end

-- Simple smoothing param setter
local function smooth_transition(param_name, new_val, duration)
  clock.run(function()
    local start_val = params:get(param_name)
    local steps = 60
    local dt    = duration / steps
    for i=1, steps do
      local t = i / steps
      local interp = start_val + (new_val - start_val)*t
      params:set(param_name, interp)
      clock.sleep(dt)
    end
    params:set(param_name, new_val)
  end)
end

----------------------------------------------------------------
-- 3) RANDOM UTILS
----------------------------------------------------------------

local function random_float(l, h)
  return l + math.random()*(h - l)
end

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
       string.match(lower_f, "%.flac$" ) then
      table.insert(audio_files, dir.."/"..f)
    end
  end
  if #audio_files>0 then
    return audio_files[ math.random(#audio_files) ]
  else
    return nil
  end
end

----------------------------------------------------------------
-- 4) ENGINE / PLAYHEAD / PING-PONG LOGIC
----------------------------------------------------------------

-- Called whenever "playhead_rate" or "playhead_direction" changes
local function update_playhead(i)
  local rate = params:get(i.."playhead_rate")
  local dir  = params:get(i.."playhead_direction")
  if pingpong_metros[i] ~= nil then
    pingpong_metros[i]:stop()
    pingpong_metros[i] = nil
    pingpong_sign[i]   = 1
  end

  if dir == 1 then
    -- forward => speed = +rate
    engine.speed(i, rate)
  elseif dir == 2 then
    -- backward => speed = -rate
    engine.speed(i, -rate)
  else
    -- ping-pong => toggle sign every 2s
    pingpong_metros[i] = metro.init()
    pingpong_metros[i].time = 2.0
    pingpong_metros[i].event = function()
      pingpong_sign[i] = -pingpong_sign[i]
      engine.speed(i, pingpong_sign[i]*rate)
    end
    pingpong_metros[i]:start()
    engine.speed(i, rate)
  end
end

local function get_random_pitch(slot)
  local s = tostring(slot)
  local root_offset = params:get("pitch_root") - 1
  local scale_index = params:get("pitch_scale")
  local selected_scale = scale_options[scale_index]
  local base_intervals = scales[selected_scale]

  local min_offset = tonumber(params:string(s.."pitch_rng_min"))
  local max_offset = tonumber(params:string(s.."pitch_rng_max"))
  if min_offset > max_offset then
    min_offset = max_offset
  end

  local current_pitch = params:get(s.."pitch")
  local current_offset = current_pitch - root_offset

  local allowed_pitches = {}
  for _, interval in ipairs(base_intervals) do
    local semitone_offsets = {interval - 12, interval, interval + 12}
    for _, semitone_offset in ipairs(semitone_offsets) do
      if semitone_offset >= min_offset and semitone_offset <= max_offset then
        table.insert(allowed_pitches, semitone_offset)
      end
    end
  end

  if #allowed_pitches > 1 then
    for i, v in ipairs(allowed_pitches) do
      if v == current_offset then
        table.remove(allowed_pitches, i)
        break
      end
    end
  end

  if #allowed_pitches > 0 then
    local chosen_offset = allowed_pitches[math.random(#allowed_pitches)]
    return root_offset + chosen_offset
  else
    return root_offset
  end
end

local function get_harmony_pitch(slot)
  local s = tostring(slot)
  local active_pitch = params:get(active_slot.."pitch")

  local min_offset = tonumber(params:string(s.."pitch_rng_min"))
  local max_offset = tonumber(params:string(s.."pitch_rng_max"))
  if min_offset > max_offset then
    min_offset = max_offset
  end

  local scale_index = params:get("pitch_scale")
  local selected_scale = scale_options[scale_index]
  local base_intervals = scales[selected_scale]

  local allowed_offsets = {}
  for _, interval in ipairs(base_intervals) do
    for _, shift in ipairs({-12, 0, 12}) do
      local candidate = interval + shift
      if candidate >= min_offset and candidate <= max_offset then
        table.insert(allowed_offsets, candidate)
      end
    end
  end

  if #allowed_offsets > 1 then
    for i, v in ipairs(allowed_offsets) do
      if v == active_pitch then
        table.remove(allowed_offsets, i)
        break
      end
    end
  end

  if #allowed_offsets > 0 then
    local chosen_offset = allowed_offsets[math.random(#allowed_offsets)]
    return chosen_offset
  else
    return active_pitch
  end
end

----------------------------------------------------------------
-- 5) PARAM DEFINITIONS
----------------------------------------------------------------

local function setup_params()
  params:add_separator("random sample")

  params:add_option("random_sample", "random sample?", {"no", "yes"}, 1)
  params:add_file("sample_dir", "sample directory")
  params:set_action("sample_dir", function(file)
    if file~="" then
      local folder = file_dir_name(file)
      if folder then
        sample_dir = folder
        print("sample_dir => "..sample_dir)
      end
    end
  end)

  params:add_separator("samples")
  for i=1,3 do
    params:add_file(i.."sample", i.." sample")
    params:set_action(i.."sample", function(file) engine.read(i,file) end)

    params:add_control(i.."playhead_rate", i.." playhead rate",
      controlspec.new(0, 4, "lin", 0.01, 1.0, "", 0.01/4))
    params:set_action(i.."playhead_rate", function(v)
      update_playhead(i)
    end)

    params:add_option(i.."playhead_direction", i.." direction",{">>","<<","<->"},1)
    params:set_action(i.."playhead_direction", function(d)
      update_playhead(i)
    end)

    params:add_taper(i.."volume", i.." volume", -60, 20, 0, 0, "dB")
    params:set_action(i.."volume", function(v) engine.volume(i, math.pow(10, v/20)) end)

    params:add_taper(i.."jitter", i.." jitter", 0,2000,0,5,"ms")
    params:set_action(i.."jitter", function(val) engine.jitter(i, val/1000) end)

    params:add_taper(i.."size", i.." size", 1,500,100,5,"ms")
    params:set_action(i.."size", function(val) engine.size(i, val/1000) end)

    params:add_taper(i.."density", i.." density", 0,512,20,6,"hz")
    params:set_action(i.."density", function(val) engine.density(i,val) end)

    params:add_taper(i.."pitch", i.." pitch", -48,48,0,0,"st")
    params:set_action(i.."pitch", function(val) engine.pitch(i, math.pow(0.5, -val/12)) end)

    params:add_taper(i.."spread", i.." spread", 0,100,0,0,"%")
    params:set_action(i.."spread", function(val) engine.spread(i, val/100) end)

    params:add_taper(i.."fade", i.." att / dec", 1,9000,1000,3,"ms")
    params:set_action(i.."fade", function(val) engine.envscale(i, val/1000) end)

    params:add_control(i.."seek", i.." seek",
      controlspec.new(0,100,"lin",0.1,(i==3)and 100 or 0, "%", 0.1/100))
    params:set_action(i.."seek", function(val) engine.seek(i, val/100) end)

    params:add_option(i.."random_seek", i.." randomize seek", {"off","on"},1)
    params:add_control(i.."random_seek_freq_min", i.." rnd seek frq min",
      controlspec.new(100, 30000, "lin", 100, 500, "ms", 0.00333))
    params:add_control(i.."random_seek_freq_max", i.." rnd seek frq max",
      controlspec.new(100, 30000, "lin", 100, 2000, "ms", 0.00333))

    params:set_action(i.."random_seek_freq_min", function(val)
      local max_val = params:get(i.."random_seek_freq_max")
      if val > max_val then
        return max_val
      else
        return val
      end
    end)

    params:set_action(i.."random_seek_freq_max", function(val)
      local min_val = params:get(i.."random_seek_freq_min")
      if val < min_val then
        return min_val
      else
        return val
      end
    end)

    params:set_action(i.."random_seek", function(val)
      if val == 2 then
        if random_seek_metros[i] == nil then
          random_seek_metros[i] = metro.init()
          random_seek_metros[i].event = function()
            params:set(i.."seek", math.random()*100)
            local tmin = params:get(i.."random_seek_freq_min")
            local tmax = params:get(i.."random_seek_freq_max")
            if tmax < tmin then
              local temp = tmin
              tmin = tmax
              tmax = temp
            end
            local next_interval = math.random(tmin, tmax)
            random_seek_metros[i].time = next_interval / 1000
            random_seek_metros[i]:start()
          end
        end
        random_seek_metros[i].time = 0.1
        random_seek_metros[i]:start()
      else
        if random_seek_metros[i] ~= nil then
          random_seek_metros[i]:stop()
        end
      end
    end)

    local function refresh_random_seek(k)
      if params:get(k.."random_seek") == 2 and random_seek_metros[k]~=nil then
        random_seek_metros[k]:stop()
        random_seek_metros[k].time = 0.1
        random_seek_metros[k]:start()
      end
    end
    params:set_action(i.."random_seek_freq_min", function() refresh_random_seek(i) end)
    params:set_action(i.."random_seek_freq_max", function() refresh_random_seek(i) end)

    params:add_option(i.."pitch_change", i.." pitch change?", {"no","yes"}, 2)

    -- pitch range
    local pitch_rng_values = {}
    for v = -24, 24 do
      table.insert(pitch_rng_values, v)
    end
    local pitch_rng_strings = {}
    for _, v in ipairs(pitch_rng_values) do
      table.insert(pitch_rng_strings, tostring(v))
    end

    params:add_option(i.."pitch_rng_min", i.." pitch rng min", pitch_rng_strings, 25)
    params:add_option(i.."pitch_rng_max", i.." pitch rng max", pitch_rng_strings, 25)

    params:set_action(i.."pitch_rng_min", function(idx)
      local min_val = pitch_rng_values[idx]
      local max_idx = params:get(i.."pitch_rng_max")
      local max_val = pitch_rng_values[max_idx]
      if min_val > max_val then
        params:set(i.."pitch_rng_min", max_idx)
      end
    end)

    params:set_action(i.."pitch_rng_max", function(idx)
      local max_val = pitch_rng_values[idx]
      local min_idx = params:get(i.."pitch_rng_min")
      local min_val = pitch_rng_values[min_idx]
      if max_val < min_val then
        params:set(i.."pitch_rng_max", min_idx)
      end
    end)

    -- filter-change param (the new “random filter?”)
    params:add_option(i.."filter_change", i.." random filter?", {"no","yes"}, 1)

    -- actual filter cutoff & Q per slot
    params:add_taper(i.."filter_cutoff", i.." filter cutoff", 20, 20000, 8000, 0, "Hz")
    params:set_action(i.."filter_cutoff", function(val) engine.filterCutoff(i, val) end)

    params:add_taper(i.."filter_q", i.." filter Q", 0.1, 4.0, 0.5, 0, "")
    params:set_action(i.."filter_q", function(val) engine.filterRQ(i, val) end)
  end

  params:add_separator("key & scale")
  local note_names = {"C","C#/Db","D","D#/Eb","E","F","F#/Gb","G","G#/Ab","A","A#/Bb","B"}
  params:add_option("pitch_root", "root note", note_names, 1)
  params:add_option("pitch_scale","scale", scale_options, 1)

  params:add_separator("transition")
  params:add_option("transition_time","transition time (ms)", transition_time_options,10)
  params:add_option("morph_time","morph time (ms)", morph_time_options,1)
  params:set_action("morph_time", function(idx)
    local chosen_morph = morph_time_options[idx]
    local trans_ms     = transition_time_options[ params:get("transition_time") ]
    if chosen_morph>trans_ms then
      local best_index=1
      for i=1,#morph_time_options do
        if morph_time_options[i]<=trans_ms then
          best_index=i
        end
      end
      params:set("morph_time", best_index)
    end
  end)

  params:add_option("k2_release_action","K2 release",{"no change","randomize"},1)

  ---------------------------------------------------------------
  -- [NEW] DELAY & DECIMATOR SECTION (Engine_GlutXtd supports these)
  ---------------------------------------------------------------
  params:add_separator("delay")

  -- Delay times up to 2 seconds (the engine's default maxDelay is 2.0)
  params:add_taper("delay_time",     "delay time",     0.0, 2.0, 0.5, 0, "s")
  params:set_action("delay_time",     function(v) engine.delay_time(v) end)

  -- Feedback is typically 0..1 (or 0..100%), default 0.5
  params:add_taper("delay_feedback", "delay feedback", 0,   1,   0.5, 0, "")
  params:set_action("delay_feedback", function(v) engine.delay_feedback(v) end)

  -- Mix also typically 0..1, default 0.5
  params:add_taper("delay_mix",      "delay mix",      0,   1,   0.5, 0, "")
  params:set_action("delay_mix",      function(v) engine.delay_mix(v) end)

  -- Decimator parameters
  params:add_separator("decimator")
  params:add_taper("decimator_rate", "decimator rate",  100, 44100, 44100, 0, "Hz")
  params:set_action("decimator_rate", function(v) engine.decimator_rate(v) end)

  params:add_taper("decimator_bits", "decimator bits",  1,   24,    24,    0, "")
  params:set_action("decimator_bits", function(v) engine.decimator_bits(v) end)

  params:add_control("decimator_mul", "decimator mul",
    controlspec.new(0.0,10.0,"lin",0,1.0,""))
  params:set_action("decimator_mul",  function(v) engine.decimator_mul(v) end)

  params:add_control("decimator_add", "decimator add",
    controlspec.new(-10,10,"lin",0,0,""))
  params:set_action("decimator_add",  function(v) engine.decimator_add(v) end)

  ---------------------------------------------------------------
  -- [MIN/MAX RANGES FOR THE RANDOMIZER]
  ---------------------------------------------------------------
  params:add_separator("randomizer")
  params:add_taper("min_jitter", "jitter (min)", 0,2000,0,5,"ms")
  params:add_taper("max_jitter", "jitter (max)", 0,2000,500,5,"ms")
  params:add_taper("min_size",   "size (min)",   1,500,1,5,"ms")
  params:add_taper("max_size",   "size (max)",   1,500,500,5,"ms")
  params:add_taper("min_density","density (min)",0,512,0,6,"hz")
  params:add_taper("max_density","density (max)",0,512,40,6,"hz")
  params:add_taper("min_spread", "spread (min)",0,100,0,0,"%")
  params:add_taper("max_spread", "spread (max)",0,100,100,0,"%")

  -- filter randomization ranges
  params:add_taper("min_filter_cutoff", "filter cutoff (min)",  20, 20000, 500, 0, "Hz")
  params:add_taper("max_filter_cutoff", "filter cutoff (max)",  20, 20000, 8000,0, "Hz")
  params:add_taper("min_filter_q", "filter Q (min)",  0.1, 4.0, 0.25, 0, "")
  params:add_taper("max_filter_q", "filter Q (max)",  0.1, 4.0, 1.2,  0, "")

  -- The five older “pitch_x”
  params:add_taper("pitch_1","pitch (1)",-48,48,-12,0,"st")
  params:add_taper("pitch_2","pitch (2)",-48,48,-5, 0,"st")
  params:add_taper("pitch_3","pitch (3)",-48,48, 0, 0,"st")
  params:add_taper("pitch_4","pitch (4)",-48,48, 7, 0,"st")
  params:add_taper("pitch_5","pitch (5)",-48,48,12,0,"st")

  ----------------------------------------------------------------
  -- HARMONY
  ----------------------------------------------------------------
  params:add_separator("harmony")

  params:add_taper("A_volume", "A - volume", -60, 20, -12, 0, "dB")
  params:add_control("A_pan",   "A - pan", controlspec.new(-1, 1, "lin", 0, 0, ""))
  params:add_control("A_fade_in",  "A - fade in time",  controlspec.new(0, 9000, "lin", 1, 500, "ms"))
  params:add_control("A_fade_out", "A - fade out time", controlspec.new(0, 9000, "lin", 1, 500, "ms"))

  params:add_taper("B_volume", "B - volume", -60, 20, -12, 0, "dB")
  params:add_control("B_pan",   "B - pan", controlspec.new(-1, 1, "lin", 0, 0, ""))
  params:add_control("B_fade_in",  "B - fade in time",  controlspec.new(0, 9000, "lin", 1, 500, "ms"))
  params:add_control("B_fade_out", "B - fade out time", controlspec.new(0, 9000, "lin", 1, 500, "ms"))

  params:bang()
end

-- Clamp random_seek min <= max
local random_seek_clamp_metro = metro.init(function()
  for i = 1, 3 do
    local min_val = params:get(i.."random_seek_freq_min")
    local max_val = params:get(i.."random_seek_freq_max")
    if min_val > max_val then
      params:set(i.."random_seek_freq_min", max_val)
    end
  end
end, 0.1)
random_seek_clamp_metro:start()

----------------------------------------------------------------
-- 6) RANDOMIZE + TRANSITION
----------------------------------------------------------------

-- This randomizes either just granular params, or also pitch/filter if user wants.
local function randomize(slot)
  local transition_ms = transition_time_options[params:get("transition_time")]
  local morph_ms      = morph_time_options[params:get("morph_time")]
  local actual_ms     = math.min(morph_ms, transition_ms)
  local morph_duration = actual_ms/1000

  local new_jitter  = random_float(params:get("min_jitter"),  params:get("max_jitter"))
  local new_size    = random_float(params:get("min_size"),    params:get("max_size"))
  local new_density = random_float(params:get("min_density"), params:get("max_density"))
  local new_spread  = random_float(params:get("min_spread"),  params:get("max_spread"))

  if params:get(slot.."pitch_change") == 2 then
    local new_pitch = get_random_pitch(slot)
    params:set(slot.."pitch", new_pitch)
  end

  if params:get(slot.."filter_change") == 2 then
    local new_cutoff = random_float(params:get("min_filter_cutoff"), params:get("max_filter_cutoff"))
    local new_q      = random_float(params:get("min_filter_q"),       params:get("max_filter_q"))
    smooth_transition(slot.."filter_cutoff", new_cutoff, morph_duration)
    smooth_transition(slot.."filter_q",      new_q,      morph_duration)
  end

  smooth_transition(slot.."jitter",  new_jitter,  morph_duration)
  smooth_transition(slot.."size",    new_size,    morph_duration)
  smooth_transition(slot.."density", new_density, morph_duration)
  smooth_transition(slot.."spread",  new_spread,  morph_duration)
end

local function transition_to_new_state()
  local trans_ms      = transition_time_options[params:get("transition_time")]
  local transition_duration = trans_ms/1000

  local old_slot = active_slot
  last_old_slot_for_k2 = old_slot

  -- pick a new slot from the other 2
  local candidates = {}
  for i=1,3 do
    if i~=old_slot then
      table.insert(candidates,i)
    end
  end
  local new_slot = candidates[ math.random(#candidates) ]

  -- random sample load if wanted
  if params:get("random_sample")==2 then
    local rnd_file = pick_random_file(sample_dir)
    if rnd_file then
      print("Loaded random file into slot "..new_slot..": "..rnd_file)
      engine.read(new_slot, rnd_file)
      params:set(new_slot.."sample", rnd_file)
    else
      print("No valid audio in "..sample_dir)
    end
  end

  -- Gate on new slot
  engine.gate(new_slot,1)
  params:set(new_slot.."volume", -60)

  -- Copy old slot's jitter/size/density/spread/filter settings
  local granular_params={"jitter","size","density","spread","filter_cutoff","filter_q"}
  for _,p in ipairs(granular_params) do
    local cur_val = params:get(old_slot..p)
    params:set(new_slot..p, cur_val)
  end

  -- Now pick new random targets
  local new_jitter  = random_float(params:get("min_jitter"),  params:get("max_jitter"))
  local new_size    = random_float(params:get("min_size"),    params:get("max_size"))
  local new_density = random_float(params:get("min_density"), params:get("max_density"))
  local new_spread  = random_float(params:get("min_spread"),  params:get("max_spread"))

  -- We always do a new pitch for transitions => 'harmony'
  local new_pitch = get_harmony_pitch(new_slot)
  params:set(new_slot.."pitch", new_pitch)

  -- Possibly randomize filter if “filter_change” is yes
  local do_filter = (params:get(new_slot.."filter_change") == 2)
  local new_cutoff, new_q
  if do_filter then
    new_cutoff = random_float(params:get("min_filter_cutoff"), params:get("max_filter_cutoff"))
    new_q      = random_float(params:get("min_filter_q"),       params:get("max_filter_q"))
  else
    new_cutoff = params:get(new_slot.."filter_cutoff")
    new_q      = params:get(new_slot.."filter_q")
  end

  -- Smooth transitions
  smooth_transition(new_slot.."jitter",  new_jitter,  transition_duration)
  smooth_transition(new_slot.."size",    new_size,    transition_duration)
  smooth_transition(new_slot.."density", new_density, transition_duration)
  smooth_transition(new_slot.."spread",  new_spread,  transition_duration)

  if do_filter then
    smooth_transition(new_slot.."filter_cutoff", new_cutoff, transition_duration)
    smooth_transition(new_slot.."filter_q",      new_q,      transition_duration)
  end

  -- Volume crossfade
  local phase1_time = transition_duration*0.2
  local phase2_time = transition_duration - phase1_time

  clock.run(function()
    -- fade new slot from -60 => -7
    local start_db = -60
    local mid_db   = -7
    local steps    = 30
    local dt       = phase1_time/steps
    for i=1, steps do
      local t = i/steps
      local factor = 1 - (1 - t)^2
      local new_db = start_db + (mid_db - start_db)*factor
      params:set(new_slot.."volume", new_db)
      clock.sleep(dt)
    end
    params:set(new_slot.."volume", mid_db)

    -- Then crossfade old slot from 0 => -60, new slot from -7 => 0
    clock.run(function()
      local start_db_out=0
      local end_db_out  =-60
      local steps2=30
      local dt2=phase2_time/steps2
      for j=1, steps2 do
        local t2 = j/steps2
        local factor2 = t2^2
        local new_db_out = start_db_out + (end_db_out - start_db_out)*factor2
        params:set(old_slot.."volume", new_db_out)
        clock.sleep(dt2)
      end
      params:set(old_slot.."volume", end_db_out)
    end)

    clock.run(function()
      local start_db_in=-7
      local end_db_in=0
      local steps2=30
      local dt2=phase2_time/steps2
      for j=1, steps2 do
        local t2=j/steps2
        local factor2= 1 - (1 - t2)^2
        local new_db_in= start_db_in+(end_db_in-start_db_in)*factor2
        params:set(new_slot.."volume", new_db_in)
        clock.sleep(dt2)
      end
      params:set(new_slot.."volume", end_db_in)
    end)
  end)

  active_slot = new_slot

  -- squares visual fade
  clock.run(function()
    local steps=60
    local dt   = transition_duration/steps
    for i=1, steps do
      local t = i/steps
      fill_levels[old_slot] = 1 - t
      fill_levels[new_slot] = t
      clock.sleep(dt)
    end
    fill_levels[old_slot]=0
    fill_levels[new_slot]=1
  end)

  -- After crossfade, gate off old slot
  clock.run(function()
    clock.sleep(transition_duration+2)
    engine.gate(old_slot, 0)
  end)
end

----------------------------------------------------------------
-- 7) INIT / KEYS / ENCODERS / REDRAW
----------------------------------------------------------------

local function setup_engine()
  -- Initialize each slot:
  engine.seek(1,0)
  engine.gate(1,1)
  params:set("1volume",0)

  engine.seek(2,0)
  engine.gate(2,1)
  params:set("2volume",-60)

  engine.seek(3,1)
  engine.gate(3,1)
  params:set("3volume",-60)

  for i=1,3 do
    update_playhead(i)
  end

  -- randomize all
  randomize(1)
  randomize(2)
  randomize(3)

  active_slot=1
end

----------------------------------------------------------------
-- 8) HARMONY SLOTS (4 & 5)
----------------------------------------------------------------

local function harmony_randomize(slot)
  local j = random_float(params:get("min_jitter"),  params:get("max_jitter"))
  local s = random_float(params:get("min_size"),    params:get("max_size"))
  local d = random_float(params:get("min_density"), params:get("max_density"))
  local sp= random_float(params:get("min_spread"),  params:get("max_spread"))

  engine.jitter(slot, j/1000)
  engine.size(slot,   s/1000)
  engine.density(slot,d)
  engine.spread(slot, sp/100)

  local active_slot_pitch = params:get(active_slot.."pitch")
  local scale_index = params:get("pitch_scale")
  local selected_scale = scale_options[scale_index]
  local base_intervals = scales[selected_scale]

  local harmony_intervals = {}
  for _, interval in ipairs(base_intervals) do
    table.insert(harmony_intervals, interval - 12)
    table.insert(harmony_intervals, interval)
    if interval == 0 then
      table.insert(harmony_intervals, interval + 12)
    end
  end

  local random_interval = harmony_intervals[math.random(#harmony_intervals)]
  local new_pitch = active_slot_pitch + random_interval
  engine.pitch(slot, math.pow(0.5, -new_pitch / 12))
end

local function setup_harmony_playhead(slot)
  engine.speed(slot, 1)
  engine.seek(slot, 0)
  engine.gate(slot, 0)
end

local function harmony_fade_in(slot, target_dB, fade_ms)
  clock.run(function()
    local steps = 60
    local dt = (fade_ms/1000) / steps
    local start_db = -60
    for i=1, steps do
      local t = i/steps
      local factor = 1 - (1 - t)^2
      local new_db = start_db + (target_dB - start_db)*factor
      engine.volume(slot, math.pow(10, new_db/20))
      clock.sleep(dt)
    end
    engine.volume(slot, math.pow(10, target_dB/20))
  end)
end

local function harmony_fade_out(slot, start_dB, fade_ms)
  clock.run(function()
    local steps = 60
    local dt = (fade_ms/1000) / steps
    for i=1, steps do
      local t = i/steps
      local factor = t^2
      local new_db = start_dB + (-60 - start_dB)*factor
      engine.volume(slot, math.pow(10, new_db/20))
      clock.sleep(dt)
    end
    engine.volume(slot, math.pow(10, -60/20))
    engine.gate(slot, 0)
  end)
end

local function trigger_harmony()
  local file = params:get(active_slot.."sample")
  if type(file)=="string" and file~="" then
    engine.read(4, file)
    engine.read(5, file)
  else
    do return end
  end

  setup_harmony_playhead(4)
  setup_harmony_playhead(5)

  harmony_randomize(4)
  harmony_randomize(5)

  engine.pan(4, params:get("A_pan"))
  engine.pan(5, params:get("B_pan"))

  engine.volume(4, math.pow(10, -60/20))
  engine.volume(5, math.pow(10, -60/20))

  engine.gate(4, 1)
  engine.gate(5, 1)

  local A_target = params:get("A_volume")
  local A_fade   = params:get("A_fade_in")
  local B_target = params:get("B_volume")
  local B_fade   = params:get("B_fade_in")

  harmony_fade_in(4, A_target, A_fade)
  harmony_fade_in(5, B_target, B_fade)
end

local function release_harmony()
  local A_start = params:get("A_volume")
  local B_start = params:get("B_volume")
  local A_out   = params:get("A_fade_out")
  local B_out   = params:get("B_fade_out")

  harmony_fade_out(4, A_start, A_out)
  harmony_fade_out(5, B_start, B_out)
end

----------------------------------------------------------------
-- KEY / ENC / REDRAW
----------------------------------------------------------------

function key(n,z)
  if n==1 then
    if z==1 then
      key1_hold=true
      clock.run(function()
        clock.sleep(1)
        if key1_hold then
          -- long press => random slot 3
          randomize(3)
        end
      end)
    else
      key1_hold=false
    end
  elseif n==2 then
    if z==1 then
      key2_hold=true
      clock.run(function()
        clock.sleep(1)
        if key2_hold==true then
          -- long press => crossfade transition
          transition_to_new_state()
          key2_hold="transition"
        end
      end)
    else
      if key2_hold==true then
        key2_hold=false
        -- short press => random slot 1
        randomize(1)
      elseif key2_hold=="transition" then
        key2_hold=false
        -- if "k2_release_action" == "randomize", randomize old slot
        if params:get("k2_release_action")==2 then
          randomize(last_old_slot_for_k2)
        end
      end
    end
  elseif n==3 then
    if z==1 then
      key3_hold = true
      clock.run(function()
        clock.sleep(1)
        if key3_hold == true then
          -- long press => trigger harmony
          key3_hold = "harmony"
          trigger_harmony()
        end
      end)
    else
      if key3_hold == true then
        key3_hold = false
        -- short press => random slot 2
        randomize(2)
      elseif key3_hold == "harmony" then
        key3_hold = false
        -- release => fade out harmony
        release_harmony()
      end
    end
  end
end

function enc(n,d)
  if n==1 then
    -- global volume offset for slots 1/2/3
    params:delta("1volume",d)
    params:delta("2volume",d)
    params:delta("3volume",d)
  elseif n==2 then
    -- enc2 => adjust slot1's seek
    params:delta("1seek",d)
  elseif n==3 then
    -- enc3 => adjust slot2 + inverse for slot3
    params:delta("2seek",d)
    params:delta("3seek",-d)
  end
end

function redraw()
  screen.clear()
  for i=1,3 do
    local fill = fill_levels[i]
    screen.level(15)
    screen.rect(square_x[i], square_y, square_size, square_size)
    screen.stroke()
    if fill>0 then
      screen.level(10)
      local fill_h = square_size*fill
      local fill_y = square_y + (square_size - fill_h)
      screen.rect(square_x[i], fill_y, square_size, fill_h)
      screen.fill()
    end
  end
  screen.update()
end

function init()
  setup_ui_metro()
  setup_params()
  setup_engine()

  -- harmony placeholders
  setup_harmony_playhead(4)
  setup_harmony_playhead(5)

  fill_levels = {1,0,0}
end
