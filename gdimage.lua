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

local NOT_TRANSPARENT = 0xFFFFFFFF

function GDImage:__init()
  self:clear()
end

function GDImage:clear()
  self.palette = {}
  self.pixel_data = {}
  self.width = 0
  self.height = 0
  self.is_palette = false
  self.transparent = NOT_TRANSPARENT
end

-- GD 1.0 is untested
function GDImage:load_file(filename)
  local file = assert(io.open(filename, 'rb'),
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
      local is_truecolor = read_BE(data:sub(offset + 1, offset + 1))
      assert(is_truecolor == 0,
          'Truecolor flag should not be set for palette image, but it is...')
      used_colors = read_BE(data:sub(offset + 2, offset + 3))
      -- what is this?!?! says it's a palette index, but it's huge!
      self.transparent = read_BE(data:sub(offset + 4, offset + 7))
      offset = offset + 7
      for i = 1, used_colors do
        table.insert(self.palette, read_BE(data:sub(offset + 1, offset + 4)))
        offset = offset + 4
      end
      -- the palette is ALWAYS 256 colors in size, even if not all of those
      -- are used.  Skip the rest, though.
      offset = offset + (256 - used_colors) * 4
    else
      -- redundant flag; should always be 1 for truecolor
      local is_truecolor = read_BE(data:sub(offset + 1, offset + 1))
      assert(is_truecolor == 1,
          'Truecolor flag should be set for truecolor image, but it is not...')
      -- what is this?!?! says it's an ARGB color
      self.transparent = read_BE(data:sub(offset + 2, offset + 5))
      offset = offset + 5
    end
  else
    -- gd 1.0
    -- file header
    self.is_palette = true
    self.width = signature  -- not really a signature in 1.0
    self.height = read_BE(data:sub(3, 4))
    used_colors = read_BE(data:sub(5, 5))
    self.transparent = read_BE(data:sub(6, 7))
    if self.transparent == 257 then
      self.transparent = NOT_TRANSPARENT
    end
    offset = 7
    for i = 1, used_colors do
      -- only RGB
      table.insert(self.palette, read_BE(data:sub(offset + 1, offset + 3)))
      offset = offset + 3
    end
    -- UNTESTED: i'm _assuming_ 1.0 palettes work the same as 2.0 ones, so
    -- padding to 256 in size.
    offset = offset + (256 - used_colors) * 3
  end

  -- pixel data
  if self.is_palette then
    for i = 1, (self.width * self.height) do
      table.insert(self.pixel_data, read_BE(data:sub(offset + 1, offset + 1)))
      offset = offset + 1
    end
  else
    for i = 1, (self.width * self.height) do
      table.insert(self.pixel_data, read_BE(data:sub(offset + 1, offset + 4)))
      offset = offset + 4
    end
  end
end

function GDImage:convert_to_truecolor()
  if self.is_palette then
    self.is_palette = false
    for i = 1, #self.pixel_data do
      self.pixel_data[i] = self.palette[self.pixel_data[i] + 1]
    end
    if self.transparent ~= NOT_TRANSPARENT then
      self.transparent = self.palette[self.transparent + 1]
    end
    self.palette = {}
  end
end

function GDImage:convert_to_palette()
  if not self.is_palette then
    self.is_palette = true
    self.palette = {}  -- unnecessary, probably
    local color_map = {}
    for i = 1, #self.pixel_data do
      local color = self.pixel_data[i]
      local index = color_map[color]
      if index == nil then
        index = #self.palette  -- lua index - 1
        color_map[color] = index
        table.insert(self.palette, color)
      end
      self.pixel_data[i] = index
    end
    if self.transparent ~= NOT_TRANSPARENT then
      self.transparent = color_map[color]
    end
  end
end



function GDImage:save_file(filename)
  local file = assert(io.open(filename, 'wb'), 'Error opening: ' .. filename)
  file:write(write_BE(self.is_palette and 0xFFFF or 0xFFFE, 2))
  file:write(write_BE(self.width, 2))
  file:write(write_BE(self.height, 2))
  if self.is_palette then
    file:write(write_BE(0, 1))  -- palette
    file:write(write_BE(#self.palette, 2))
    file:write(write_BE(self.transparent, 4))
    for i = 1, 256 do  -- palette is always 256 in size, just not all used
      file:write(write_BE(self.palette[i] or 0, 4))
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

--image = GDImage()
--image:load_file(THIS_DIR .. '/GD_example.gd')
--image:convert_to_truecolor()
--image:convert_to_palette()
--image:save_file(THIS_DIR .. '/out.gd')

return {
  GDImage = GDImage,
}
