--[[============================================================================
main.lua
============================================================================]]--

SOX = ({
  LINUX = "sox",
  WINDOWS = "bin\\windows\\sox.exe",
  MACINTOSH = "bin/mac/sox"
})[os.platform()]

NOISE_PROFILE = nil
NOISE_PROFILE_CHANNELS = 0

-- not currently using remix, because SoX dislikes noise profiles
-- when their number of channels differs from the processed sample
REMIX_MAP = {
  'remix 1',
  'remix 2',
  'remix 1 2'
}

--------------------------------------------------------------------------------
-- preferences
--------------------------------------------------------------------------------

local options = renoise.Document.create("NoiseReductionPreferences") {
  amount = 0.2
}

renoise.tool().preferences = options
  
--------------------------------------------------------------------------------
-- menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Sample Editor:Process:Create Noise Profile",
  invoke = function()
    create_noise_profile()
  end
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Process:Remove Noise...",
  active = function()
    return can_remove_noise()
  end,
  invoke = function() 
    remove_noise_dialog()
  end
}

--------------------------------------------------------------------------------
-- key bindings
--------------------------------------------------------------------------------

renoise.tool():add_keybinding {
  name = "Sample Editor:Process:Create Noise Profile",
  invoke = function(repeated)
    if (not repeated) then -- we ignore soft repeated keys here
      create_noise_profile()
    end
  end
}

renoise.tool():add_keybinding {
  name = "Sample Editor:Process:Remove Noise...",
  invoke = function(repeated)
    if (not repeated) then -- we ignore soft repeated keys here
      remove_noise_dialog()
    end
  end
}

renoise.tool():add_keybinding {
  name = "Sample Editor:Process:Remove Noise (non-interactive)",
  invoke = function(repeated)
    if (not repeated) then -- we ignore soft repeated keys here
      remove_noise()
    end
  end
}

--------------------------------------------------------------------------------
-- functions
--------------------------------------------------------------------------------

function can_remove_noise()
  return (NOISE_PROFILE ~= nil and renoise.song().selected_sample.sample_buffer.number_of_channels == NOISE_PROFILE_CHANNELS)
end

function create_noise_profile()
  if NOISE_PROFILE == nil then
    NOISE_PROFILE = os.tmpname('noise-profile')  
  end
  
  local tmpfile = os.tmpname('wav')
  renoise.song().selected_sample.sample_buffer:save_as(tmpfile, 'wav')
  
  local cmd = string.format("%s %s -n trim %ds %ds noiseprof %s",
    SOX,
    tmpfile,
    renoise.song().selected_sample.sample_buffer.selection_start,
    renoise.song().selected_sample.sample_buffer.selection_end,
    NOISE_PROFILE)
  
  os.execute(cmd)
  os.remove(tmpfile)
  NOISE_PROFILE_CHANNELS = renoise.song().selected_sample.sample_buffer.number_of_channels
end

function remove_noise_dialog()
  -- just a 2nd check in case the function is triggered by a shortcut
  if not can_remove_noise() then
    return
  end

  local amount_value = options.amount.value

  local vb = renoise.ViewBuilder()
  local dialog_content = vb:column {
    margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
    vb:row {
      spacing = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
      vb:text {
        text = "Amount"
      },
      vb:slider {
        min = 0.0,
        max = 1.0,
        value = amount_value,
        notifier = function(slider_value)
          amount_value = slider_value
          vb.views.amount_label.text = ("%.2f"):format(amount_value)
        end
      },
      vb:text {
        id = "amount_label",
        text = ("%.2f"):format(amount_value)
      }
    }
  }

  local dialog_response = renoise.app():show_custom_prompt("Noise Reduction",
    dialog_content,
    {"Process", "Cancel"})

  if dialog_response == "Process" then
    options.amount.value = amount_value
    remove_noise()
  end
end

function remove_noise()
  -- just a 2nd check in case the function is triggered by a shortcut
  if not can_remove_noise() then
    return
  end
  
  local origfile = os.tmpname('wav')
  local cleanfile = os.tmpname('wav')
  renoise.song().selected_sample.sample_buffer:save_as(origfile, 'wav')
  
  local cmd = string.format("%s %s %s noisered %s %f",
    SOX,
    origfile,
    cleanfile,
    NOISE_PROFILE,
    options.amount.value)
  
  os.execute(cmd)
  renoise.song().selected_sample.sample_buffer:load_from(cleanfile)
  
  os.remove(origfile)
  os.remove(cleanfile)
end
