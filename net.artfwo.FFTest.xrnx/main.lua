--[[============================================================================
main.lua
============================================================================]]--

--------------------------------------------------------------------------------
-- menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Sample Editor:FFTest",
  invoke = function()
    test_fft()
  end
}

--------------------------------------------------------------------------------
-- key bindings
--------------------------------------------------------------------------------

renoise.tool():add_keybinding {
  name = "Sample Editor:Process:FFTest",
  invoke = function(repeated)
    if (not repeated) then -- we ignore soft repeated keys here
      test_fft()
    end
  end
}

--------------------------------------------------------------------------------
-- functions
--------------------------------------------------------------------------------

function test_fft()
  local frames = renoise.song().selected_sample.sample_buffer.number_of_frames
  local size = next_possible_size(frames)
  local frequency = renoise.song().selected_sample.sample_buffer.sample_rate
  local signal = {}
  
  for i = 1, frames do
    signal[i] = renoise.song().selected_sample.sample_buffer:sample_data(1, i)
  end
  
  process(signal)
  
  return
end

--[[============================================================================
FFT stuff below
============================================================================]]--

local WINSIZE = 2048
--local HALFWIN = WINSIZE/2

require "math"
luafft = require "luafft"

--------------------------------------------------------------------------------
-- envelopes and helpers
--------------------------------------------------------------------------------

envelope = {}

envelope.hann = function(size)
  local env = {}
  for i = 1, size do
    env[i] = 0.5 * (1 - math.cos(2 * math.pi * (i - 1) / (size - 1)))
  end
  return env
end

envelope.tri = function(size)
  local env = {}
  for i = 1, size do
    env[i] = 2 / (size - 1) * ((size - 1) / 2 - math.abs((i - 1) - (size - 1) / 2))
  end
  return env
end

function peak_freq(spec)
  local res = {1, spec[1]:abs()}
  for i, v in ipairs(spec) do 
    local w = v:abs()
    if res[2] < w then
      res[1] = i
      res[2] = w
    end
  end
  return res[1] / WINSIZE * 44100 --<< gotta replace this with the real SR
end

--------------------------------------------------------------------------------
-- process
--------------------------------------------------------------------------------

function process(sample_data)
  local env = envelope.hann(WINSIZE)
  local origsize = #sample_data

  -- zero-pad data to winsize
  if #sample_data % WINSIZE ~= 0 then
    local padsize = #sample_data - (#sample_data % WINSIZE) + WINSIZE
    for i = #sample_data + 1, padsize do
      sample_data[i] = 0
    end
  end

  -- FIXME first and last half-windows are not properly processed
  local result = {}
  for i = 1, #sample_data do
    result[i] = 0
  end

  for i = 1, #sample_data - WINSIZE / 2, WINSIZE / 2 do
    -- get the slice [i:i+WINSIZE-1]
    local k = 1
    local slice = {}
    for j = i, i + WINSIZE - 1 do
      slice[k] = complex.new(sample_data[j] * env[k], 0)
      k = k + 1
    end

    -- begin FFT --
    local spectrum = fft(slice, false)
    print("peak frequency:", peak_freq(spectrum, 44100))
    -- end FFT ---
    
    -- overlap-add the slice back
    for j = 1, #slice do
      result[i + j - 1] = result[i + j - 1] + slice[j]
    end
  end
  print("--- finished ---")
end
