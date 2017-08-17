#!/usr/bin/env lua
local THIS_DIR = (... or '1'):match("(.-)[^%.]+$")
local class = require(THIS_DIR .. 'class')
if not memory then
  memory = require(THIS_DIR ..'stub_memory')
end

Array = class()
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

Field = class(Array)
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

Unsigned = class(Field)
function Unsigned:__init(address, size)
  Field.__init(self, address, size, false)
end
Signed = class(Field)
function Signed:__init(address, size)
  Field.__init(self, address, size, true)
end

return {
  Array = Array,
  Field = Field,
  Unsigned = Unsigned,
  Signed = Signed,
}
