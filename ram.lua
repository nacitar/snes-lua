#!/usr/bin/env lua

local util = require 'util'
local string = require 'string'

if not memory then
  memory = require 'stub_memory'
end



Array = util.class()
function Array:__init(address, data_size, length)
  if type(address) ~= 'number' then
    error('address must be a number')
  end
  if type(data_size) ~= 'number' then
    error('size must be a number')
  end
  if type(length) ~= 'number' then
    error('length must be a number')
  end
  if data_size ~= 1 and data_size ~= 2 and data_size ~= 4 then
    error(('invalid data size (%d): can only be 1, 2, or 4 bytes'):format(
        data_size))
  end
  self._address = address
  self._data_size = data_size
  self._length = length
end

function Array:indexed_address(index)
  if type(index) ~= 'number' or index < 0 or index >= self._length then
    error(('invalid index (%d), range [0, %d)'):format(index, self._length))
  end
  return self._address + (self._data_size * index)
end

function Array:read(index, signed)
  if type(signed) ~= 'boolean' then
    error('signed must be boolean')
  end
  local address = self:indexed_address(index)
  if self._data_size == 1 then
    if signed then
      return memory.readbytesigned(address)
    end
    return memory.readbyte(address)
  elseif self._data_size == 2 then
    if signed then
      return memory.readwordsigned(address)
    end
    return memory.readword(address)
  elseif self._data_size == 4 then
    if signed then
      return memory.readdwordsigned(address)
    end
    return memory.readdword(address)
  end
end
function Array:write(index, value)
  local address = self:indexed_address(index)
  if self._data_size == 1 then
    memory.writebyte(address, value)
  elseif self._data_size == 2 then
    memory.writeword(address, value)
  elseif self._data_size == 4 then
    memory.writedword(address, value)
  end
end

Field = util.class(Array)
function Field:__init(address, size, signed)
  if type(signed) ~= 'boolean' then
    error('signed must be boolean')
  end
  Array.__init(self, address, size, 1)
  self._signed = signed
end
function Field:read()
  return Array.read(self, 0, self._signed)
end
function Field:write(value)
  Array.write(self, 0, value)
end
function Field:add(value)
  self:write(self:read() + value)
end
function Field:sub(value)
  self:write(self:read() - value)
end
function Field:inc()
  self:add(1)
end
function Field:dec()
  self:sub(1)
end

Unsigned = util.class(Field)
function Unsigned:__init(address, size)
  Field.__init(self, address, size, false)
end
Signed = util.class(Field)
function Signed:__init(address, size)
  Field.__init(self, address, size, true)
end


return {
  Array = Array,
  Field = Field,
  Unsigned = Unsigned,
  Signed = Signed,

  rng = Unsigned(0x7E0FA0, 2),

  player_not_overworld = Unsigned(0x7E001B, 1),
      -- 0x0 = overworld, 0x1 = house or dungeon
  player_y = Unsigned(0x7E0020, 2),
  player_x = Unsigned(0x7E0022, 2),
  input_push_state = Unsigned(0x7E0026, 1),
      -- TODO: useful? looks like input_buffer_main except only udlr
  player_y_cycle_index = Unsigned(0x7E002A, 1),
  player_x_cycle_index = Unsigned(0x7E002B, 1),
  animation_step_counter = Unsigned(0x7E002E, 1),
  player_facing = Unsigned(0x7E002F, 1),
  player_y_cycle = Signed(0x7E0030, 1),
  player_x_cycle = Signed(0x7E0031, 1),


  player_movement_type = Unsigned(0x7E005E, 1),
      -- 0x0C == sword/item held
      -- 0x00 == normal
      -- 0x10 == dashing (not on stairs)
      -- 0x02 == stairs (when walking/dashing vertically)
      -- 0x06 == entering cave from overworld
  player_on_lower_level = Unsigned(0x7E00EE, 1),
      -- 0 upper, 1 lower

  input_buffer_main = Unsigned(0x7E00F0, 1),  -- BYST|udlr
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
  input_buffer_secondary = Unsigned(0x7E00F2, 1),  -- AXLR|????
  input_buffer_secondary_flags = {
    R = 16,
    L = 32,
    X = 64,
    A = 128,
  },
}
