local THIS_DIR = (... or ''):match("(.-)[^%.]+$") or '.'

-- https://github.com/libgd/libgd/blob/master/src/gd_gd.c

local class = require(THIS_DIR .. 'class')
local bit = require('bit')
local endian = require('endian')

GDImage = class()

function GDImage:__init(filename)
  self.filename = filename
  local file = assert(io.open(filename, 'r'), 'Error loading file: ' .. filename)
  self.data = file:read("*all")
  file:close()
  self.header = {self.data:byte(1,15)}
end

function GDImage:is_palette()
end


function mytohex(str)
  local result = {}
  local CHARSET='0123456789ABCDEF'
  for i = 1,#str do
    local value = str:byte(i)
    local high = bit.rshift(value, 4) + 1  -- stupid lua
    local low = bit.band(value, 0x0F) + 1  -- stupid lua
    local highnib = CHARSET:sub(high,high):byte()
    local lownib = CHARSET:sub(low,low):byte()
    table.insert(result, CHARSET:sub(high,high):byte())
    table.insert(result, CHARSET:sub(low,low):byte())
  end
  return string.char(unpack(result))
end

-- This is just test nonsense
function GDImage:verify_header()
  --a, b = self.data:byte(1,2)
  --print(a)
  --print(b)
  --print(read_signed_big_endian{self.data:byte(3,4)})
  --print(endian.read_big_signed{0xFF,0xFE})
  --print(endian.read_little_signed{0xFF,0xFE})
  x=endian.serialize(-2, false)
  print(x:byte(1,#x))
  --print(little_endian{self.data:byte(3,4)})
  --print(self.data:byte(5,6))
  i = -16515072
  print(i, '=', mytohex(endian.serialize(i, false)))
  if false then
    for i = -1024, 300 do
      print(i, '=', mytohex(endian.serialize(i, false)))
      endian.serialize(i, false)
      print('.')
    end
  end
end

image = GDImage(THIS_DIR .. '/foo.gd')
image:verify_header()
--x={string.byte(image.data, 2,3)}
--print(x[2])


