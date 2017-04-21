#!/usr/bin/env lua

-- https://wiki.superfamicom.org/snes/show/65816+Reference
-- https://wiki.superfamicom.org/snes/show/Jay%27s+ASM+Tutorial

local ram = require 'ram'


local sub_submodule_index = ram.Field(0x7E00B0, 1, 'u')  -- really 1?
local incap_timer = ram.Field(0x7E0046, 1, 'u')  -- really 1?
local scr_transition_bf2 = ram.Field(0x7E0416, 2, 'u')  -- values?
local y_dest = ram.Field(0x7EC184, 2, 'u') -- name?
local x_dest = ram.Field(0x7EC186, 2, 'u') -- name?

local tmp_y = ram.Field(0x7E0000, 2, 's')
local tmp_x = ram.Field(0x7E0002, 2, 's')
local player_x = ram.player_x  -- $22
local player_y = ram.player_y  -- $20
local player_y_cycle = ram.player_y_cycle  -- $30
local player_x_cycle = ram.player_x_cycle  -- $31

function Overworld_ScrollMap()
  -- via -- JSR Overworld_ScrollMap     ; $17273 IN ROM
  error('unimplemented')
end

function unknown_function_BB90()
  -- via -- JSR $BB90 ; $13B90 IN ROM
  error('unimplemented')
end

function unknown_function_9583()
  -- via -- dw $9583 ; = $11583*                                                     
  error('unimplemented')
end

function max_step(position, destination)
  local result = destination - position
  if result > 2 then
    return 2
  elseif result < -2 then
    return -2
  end
  return result
end
--; *$13528-$13531 JUMP LOCATION                                               
function jump_func()
  if sub_submodule_index:read() == 0 then
    --  dw $B532 ; = $13532*                                                     
    complete_rewrite()
  else
    --  dw $9583 ; = $11583*                                                     
    unknown_function_9583()
  end
end
-- Bank02.asm line 8138
-- ; *$13532-$135AB JUMP LOCATION
function complete_rewrite()
  tmp_x.write(max_step(player_x:read(), x_dest:read()))
  tmp_y.write(max_step(player_y:read(), y_dest:read()))

  player_x.write(player_x:read() + tmp_x.read())
  player_y.write(player_y:read() + tmp_y.read())

  if player_y:read() == y_dest:read() and player_x:read() == x_dest:read() then
    sub_submodule_index:inc()  -- INC $B0
    incap_timer:write(0)  -- STZ $46
  end

  player_y_cycle.write(steps.y)
  player_x_cycle.write(steps.x)

  unknown_function_BB90()
  if scr_transition_bf2:read() ~= 0 then
    Overworld_ScrollMap()
  end
end

function branched_set_speeds()
  local A = nil

  -- A is 16-bit  -- REP #$20
  tmp_y:write(0)  -- STZ $00
  tmp_x:write(0)  -- STZ $02

  ---- X STUFF ----
  A = player_x:read()  -- LDA $22
  if A > x_dest:read() then 
    tmp_x:dec()  -- DEC $02
    A = A - 1  -- DEC A
    if A ~= x_dest:read() then
      tmp_x:dec()  -- DEC $02
      A = A - 1  -- DEC A
    end
  elseif A < x_dest:read() then
    -- ::BRANCH_BETA::
    tmp_x:inc()  -- INC $02
    A = A + 1  -- INC A
    if A ~= x_dest:read() then
      tmp_x:inc()  -- INC $02
      A = A + 1  -- INC A
    end
  end
  -- ::BRANCH_ALPHA::
  player_x:write(A)  -- STA $22

  ---- Y STUFF ----
  A = player_y:read()  -- LDA $20
  if A > y_dest:read() then
    tmp_y:dec() -- DEC $00
    A = A - 1  -- DEC A
    if A ~= y_dest:read() then
      tmp_y:dec()  -- DEC $00
      A = A - 1  -- DEC A
    end
  elseif A < y_dest:read() then
    -- ::BRANCH_DELTA::
    tmp_y:inc()  -- INC $00
    A = A + 1  -- INC A
    if A ~= y_dest:read() then
      tmp_y:inc()  -- INC $00
      A = A + 1  -- INC A
    end
  end
  -- ::BRANCH_GAMMA::
  player_y:write(A)  -- STA $20

  if player_y:read() == y_dest:read() and player_x:read() == x_dest:read() then
    -- TODO: what??!?!
    sub_submodule_index:inc()  -- INC $B0
    incap_timer:write(0)  -- STZ $46
  end
  -- ::BRANCH_EPSILON::

  -- A is 8-bit  -- SEP #$20
  player_y_cycle:write(tmp_y:read())  -- LDA $00 : STA $30
  player_x_cycle:write(tmp_x:read())  -- LDA $02 : STA $31

  -- TODO? checking if we need to scroll the map, maybe?  FOR LATER
  unknown_function_BB90()  -- JSR $BB90 ; $13B90 IN ROM
  -- LDA $0416
  if scr_transition_bf2:read() ~= 0 then
    Overworld_ScrollMap()  -- JSR Overworld_ScrollMap     ; $17273 IN ROM
  end
  -- ::BRANCH_ZETA::
  return  -- RTS
