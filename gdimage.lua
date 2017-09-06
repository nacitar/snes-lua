local THIS_DIR = (... or ''):match("(.-)[^%.]+$") or '.'

-- only supporting gd 1.0/2.0 and not gd2
-- https://github.com/libgd/libgd/blob/master/src/gd_gd.c

local class = require(THIS_DIR .. 'class')
local endian = require('endian')

local function read_BE(data)
  return endian.deserialize(data, true)
end

local function write_BE(value, size)
  return string.char(unpack(endian.serialize(value, true, false, size)))
end

GDImage = class()

function GDImage:__init()
  self:clear()
end

function GDImage:clear()
  self.palette = {}
  self.pixel_data = {}
  self.width = 0
  self.height = 0
  self.is_palette = false
end

function GDImage:load_file(filename)
  local file = assert(io.open(filename, 'r'),
      'Error loading file: ' .. filename)
  data = file:read("*all")
  file:close()

  local signature = read_BE(data:sub(1, 2))
  local offset
  if signature == 0xFFFF or signature == 0xFFFE then
    -- gd 2.0
    -- file header
    self.is_palette = (signature == 0xFFFF)
    self.width = read_BE(data:sub(3, 4))
    self.height = read_BE(data:sub(5, 6))
    offset = 6
    -- color header
    if self.is_palette then
      -- redundant flag; should always be 0 for palette
      local is_truecolor = read_BE(data:sub(offset+1, offset+1))
      assert(is_truecolor == 0,
          'Truecolor flag should not be set for palette image, but it is...')
      local color_count = read_BE(data:sub(offset+2, offset+3))
      -- what is this?!?! says it's a palette index, but it's huge!
      self.transparent = read_BE(data:sub(offset+4, offset+7))
      offset = offset + 7
      for i = 1, color_count do
        table.insert(self.palette, read_BE(data:sub(offset+i, offset+i+3)))
      end
      offset = offset + color_count * 4
    else
      -- redundant flag; should always be 1 for truecolor
      local is_truecolor = read_BE(data:sub(offset+1, offset+1))
      assert(is_truecolor == 1,
          'Truecolor flag should be set for truecolor image, but it is not...')
      -- what is this?!?! says it's an ARGB color
      self.transparent = read_BE(data:sub(offset+2, offset+5))
      offset = offset + 5
    end
  else
    -- gd 1.0
    -- file header
    self.is_palette = true
    self.width = signature  -- not really a signature in 1.0
    self.height = read_BE(data:sub(3, 4))
    self.count = read_BE(data:sub(5, 5))
    -- what is this?  257 signals no transparency
    self.transparent = read_BE(data:sub(6, 7))
    offset = 7
    for i = 1, self.count do
      -- only RGB
      table.insert(self.palette, read_BE(data:sub(offset+i, offset+i+2)))
    end
    offset = offset + color_count * 3
  end

  -- pixel data
  if self.is_palette then
    for i = 1, (self.width * self.height) do
      table.insert(self.pixel_data, read_BE(data:sub(offset+i, offset+i)))
    end
  else
    for i = 1, (self.width * self.height) do
      table.insert(self.pixel_data, read_BE(data:sub(offset + 1, offset + 4)))
      offset = offset + 4
    end
  end
end

function GDImage:save(filename)
  local file = assert(io.open(filename, 'wb'), 'Error opening: ' .. filename)
  file:write(write_BE(self.is_palette and 0xFFFF or 0xFFFE, 2))
  file:write(write_BE(self.width, 2))
  file:write(write_BE(self.height, 2))
  if self.is_palette then
    file:write(write_BE(0, 1))  -- palette
    file:write(write_BE(#self.palette, 2))
    file:write(write_BE(self.transparent, 4))
    for i = 1, #self.palette do
      file:write(write_BE(self.palette[i], 4))
    end
    for i = 1, #self.pixel_data do
      file:write(write_BE(self.pixel_data[i], 1))
    end
  else
    file:write(write_BE(1, 1))  -- truecolor
    file:write(write_BE(self.transparent, 4))
    for i = 1, #self.pixel_data do
      file:write(write_BE(self.pixel_data[i], 4))
    end
  end
  file:close()
end

-- image = GDImage()
-- image:load_file(THIS_DIR .. '/foo.gd')
-- image:save(THIS_DIR .. '/test.gd')

return {
  GDImage = GDImage,
}
