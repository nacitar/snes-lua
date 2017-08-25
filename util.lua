local THIS_DIR = (... or ''):match("(.-)[^%.]+$") or '.'

if not gui then
  gui = require(THIS_DIR .. 'stub_gui')
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
    gui.text(base_x, y, line)
  end
end


return {
  pretty_string = pretty_string,
  Set = Set,
  draw_text = draw_text,
}
