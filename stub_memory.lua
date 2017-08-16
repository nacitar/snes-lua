#!/usr/bin/env lua

if memory == nil then
  -- simple stub, doesn't do any conversions or use a real buffer
  -- simple key/value pair.  accessing the same location as multiple types
  -- will store/retrieve the same value
  memory = {}

  memory._buffer = {}

  function memory._validate(address)
    if 0x7e0000 <= address and address <= 0x7FFFFF then
      return true
    else
      error(('Address out of range: 0x%06x'):format(address))
    end
    return false
  end
  function memory._read(address)
    memory._validate(address)
    local value = memory._buffer[address]
    if value == nil then
      value = 0
    end
    return value
  end
  function memory._write(address, value)
    memory._validate(address)
    memory._buffer[address] = value
  end

  function memory.readbyterange(address, length)
    error('stub memory.readbyterange() unimplemented')
  end
  function memory.readbyte(address)
    return memory._read(address)
  end
  function memory.readbytesigned(address)
    return memory._read(address)
  end
  function memory.readword(address)
    return memory._read(address)
  end
  function memory.readwordsigned(address)
    return memory._read(address)
  end
  function memory.readdword(address)
    return memory._read(address)
  end
  function memory.readdwordsigned(address)
    return memory._read(address)
  end
  function memory.writebyte(address, value)
    return memory._write(address, value)
  end
  function memory.writeword(address, value)
    return memory._write(address, value)
  end
  function memory.writedword(address, value)
    return memory._write(address, value)
  end
end

return memory
