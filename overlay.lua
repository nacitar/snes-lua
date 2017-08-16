local eg_status = require 'eg_status'
local waterwalk_status = require 'waterwalk_status'
local util = require 'util'

while true do
  eg_status.main()
  stored_eg = eg_status.stored_eg_string()
  waterwalk_armed = waterwalk_status.waterwalk_string()
  spinspeed_armed = waterwalk_status.spinspeed_string()
  util.draw_text(2, 120, {
      'Stored EG: ' .. stored_eg,
      'Waterwalk: ' .. waterwalk_armed,  
      'Spinspeed: ' .. spinspeed_armed,  
  })
  snes9x.frameadvance()
end
