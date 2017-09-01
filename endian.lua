-- just some helpers to pretty up code
local TABLE_INSERT = table.insert
local function prepend_table(table, value)
  TABLE_INSERT(table, 1, value)
end
local function append_table(table, value)
  TABLE_INSERT(table, value)
end

function deserialize(binary_value, is_big, is_signed)
  assert(#binary_value > 0, 'no data to deserialize')
  local first, last, step
  if is_big then
    first, last, step = 1, #binary_value, 1
  else
    -- iterate in reverse for little endian.  we can do this just as well if
    -- iterating forward, however doing this change here moves the if/else
    -- branching OUTSIDE the loop, so we do the conditional part once instead
    -- of for every byte
    first, last, step = #binary_value, 1, -1
  end
  -- checking index 'first' because the iteration order matches big endian
  local is_negative = (is_signed and binary_value:byte(first) >= 0x80)
  local result = 0
  for i = first, last, step do
    local value = binary_value:byte(i)
    assert(value >= 0 and value <= 0xFF, 'value out of range: ' .. value)
    if is_negative then
      -- two's complement... do the bnot now, and add the 1 when we're done
      value = 0xFF - value  -- fast single byte bnot
    end
    result = result * 0x100 + value
  end
  if is_negative then
    result = -(result+1)
  end
  return result
end

-- This function always either writes the value into the smallest number of
-- bytes in which it can fit, or the size provided _IF_ it can fit in it.
--
-- __IF__ the assert is commented out, you can indeed serialize negative
-- numbers as unsigned, and this will result in a value equal in size to the
-- minimum number of bytes needed to represent the abs() of that value (or the
-- size passed if larger) and that value will be one more than the maximum
-- value representable by this many bytes (that value being 2^num_bits) minus
-- the abs() of the value provided.
-- Useful examples:
--   -1 ==> 0xFF
--   -1 with size 2 ==> 0xFFFF
--   -256 ==> 0xFF00
-- This sounds confusing though it's pretty simple... but I fear accidental
-- uses of this rather than clever ones, so the assert remain.  As an aside,
-- provided that you do in fact specify a size, it makes it behave just like
-- it would in C/C++, where -2 with a 4-byte size yields 0xFFFE.  =)
function serialize(value, is_big, is_signed, size)
  local result = {}
  local pad_byte = 0x00
  local INSERTER = is_big and prepend_table or append_table
  if value == 0 then
    TABLE_INSERT(result, 0x00)
  else
    local is_negative = (value < 0)
     assert((not is_negative or is_signed), -- or size ~= nil,
        "Cannot serialize a negative value as unsigned.")
    local need_1_added = is_negative
    if is_negative then
      pad_byte = 0xFF
      value = -value  -- positive... so we can derive its 2's complement
    end
    local current_byte
    while value ~= 0 do
      current_byte = (value % 0x100)  -- faster than bit.band(value, 0xFF)
      value = (value - current_byte) / 0x100  -- force integer division
      if is_negative then
        -- convert to 2's complement... bnot() bytes, propagating a single add
        current_byte = 0xFF - current_byte  -- fast single byte bnot
        if need_1_added then
          if current_byte == 0xFF then
            current_byte = 0
            -- add had a carry, so don't clear need_1_added
          else
            current_byte = current_byte + 1
            need_1_added = false
          end
        end
      end
      INSERTER(result, current_byte)
    end
    -- if the negativity doesn't match what the high byte represents, and we
    -- aren't already padding another byte... make it pad one to fix this
    if is_signed and is_negative ~= (current_byte >= 0x80) and (
      not size or size <= #result) then
      size = #result + 1
    end
  end
  if size then
    while #result < size do
      INSERTER(result, pad_byte)
    end
  end
  return string.char(unpack(result))
end

return {
    serialize = serialize,
    deserialize = deserialize,
}
