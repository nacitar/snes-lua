local THIS_DIR = (... or ''):match("(.-)[^%.]+$") or '.'

function pixelTextStubbed(x, y, text, color)
  -- noop for running from terminal
end
function drawPixelStubbed(x, y, color)
  -- noop for running from terminal
end
function drawLineStubbed(x, y, x2, y2, color)
  -- noop for running from terminal
end
function drawBoxStubbed(x, y, x2, y2, line, background)
  -- noop for running from terminal
end
function RGBA_bizhawk(red, green, blue, alpha)
  return (
      bit.band(blue, 0xFF) +
      bit.lshift(bit.band(green, 0xFF), 8) +
      bit.lshift(bit.band(red, 0xFF), 16) +
      bit.lshift(bit.band(alpha, 0xFF), 24))
end
function RGBA_snes9x(red, green, blue, alpha)
  return (
      bit.band(alpha, 0xFF) +
      bit.lshift(bit.band(blue, 0xFF), 8) +
      bit.lshift(bit.band(green, 0xFF), 16) +
      bit.lshift(bit.band(red, 0xFF), 24))
end

if gui then
  -- good enough check; bizhawk only function
  if gui.pixelText then
    running_in = 'bizhawk'
    gui.defaultTextBackground(nil)
    pixelText = gui.pixelText
    drawPixel = gui.drawPixel
    drawLine = gui.drawLine
    drawBox = gui.drawBox
    RGBA = RGBA_bizhawk
  else
    running_in = 'snes9x' -- assumption
    pixelText = gui.text
    drawPixel = gui.pixel
    drawLine = gui.line
    drawBox = gui.rect
    RGBA = RGBA_snes9x
  end
else
  -- terminal?
  running_in = 'unknown'
  pixeltext = pixelTextStubbed
  drawPixel = drawPixelStubbed
  drawLine = drawLineStubbed
  drawBox = drawBoxStubbed
  RGBA = RGBA_snes9x
end

function is_bizhawk()
  return (running_in == 'bizhawk')
end
function is_snes9x()
  return (running_in == 'snes9x')
end


function file_line_iterator(file)
  if is_bizhawk() then
    -- bizhawk gives unknown lua error after using file:lines/io.lines
    -- so avoid it by using an intermediary string
    local data = file:read('*all')
    if data:sub(-1) ~= '\n' then
      data = data .. '\n'
    end
    return data:gmatch("(.-)\n")
  else
    return file:lines()
  end
end

function pretty_string(table)
  -- build a string otherwise
  local result = nil
  if type(table) == 'table' then
    local result = ''
    for i, value in ipairs(table) do
      result = result .. pretty_string(value) .. ', '
    end
    for key, value in pairs(table) do
      if type(key) ~= 'number' then
        result = result .. key .. '=' .. pretty_string(value) .. ', '
      end
    end
    if result ~= '' then
      result = result:sub(1, -3)
    end
    return '{' .. result .. '}'
  end
  -- fallback; not a table
  return tostring(table)
end

function Set (list)
  local set = {}
  for _, l in ipairs(list) do
    set[l] = true
  end
  return set
end

function draw_text(base_x, base_y, lines)
  for i, line in pairs(lines) do
    local y = base_y + (8 * (i - 1))
    -- color arg ignored in 9x.. but no black outline in bizhawk
    pixelText(base_x, y, line, 'yellow')
  end
end

function draw_text_above(base_x, base_y, lines)
  draw_text(base_x, base_y - (8 * #lines), lines)
end

function tohex(str)
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

return {
  pretty_string = pretty_string,
  Set = Set,
  draw_text = draw_text,
  draw_text_above = draw_text_above,
  file_line_iterator = file_line_iterator,
  running_in = running_in,
  is_bizhawk = is_bizhawk,
  is_snes9x = is_snes9x,
  pixelText = pixelText,
  drawPixel = drawPixel,
  drawLine = drawLine,
  drawBox = drawBox,
  RGBA = RGBA,
}
