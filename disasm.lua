#!/usr/bin/env lua

-- https://wiki.superfamicom.org/snes/show/65816+Reference
-- https://wiki.superfamicom.org/snes/show/Jay%27s+ASM+Tutorial

local ram = require 'ram'


local module_index = ram.Field(0x7E0010, 1, 'u')  -- unused?
local submodule_index = ram.Field(0x7E0011, 1, 'u')
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


-- Module_Overworld takes $11, shifts it left 1 bit, stores in X
-- then  jsr(.submodules, X), within pool Module_Overworld
--   dw $B528 ; = $13528*              ; 0x2A -
function Overworld_ScrollMap()
  -- via -- JSR Overworld_ScrollMap     ; $17273 IN ROM
  error('unimplemented')
end

function unknown_function_BB90()
  -- via -- JSR $BB90 ; $13B90 IN ROM
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
function jump_func_B528()
  local index = sub_submodule_index:read()
  if index == 0 then
    --  dw $B532 ; = $13532*
    complete_rewrite()
  elseif index == 1 then
    --  dw $9583 ; = $11583*
    unknown_function_9583()
  else
    error('probable crash')
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

  player_y_cycle.write(tmp_y:read())
  player_x_cycle.write(tmp_x:read())

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




function unknown_function_9583()

  -- via -- dw $9583 ; = $11583*
  error('unimplemented')
  -- A is 16-bit  -- REP #$20
  player_y:write(y_dest:read())  -- LDA $7EC184 : STA $20
  player_x:write(x_dest:read())  -- LDA $7EC186 : STA $22


  Field(0x7E0600, 2, 'u'):write(Field(0x7EC188, 2, 'u'):read())  -- LDA $7EC188 : STA $0600
  Field(0x7E0604, 2, 'u'):write(Field(0x7EC18A, 2, 'u'):read())  -- LDA $7EC18A : STA $0604
  Field(0x7E0608, 2, 'u'):write(Field(0x7EC18C, 2, 'u'):read())  -- LDA $7EC18C : STA $0608
  Field(0x7E060C, 2, 'u'):write(Field(0x7EC18E, 2, 'u'):read())  -- LDA $7EC18E : STA $060C
  Field(0x7E0610, 2, 'u'):write(Field(0x7EC190, 2, 'u'):read())  -- LDA $7EC190 : STA $0610
  Field(0x7E0612, 2, 'u'):write(Field(0x7EC192, 2, 'u'):read())  -- LDA $7EC192 : STA $0612
  Field(0x7E0614, 2, 'u'):write(Field(0x7EC194, 2, 'u'):read())  -- LDA $7EC194 : STA $0614
  Field(0x7E0616, 2, 'u'):write(Field(0x7EC196, 2, 'u'):read())  -- LDA $7EC196 : STA $0616
    
  -- LDA $1B : AND.w #$00FF
  if bit.band(ram.player_not_overworld:read(), 0xFF) == 0 then
    goto OUTDOORS  -- : BEQ .outdoors
  end
    
  Field(0x7E0618, 2, 'u'):write(Field(0x7EC198, 2, 'u'):read())  -- LDA $7EC198 : STA $0618
    
    INC #2 : STA $061A
    
    LDA $7EC19A : STA $061C
    
    INC #2 : STA $061E

  ::OUTDOORS::

    LDA $7EC19C : STA $A6
    LDA $7EC19E : STA $A9
    
    LDA $1B : AND.w #$00FF : BNE .indoors

    LDA $0618 : DEC #2 : STA $061A
    LDA $061C : DEC #2 : STA $061E

  ::INDOORS::

    SEP #$20
    
    LDA $7EC1A6 : STA $2F
    LDA $7EC1A7 : STA $EE
    
    LDA $7EC1A8 : STA $0476
    
    LDA $7EC1A9 : STA $6C
    
    LDA $7EC1AA : STA $A4
    
    STZ $4B
    
    LDA.b #$90 : STA $031F
    
    JSR $8EC9 ; $10EC9 IN ROM
    
    STZ $037B
    
    JSL $07984B ; $3984B IN ROM
    
    STZ $02F9
    
    JSL Tagalong_Init
    
    STZ $0642
    STZ $0200
    STZ $B0
    STZ $0418
    STZ $11
    
    LDA $7EF36D : BNE .notDead
    
    LDA.b #$00 : STA $7EF36D
    
    LDA $1C : STA $7EC211
    LDA $1D : STA $7EC212
    
    LDA $10 : STA $010C
    
    LDA.b #$12 : STA $10
    LDA.b #$01 : STA $11
    
    STZ $031F

.notDead

    RTS
end
