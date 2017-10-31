local THIS_DIR = (... or ''):match("(.-)[^%.]+$") or '.'

if not gui then
  gui = require(THIS_DIR .. 'stub_gui')
end

if gui.defaultTextBackground then
  gui.defaultTextBackground(nil)
end

local pixelText = (gui.pixelText or gui.text)

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
}
