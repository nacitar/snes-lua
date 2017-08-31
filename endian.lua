
local bit = require('bit')

function read_little(byte_list)
  local result = 0
  local multiplier = 0x1
  for i, value in ipairs(byte_list) do
    assert(value >= 0 and value <= 0xFF, 'value out of range: ' .. value)
    result = result + value * multiplier
    multiplier = multiplier * 0x100
  end
  return result
end
function read_negative_little(byte_list)
  local result = 0
  local multiplier = 0x1
  for _, value in ipairs(byte_list) do
    assert(value >= 0 and value <= 0xFF, 'value out of range: ' .. value)
    -- two's complement... so we'll parse the bnot of the value instead
    -- then negate this result when we're done, and add 1 to it.
    result = result + bit.band(bit.bnot(value), 0xFF) * multiplier
    multiplier = multiplier * 0x100
  end
  return -(result + 1)
end
function read_big(byte_list)
  local result = 0
  for i, value in ipairs(byte_list) do
    assert(value >= 0 and value <= 0xFF, 'value out of range: ' .. value)
    result = result * 0x100 + value
  end
  return result
end
function read_negative_big(byte_list)
  local result = 0
  for _, value in ipairs(byte_list) do
    assert(value >= 0 and value <= 0xFF, 'value out of range: ' .. value)
    -- two's complement... so we'll parse the bnot of the value instead
    -- then negate this result when we're done, and add 1 to it.
    result = result * 0x100 + bit.band(bit.bnot(value), 0xFF)
  end
  return -(result + 1)
end
function read_big_signed(byte_list)
  if #byte_list > 0 and byte_list[1] > 0x7F then
    return read_negative_big(byte_list)
  end
  return read_big(byte_list)
end
function read_little_signed(byte_list)
  if #byte_list > 0 and byte_list[#byte_list] > 0x7F then
    return read_negative_little(byte_list)
  end
  return read_little(byte_list)
end
function serialize(value, is_big)
  local result = {}
  if value == 0 then
    table.insert(result, 0)
  else
    local is_negative = (value < 0)
    local fixed_neg = false
    if is_negative then
      value = -value
    end

    local low_byte = nil
    while value ~= 0 do
      low_byte = value % 0x100
      -- subtract off the excess to force integer division
      value = (value - low_byte) / 0x100
      if is_negative then
        -- the bnot doesn't get us the right bits until we add 1
        low_byte = bit.bnot(low_byte) % 0x100
        if not fixed_neg then
          if low_byte == 0xFF then
            print(value)
            low_byte = 0
          else
            low_byte = low_byte + 1
            fixed_neg = true
          end
        end
      end
      if is_big then
        table.insert(result, 1, low_byte)
      else
        table.insert(result, low_byte)
      end
    end
    if is_negative and not fixed_neg then
      -- The only way this could happen is if the last byte processed is 0x00,
      -- because after the bnot that would make it 0xFF.. but the loop would
      -- have stopped by then, so if this ever happens there be gremlins
      error('If you see this, read the comment in the code: ' .. value)
    end
    -- TODO: what? if not fixed_neg
    -- test this more fully, too!
    -- if this doesn't indicate negative, the next byte must
    if is_negative and low_byte < 0x80 then
      if is_big then
        table.insert(result, 1, 0xFF)
      else
        table.insert(result, 0xFF)
      end
    end
  end

  return string.char(unpack(result))
end

return {
    read_little = read_little,
    read_big = read_big,
    read_little_signed = read_little_signed,
    read_big_signed = read_big_signed,
    serialize = serialize,
}