end

function literal_set_speeds()
  local A = nil

  -- A is 16-bit  -- REP #$20
  tmp_y:write(0)  -- STZ $00
  tmp_x:write(0)  -- STZ $02

  ---- X STUFF ----
  A = player_x:read()  -- LDA $22
  -- : CMP $7EC186
  if A == x_dest:read() then 
    goto BRANCH_ALPHA  -- : BEQ BRANCH_ALPHA
  elseif A < x_dest:read() then
    goto BRANCH_BETA  -- : BCC BRANCH_BETA
  end
  tmp_x:dec()  -- DEC $02
  A = A - 1  -- DEC A
  -- : CMP $7EC186
  if A == x_dest:read() then
    goto BRANCH_ALPHA  -- : BEQ BRANCH_ALPHA
  end
  tmp_x:dec()  -- DEC $02
  A = A - 1  -- DEC A
  goto BRANCH_ALPHA  -- BRA BRANCH_ALPHA
  ::BRANCH_BETA::
  tmp_x:inc()  -- INC $02
  A = A + 1  -- INC A
  -- : CMP $7EC186
  if A == x_dest:read() then
    goto BRANCH_ALPHA  -- : BEQ BRANCH_ALPHA
  end
  tmp_x:inc()  -- INC $02
  A = A + 1  -- INC A
  ::BRANCH_ALPHA::
  player_x:write(A)  -- STA $22

  ---- Y STUFF ----
  A = player_y:read()  -- LDA $20
  -- : CMP $7EC184
  if A == y_dest:read() then
    goto BRANCH_GAMMA  -- : BEQ BRANCH_GAMMA
  elseif A < y_dest:read() then
    goto BRANCH_DELTA  -- : BCC BRANCH_DELTA
  end
  tmp_y:dec() -- DEC $00
  A = A - 1  -- DEC A
  -- : CMP $7EC184
  if A == y_dest:read() then
    goto BRANCH_GAMMA  -- : BEQ BRANCH_GAMMA
  end
  tmp_y:dec()  -- DEC $00
  A = A - 1  -- DEC A
  goto BRANCH_GAMMA  -- BRA BRANCH_GAMMA
  ::BRANCH_DELTA::
  tmp_y:inc()  -- INC $00
  A = A + 1  -- INC A
  -- : CMP $7EC184
  if A == y_dest:read() then  -- : BEQ BRANCH_GAMMA
    goto BRANCH_GAMMA
  end
  tmp_y:inc()  -- INC $00
  A = A + 1  -- INC A
  ::BRANCH_GAMMA::
  player_y:write(A)  -- STA $20
  -- CMP $7EC184
  if A ~= y_dest:read() then
    goto BRANCH_EPSILON  -- : BNE BRANCH_EPSILON
  end
  A = player_x:read()  -- LDA $22
  -- : CMP $7EC186
  if A ~= x_dest:read() then
    goto BRANCH_EPSILON  -- : BNE BRANCH_EPSILON
  end

  -- TODO: what??!?!
  sub_submodule_index:inc()  -- INC $B0
  incap_timer:write(0)  -- STZ $46
  ::BRANCH_EPSILON::

  -- A is 8-bit  -- SEP #$20
  player_y_cycle:write(tmp_y:read())  -- LDA $00 : STA $30
  player_x_cycle:write(tmp_x:read())  -- LDA $02 : STA $31

  -- TODO? checking if we need to scroll the map, maybe?  FOR LATER
  unknown_function_BB90()  -- JSR $BB90 ; $13B90 IN ROM
  -- LDA $0416
  if scr_transition_bf2:read() == 0 then
    goto BRANCH_ZETA  -- : BEQ BRANCH_ZETA
  end
  Overworld_ScrollMap()  -- JSR Overworld_ScrollMap     ; $17273 IN ROM
  ::BRANCH_ZETA::
  return  -- RTS
end
