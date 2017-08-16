local ram = require 'ram'

local var = {
  falling_state = ram.Unsigned(0x7E005B, 1),
  player_state = ram.Unsigned(0x7E005D, 1),
  dash_countdown = ram.Unsigned(0x7E0374, 1),  -- 29 during ss, but not checking
  bonk_wall = ram.Unsigned(0x7E0372, 1),
  hand_up_pose = ram.Unsigned(0x7E02DA, 1),
}

local FallingStateFlags = {
  NORMAL = 0,
}

local PlayerStateFlags = {
  FALLING_OR_NEAR_HOLE = 1,
  DASHING = 17,
}
local HandUpPoseFlags = {
  NOT_UP = 0,
}

function waterwalk_string()
  if var.falling_state:read() ~= FallingStateFlags.NORMAL and
      var.player_state:read() ~= PlayerStateFlags.FALLING_OR_NEAR_HOLE then
    return 'armed'
  end
  return 'disarmed'
end

function spinspeed_string()
  player_state = var.player_state:read()
  if player_state ~= PlayerStateFlags.DASHING and
      player_state ~= PlayerStateFlags.FALLING_OR_NEAR_HOLE and
      var.bonk_wall:read() == 1 and
      var.hand_up_pose:read() == 0 then
      -- duck causes your hand to go up, but so do crystals/pendants/triforce
      -- however, crystals/pendants also clear spinspeed anyway.. (as do
      -- hearts), and who cares once you get triforce.  Works.
      -- Without this extra check, dashing and then getting picked up by the
      -- duck mid-dash will erroneously report spinspeed.
    return 'armed'
  end
  return 'disarmed'
end


return {
  waterwalk_string = waterwalk_string,
  spinspeed_string = spinspeed_string,
}
