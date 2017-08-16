local ram = require 'ram'

local var = {
  falling_state = ram.Unsigned(0x7E005B, 1),
  player_state = ram.Unsigned(0x7E005D, 1),
}

local FallingStateFlags = {
  NORMAL = 0,
}

local PlayerStateFlags = {
  FALLING_OR_NEAR_HOLE = 1,
  DASHING = 17,
}

function waterwalk_string()
  if var.falling_state:read() ~= FallingStateFlags.NORMAL and
      var.player_state:read() ~= PlayerStateFlags.FALLING_OR_NEAR_HOLE then
    return 'armed'
  end
  return 'disarmed'
end

return {
  waterwalk_string = waterwalk_string,
}
