local ram = require 'ram'
local util = require 'util'


local var = {
  -- can be > 1 if it's queued and then you jump... code just adds 1 to it for
  -- some reason, rather than setting to 1 like a bool
  queued_layer_change = ram.Unsigned(0x7E047A, 2),
  room_upper_layer = ram.Unsigned(0x7E044A, 2),
  falling_state = ram.Unsigned(0x7E005B, 1),
  player_state = ram.Unsigned(0x7E005D, 1),
}
local FallingStateFlags = {
  NORMAL = 0,
  NEAR_PIT = 1,
  FALLING_IN = 2,
  FALLING_OUT = 3,
}
local PlayerStateFlags = {
  FALLING_OR_NEAR_PIT = 1,
  JUMPING = 6,
}


local eg_status = 0

local last_state = nil

function main()
  queued_layer_change = var.queued_layer_change:read()
  player_state = var.player_state:read()
  room_upper_layer = var.room_upper_layer:read()
  if queued_layer_change == 0 then
    eg_status = nil
  else
    falling_state = var.falling_state:read()
    -- the last frame of a jump swaps the state before clearing the queued
    -- layer change value... so we have to ignore the first call for accuracy
    -- sake, as we must check the previous player state.
    -- also, if we're currently jumping or currently falling, don't bother
    -- because we can't be sure of the state
    if last_player_state ~= nil and
        last_player_state ~= PlayerStateFlags.JUMPING and
        player_state ~= PlayerStateFlags.JUMPING and (
        player_state ~= PlayerStateFlags.FALLING_OR_NEAR_PIT or (
          falling_state == FallingStateFlags.NORMAL or
          falling_state == FallingStateFlags.NEAR_PIT)) then
      eg_status = room_upper_layer
    end
  end
  last_player_state = player_state
end

function eg_status_string()
  if eg_status == 1 then
    return 'strong'
  elseif eg_status ~= nil then
    return 'weak'
  end
  return 'disarmed'
end

local function draw_text(base_x, base_y, lines)
  for i, line in pairs(lines) do
    local y = base_y + (8 * (i - 1))
    gui.text(base_x, y, line)
  end
end

while true do
  main()
  status = eg_status_string()
  draw_text(2, 120, {'Stored EG: ' .. status})
  snes9x.frameadvance()
end
