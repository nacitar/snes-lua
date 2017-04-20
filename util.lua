#!/usr/bin/env lua

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

-- class() uses two tricks. It allows you to construct a class using the call
-- notation (like Dog('fido')) by giving the class itself a metatable
-- which defines __call. It handles inheritance by copying the fields of the
-- base class into the derived class. This isn't the only way of doing
-- inheritance; we could make __index a function which explicitly tries to
-- look a function up in the base class(es). But this method will give better
-- performance, at a cost of making the class objects somewhat fatter. Each
-- derived class does keep a field _base that contains the base class, but
-- this is to implement is_a.
--
-- Note that modification of a base class at runtime will not affect its
-- subclasses.

-- class.lua
-- Compatible with Lua 5.1 (not 5.0).
function class(base, __init)
  local c = {}    -- a new class instance
  if not __init and type(base) == 'function' then
    __init = base
    base = nil
  elseif type(base) == 'table' then
    -- our new class is a shallow copy of the base class!
    for i,v in pairs(base) do
      c[i] = v
    end
    c._base = base
  end
  -- the class will be the metatable for all its objects,
  -- and they will look up their methods in it.
  c.__index = c

  -- expose a constructor which can be called by <classname>(<args>)
  local mt = {}
  mt.__call = function(class_tbl, ...)
    local obj = {}
    setmetatable(obj,c)
    if class_tbl.__init then
      class_tbl.__init(obj,...)
    else
      -- make sure that any stuff from the base class is initialized!
      if base and base.__init then
        base.__init(obj, ...)
      end
    end
    return obj
  end
  c.__init = __init
  c.is_a = function(self, klass)
    local m = getmetatable(self)
    while m do
      if m == klass then return true end
      m = m._base
    end
    return false
  end
  setmetatable(c, mt)
  return c
end

--  -- EXAMPLE
--
--  local util = require 'util'
--
--  A = util.class()
--  function A:__init(x)
--    self.x = x
--  end
--  function A:test()
--    print(self.x)
--  end
-- 
--  function A:__add(b)
--    return A(self.x + b.x)
--  end
-- 
--  B = class(A)
--  function B:__init(x,y)
--    A.__init(self,x)
--    self.y = y
--  end
-- 
--  x=A(5)
--  y=B(6)
--  z=x + y
--  z:test()
--
return {
  class = class,
  pretty_string = pretty_string,
}
