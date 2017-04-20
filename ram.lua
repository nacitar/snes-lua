#!/usr/bin/env lua

local util = require 'util'
local string = require 'string'

if not memory then
  memory = require 'stub_memory'
end

-- TODO perhaps implement a layer on memory.register() if a need is found
Field = util.class()
function Field:__init(address, size, data_type)
  if type(address) ~= 'number' then
    error('address must be a number')
  end
  if type(size) ~= 'number' then
    error('size must be a number')
  end
  if data_type == 'u' or data_type == 's' then 
    self._data_type = data_type
    if size ~= 1 and size ~= 2 and size ~= 4 then
      error('unsupported size: ' + tostring(size))
    end
  elseif data_type ~= 'r' then
    error('unsupported type: ' + tostring(data_type))
  end
  self._data_type = data_type
  self._address = address
  self._size = size
end

function Field:read()
  if self._data_type == 'r' then
    return memory.readbyterange(self._address, self._size)
  elseif self._size == 1 then
    if self._signed then
      return memory.readbytesigned(self._address)
    end
    return memory.readbyte(self._address)
  elseif self._size == 2 then
    if self._signed then
      return memory.readwordsigned(self._address)
    end
    return memory.readword(self._address)
  elseif self._size == 4 then
    if self._signed then
      return memory.readdwordsigned(self._address)
    end
    return memory.readdword(self._address)
  end
  error('unimplemented')
end

function Field:write(value)
  if self._data_type == 'r' then
    -- ... because there is no memory.writebyterange
    local value_len = string.len(value)
    if value_len ~= self._size then
      error(string.format('Field size(%d) does not match value size(%d)',
          self._size, value_len))
    end
    for i = 1, self._size do
      memory.writebyte(self._address + (i - 1), string.byte(value, i))
    end
  elseif self._size == 1 then
    memory.writebyte(self._address, value)
  elseif self._size == 2 then
    memory.writeword(self._address, value)
  elseif self._size == 4 then
    memory.writedword(self._address, value)
  else
    error('unimplemented')
  end
end

return {
  Field = Field,

  rng = Field(0x7E0FA0, 2, 'u'),

  player_x = Field(0x7E0022, 2, 'u'),
  player_x_cycle = Field(0x7E0031, 1, 's'),
  player_x_cycle_index = Field(0x7E002B, 1, 'u'),

  player_y = Field(0x7E0020, 2, 'u'),
  player_y_cycle = Field(0x7E0030, 1, 's'),
  player_y_cycle_index = Field(0x7E002A, 1, 'u'),

  player_facing = Field(0x7E002F, 1, 'u'),
  player_on_lower_level = Field(0x7E00EE, 1, 'u'),
      -- 0 upper, 1 lower
  player_movement_type = Field(0x7E005E, 1, 'u'),
      -- 0x0C == sword/item held
      -- 0x00 == normal
      -- 0x10 == dashing (not on stairs)
      -- 0x02 == stairs (when walking/dashing vertically)
      -- 0x06 == entering cave from overworld
  player_not_overworld = Field(0x7E001B, 1, 'u'),
      -- 0x0 = overworld, 0x1 = house or dungeon
  animation_step_counter = Field(0x7E002E, 1, 'u'),

  input_buffer_main = Field(0x7E00F0, 1, 'u'),  -- BYST|udlr
  input_buffer_main_flags = {
    RIGHT = 1,
    LEFT = 2,
    DOWN = 4,
    UP = 8,
    START = 16,
    SELECT = 32,
    Y = 64,
    B = 128,
  },
  input_buffer_secondary = Field(0x7E00F2, 1, 'u'),  -- AXLR|????
  input_buffer_secondary_flags = {
    R = 16,
    L = 32,
    X = 64,
    A = 128,
  },
  input_push_state = Field(0x7E0026, 1, 'u'),
      -- TODO: useful? looks like JP1_PRESSED_01 except only udlr
}
