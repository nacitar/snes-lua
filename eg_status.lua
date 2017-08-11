local ram = require 'ram'
local util = require 'util'

local var = {
  -- can be > 1 if it's queued and then you jump... code just adds 1 to it for
  -- some reason, rather than setting to 1 like a bool
  queued_layer_change = ram.Unsigned(0x7E047A, 2),
  room_upper_layer = ram.Unsigned(0x7E044A, 2),
  player_state = ram.Unsigned(0x7E005D, 1),
}

local PlayerStateFlags = {
  JUMPING = 6,
}

local StoredEG = {
  DISARMED = 0,
  STRONG = 1,
  WEAK = 2,
}

local stored_eg = nil
local last_player_state = nil
function update_stored_eg()
  player_state = var.player_state:read()
  if last_player_state ~= nil then
    queued_layer_change = var.queued_layer_change:read()
    -- if we jump when we already have stored EG, the count will be > 1, keep
    -- the indicator in that case... but if it is only 1, we need to make sure
    -- it's not just a normal jump.  Also, the last frame of a jump to the
    -- ground swaps the state one frame prior to clearing the
    -- queued_layer_change, so we have to backlog one frame. =/
    if queued_layer_change > 1 or (queued_layer_change == 1 and
        last_player_state ~= nil and
        last_player_state ~= PlayerStateFlags.JUMPING and
        player_state ~= PlayerStateFlags.JUMPING) then
      room_upper_layer = var.room_upper_layer:read()
      if room_upper_layer == 1 then
        stored_eg = StoredEG.STRONG
      else
        stored_eg = StoredEG.WEAK
      end
    else
      stored_eg = StoredEG.DISARMED
    end
  end
  last_player_state = player_state
end

function main()
  update_stored_eg()
end

function stored_eg_string()
  if stored_eg == StoredEG.STRONG then
    return 'strong'
  elseif stored_eg == StoredEG.WEAK then
    return 'weak'
  elseif stored_eg == StoredEG.DISARMED then
    return 'disarmed'
  end
  return ''
end

local function draw_text(base_x, base_y, lines)
  for i, line in pairs(lines) do
    local y = base_y + (8 * (i - 1))
    gui.text(base_x, y, line)
  end
end

while true do
  main()
  status = stored_eg_string()
  draw_text(2, 120, {'Stored EG: ' .. status})
  snes9x.frameadvance()
end
