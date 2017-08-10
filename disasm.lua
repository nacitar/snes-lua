#!/usr/bin/env lua

-- https://wiki.superfamicom.org/snes/show/65816+Reference
-- https://wiki.superfamicom.org/snes/show/Jay%27s+ASM+Tutorial
-- http://problemkaputt.de/fullsnes.htm

local ram = require 'ram'

local srm_progress_indicator = ram.Unsigned(0x7EF3C5, 1)
  -- $0: Unset, Will put Link in his bed state at the beginning of
  --     the game. (Also can't use sword or shield)
  -- $1: You have a sword and start in the castle on start up.
  -- $2: Indicates you have completed the first Hyrule Castle dungeon.
  -- $3: Indicates you have beaten Agahnim and are now searching for crystals.
  -- $4 and above: meaningless. Though, you could write code using them to
  --     expand the event system perhaps.

local debug_wall_walk = ram.Unsigned(0x7E037F, 1)
    -- if nonzero, can walk over walls
local main_screen_designation = ram.Unsigned(0x7E001C, 1)
    -- Main Screen Designation (TM / $212C)
    -- uuusabcd
    -- u - Unused
    -- s - Sprite layer enabled
    -- a - BG4 enabled
    -- b - BG3 enabled
    -- c - BG2 enabled
    -- d - BG1 enabled
local mirror_main_screen_designation = ram.Unsigned(0x7EC211, 1)

local sub_screen_designation = ram.Unsigned(0x7E001D, 1)
    -- Sub Screen Designation (TS / $212D)
    -- uuusabcd
    -- u - Unused
    -- s - Sprite layer enabled
    -- a - BG4 enabled
    -- b - BG3 enabled
    -- c - BG2 enabled
    -- d - BG1 enabled

local window_mask_activation = ram.Unsigned(0x7E001E, 1)
  -- Window Mask Activation
local subscreen_window_mask_activation = ram.Unsigned(0x7E001F, 1)
  -- Subscreen Window Mask Activation
local mirror_sub_screen_designation = ram.Unsigned(0x7EC212, 1)

local module_index = ram.Unsigned(0x7E0010, 1)  -- unused?
local submodule_index = ram.Unsigned(0x7E0011, 1)
local sub_submodule_index = ram.Unsigned(0x7E00B0, 1)
local incap_timer = ram.Unsigned(0x7E0046, 1)  -- really 1?
local tmp_module_index = ram.Unsigned(0x7E010C, 1)  -- listed as 2

local ow_scr_transition_bf2 = ram.Unsigned(0x7E0416, 2)  -- values?
local ow_scr_transition_dir = ram.Unsigned(0x7E0418, 2)
    -- 0 = up, 1 = down, 2 = left, 3 = right
local sub_submodule_index_for_mode_E = ram.Unsigned(0x7E0200, 1)
local unknown_water_puzzle_flag = ram.Unsigned(0x7E0642, 1)
local tagalong_not_transforming = ram.Unsigned(0x7E02F9, 1)
    -- guess: 0 = is transforming, nonzero = otherwise

local hittable_by_sprites = ram.Unsigned(0x7E037B, 1)
    -- 0 = not hittable by sprites, 1 = hittable (always hittable by pits)
local link_sprite_blink_timer = ram.Unsigned(0x7E031F, 1)
    -- countdown timer that, if set, causes link's sprite to flash on/off
local link_visibility_state = ram.Unsigned(0x7E004B, 1)
    -- if set to 0x0C, link will disappear
local link_dungeon_floor = ram.Unsigned(0x7E00A4, 2)  -- as 1 byte some places
local link_in_doorway = ram.Unsigned(0x7E006C, 1)
    -- 0 = not in doorway, 1 = in vertical doorway, 2 = in horizontal doorway
local pseudo_bg_level = ram.Unsigned(0x7E0476, 1)  -- listed as 2byte, accessed as 1
    -- Indicates which "level" you are on, either BG1 or BG2. BG1 is
    -- considered 1 in many cases. However, there is no need for BG1
    -- necessarily. When Link can interact with BG1, this value should
    -- match $00EE, I think. This mostly applies to staircases in rooms that
    -- only use one BG to interact with.
local bg_level = ram.Unsigned(0x7E00EE, 1)
    -- in dungeons, 0 = upper level, 1 means lower level

-- controller 2
local filtered_jp2_main = ram.Unsigned(0x7E00F5, 1)  -- BYST|udlr
local filtered_jp1_secondary = ram.Unsigned(0x7E00F6, 1)  -- AXLR|????

local mirror_link_dungeon_floor_mirror = ram.Unsigned(0x7EC1AA, 2)
local mirror_player_facing = ram.Unsigned(0x7EC1A6, 1)
local mirror_bg_level = ram.Unsigned(0x7EC1A7, 1)
local mirror_pseudo_bg_level = ram.Unsigned(0x7EC1A8, 1)
local mirror_link_in_doorway = ram.Unsigned(0x7EC1A9, 1)

local mirror_y_scroll_lower_bound = ram.Unsigned(0x7EC198, 2)
local mirror_x_scroll_lower_bound = ram.Unsigned(0x7EC19A, 2)
local mirror_x_quadrant = ram.Unsigned(0x7EC19E, 2)
local mirror_unknown_dungeon_scroll_layout = ram.Unsigned(0x7EC19C, 2)

local y_scroll_lower_bound = ram.Unsigned(0x7E0618, 2)
local y_scroll_upper_bound = ram.Unsigned(0x7E061A, 2)
local x_scroll_lower_bound = ram.Unsigned(0x7E061C, 2)
local x_scroll_upper_bound = ram.Unsigned(0x7E061E, 2)

local x_quadrant = ram.Unsigned(0x7E00A9, 2)  -- listed 1, accessed 2
    -- 0 = left half, 1 = right half
local y_quadrant = ram.Unsigned(0x7E00AA, 2)  -- listed 1, accessed 2
    -- 0 = upper half, 2 = lower half
local unknown_dungeon_scroll_layout = ram.Unsigned(0x7E00A6, 2)
    -- Set to 0 or 2, but it depends upon the dungeon room's layout
    -- and the quadrant it was entered from. Further investigation
    -- seems to indicate that its purpose is to control the
    -- camera / scrolling
    -- boundaries in dungeons.

local y_dest = ram.Unsigned(0x7EC184, 2) -- name?
local x_dest = ram.Unsigned(0x7EC186, 2) -- name?

local unknown_y_related_01 = ram.Unsigned(0x7E0600, 2)
local unknown_y_related_02 = ram.Unsigned(0x7E0604, 2)

local unknown_x_related_01 = ram.Unsigned(0x7E0608, 2)
local unknown_x_related_02 = ram.Unsigned(0x7E060C, 2)

local tmp_y = ram.Signed(0x7E0000, 2)
local tmp_x = ram.Signed(0x7E0002, 2)
local player_x = ram.player_x  -- $22
local player_y = ram.player_y  -- $20
local player_y_cycle = ram.player_y_cycle  -- $30
local player_x_cycle = ram.player_x_cycle  -- $31


local transition_scroll_target_up = ram.Unsigned(0x7E00610, 2)
local transition_scroll_target_down = ram.Unsigned(0x7E00612, 2)
local transition_scroll_target_left = ram.Unsigned(0x7E00614, 2)
local transition_scroll_target_right = ram.Unsigned(0x7E00616, 2)

local bunny_transform_timer = ram.Unsigned(0x7E02E2, 1)

local link_sprite_is_bunny = ram.Unsigned(0x7E02E0, 1)
local mirror_link_sprite_is_bunny = ram.Unsigned(0x7E0056, 1)

local tempbunny_timer = ram.Unsigned(0x7E03F5, 2)
  -- The timer for Link's tempbunny state.
  -- When it counts down he returns to his normal state.
  -- When Link is hit it always falls to zero.
  -- Is always set to 0x100 when a yellow hunter (transformer) hits him.
  -- If Link is not in normal mode, however, it will have no effect on him.
  -- The value is given in frames, so if the value written is 0x80, you
  -- will be a bunny for 128 frames

local tempbunny_needs_poof = ram.Unsigned(0x7E03F7, 1)
  -- Flag indicating whether the "poof" needs to occur for Link to transform
  -- into the tempbunny.

local link_handler_state = ram.Unsigned(0x7E005D, 1)
  -- Link Handler or "State"
  -- 0x0 - ground state
  -- 0x1 - falling into a hole
  -- 0x2 - recoil from hitting wall / enemies
  -- 0x3 - spin attacking
  -- 0x4 - swimming
  -- 0x5 - Turtle Rock platforms
  -- 0x6 recoil again (other movement)
  -- 0x7 - hit by Agahnim<92>s bug zapper
  -- 0x8 - using ether medallion
  -- 0x9 - using bombos medallion
  -- 0xA - using quake medallion
  -- 0xB - ???
  -- 0xC - ???
  -- 0xD - ???
  -- 0xE - ???
  -- 0xF - ???
  -- 0x10 - ???
  -- 0x11 - falling off a ledge
  -- 0x12 - used when coming out of a dash by pressing a direction other than the dash direction
  -- 0x13 - hookshot
  -- 0x14 - magic mirror
  -- 0x15 - holding up an item
  -- 0x16 - asleep in his bed
  -- 0x17 - permabunny
  -- 0x18 - stuck under a heavy rock
  -- 0x19 - Receiving Ether Medallion
  -- 0x1A - Receiving Bombos Medallion
  -- 0x1B - Opening Desert Palace
  -- 0x1C - temporary bunny
  -- 0x1D - Rolling back from Gargoyle gate or PullForRupees object
  -- 0x1E - The actual spin attack motion.

local link_carrying_bitfield = ram.Unsigned(0x7E0308, 1)
  -- Bit 7 is set when Link is carrying something. Bit 1 set when Link is praying?
local link_pick_up_state = ram.Unsigned(0x7E0309, 1)
  -- 0: nothing. 1: picking up something. 2: throwing something or halfway done picking up something

local special_effects_array = ram.Array(0x7E0C4A, 1, 10)

local unknown_falling_hole_related = ram.Unsigned(0x7E02CA, 1)

local link_aux_state = ram.Unsigned(0x7E004D, 1)
  -- An Auxiliary Link handler.
  -- 0x00 - ground state (normal)
  -- 0x01 - the recoil status
  -- 0x02 - jumping in and out of water?
  -- 0x04 - swimming state.

local link_brandished_item = ram.Unsigned(0x7E0301, 1)
  -- bmuaethr
  -- When non zero, Link has something in his hand, poised to strike. It's
  -- intended that only one bit in this flag be set at any time, though.
  --
  --  b - Boomerang
  --  m - Magic Powder
  --  u - Unused
  --  a - Bow and Arrow
  --  e - Tested for, but doesn't seem to correspond to any actual item or
  --      action. Possibly could indicate an item that was cut from the game
  --      during development. It is, in fact, tested for simultaneously with
  --      the hammer in many locations. Perhaps this suggests another
  --      hammer-like item was in the works.
  --  t - Tested for exclusively with the 'r' bit, but no code seems to set this
  --      particular bit. Perhaps at one point the bits for the two rods were
  --      separate at some point?
  --  h - Hammer
  --  r - Ice Rod or Fire Rod

local link_pose = ram.Unsigned(0x7E037A, 1)
  -- Puts Link in various positions, 1 - shovel, 2 - praying, etc...
  -- cane of somaria. May also have something to do with bombs?

local some_debug_value_01 = ram.Unsigned(0x7E020B, 1)
  -- Seems to be a debug value for Module 0x0E.0x01

local unused_but_written_to_01 = ram.Unsigned(0x7E0350, 1)
  -- written to, but never read

local unknown_01 = ram.Unsigned(0x7E030D, 1)
  -- ???
local z_coordinate = ram.Unsigned(0x7E0024, 1)
  -- 0xFFFF usually, but if Link is elevated off the ground it is considered to
  -- be his Z coordinate. That is, it's his height off of the ground.
local unknown_02 = ram.Unsigned(0x7E0025, 1)
  -- ???  something to do with zoom when in attract mode, but unsure otherwise
local vertical_resistance = ram.Unsigned(0x7E0029, 1)
  -- vertical resistance
  -- (ATTRACT) Agahnim's base X coordinate relative to the screen.
local unknown_03 = ram.Unsigned(0x7E0300, 1)
  -- Link's state changes? Happens when using boomerang.
  -- Also related to electrocution maybe?
local unknown_04 = ram.Unsigned(0x7E02C6, 1)
  -- ???
local unknown_05 = ram.Unsigned(0x7E030D, 1)
  -- ???
local unknown_06 = ram.Unsigned(0x7E0302, 1)
  -- ???


local seems_always_0 = ram.Unsigned(0x7E030E, 1)
  -- Always seems to be set to 0, and only read during OAM handling
  -- of the player sprite.

local throwing_and_desert_step_counter = ram.Unsigned(0x7E030A, 1)
  -- Step counter used with $030B. Also, $030A-B seem to be used for the
  -- opening of the desert palace

local BY_button_bitfield = ram.Unsigned(0x7E003A, 1)
  -- Bitfield for the B and Y buttons
  -- hymuunub
  -- b - B button was pressed this frame, and not held down during the
  --     previous frame.
  -- u - Unused.
  -- n - Possible to be set, but not sure what it does
  -- m - Checked in one place, but not sure if it's ever set.
  -- y - The Y button has been held down for one or more frames.
  -- h - The B button has been held down for one or more frames.

local A_button_bitfield = ram.Unsigned(0x7E003B, 1)
  -- Bitfield for the A button
  -- auuduuuu
  -- a - The A button is down.
  -- u - Unused.
  -- d - Debug flag. Checked in one place, but never set.

local link_grabbing_wall = ram.Unsigned(0x7E0376, 1)
  -- bit 0: Link is grabbing a wall.
  -- bit 1 is ignored(cleared via and) before certain checks for some reason..
  --   .. and it's explicitly checked if set in another place!

-- TODO: should this be called "link_can_grab_something"?
local link_grabbing_at_something = ram.Unsigned(0x7E0048, 1)
  -- If set, when the A button is pressed, the player sprite will enter the
  -- "grabbing at something" state.
  -- bit 0 and 3 are checked together in some places.. what are they?!
  -- TODO: what are these bits?!!

local link_can_turn = ram.Unsigned(0x7E0050, 1)
  -- A flag indicating whether a change of the direction Link is facing is
  -- possible.  For example, when the B button is held down with a sword.
  -- 0 - Can change
  -- non zero - Can't change.
  -- NOTE: code seems to only check bit 0

local enemy_contact_electrocutes_link = ram.Unsigned(0x7E0360, 1)
  -- A flag that, when nonzero, causes Link to be electrocuted when
  -- touching an enemy.

local cape_mode = ram.Unsigned(0x7E0055, 1)
  -- Cape flag, when set, makes you invisible and invincible.
  -- You can also go through objects, such as bungies.

local attack_related_delay_timer = ram.Signed(0x7E003D, 1)
  -- A delay timer for the spin attack.
  -- Used between shifts to make the animation flow with the flash effect.
  -- Also used for delays between different graphics when swinging the sword.
  -- Decremented past 0 and checked for wrap around, so making it signed

local walking_dir_even_stationary = ram.Unsigned(0x7E0067, 1)
  -- Indicates which direction Link is walking (even if not going anywhere).
  -- ----udlr.
  -- u - Up
  -- d - Down
  -- l - Left
  -- r - Right

local moving_into_slanted_wall = ram.Unsigned(0x7E006B, 1)
  -- moving up against a \ wall: 0x1A
  -- moving right against a \ wall: 0x25
  -- moving down against a \ wall: 0x15
  -- moving left against a \ wall: 0x2A
  --
  -- moving up against a / wall: 0x19
  -- moving left against a / wall: 0x26
  -- moving right against a / wall: 0x29
  -- moving down against a / wall: 0x16

local debug_variable_always_0 = ram.Unsigned(0x7E0305, 1)
  -- Debug variable only seen in Bank 07. If not equal to 0x01, it will cause
  -- $1E and $1F to not be zeroed out every frame, which could cause some
  -- graphical oddities.

local unknown_master_sword_ceremony = ram.Unsigned(0x7E0377, 1)
  -- Related to the Master Sword ceremony somehow. Maybe other uses.

local maybe_link_is_transforming = ram.Unsigned(0x7E02E1, 1)
  -- Link is transforming? (Poofing in a cloud to transform into
  -- something else.)

local b_frames_held_and_spin_attack_nibble = ram.Unsigned(0x7E003C, 1)
  -- Lower Nibble: How many frames the B button has been held, approximately.
  -- Upper nibble: set to 9 on spin attack release.
  -- checked for equivalence to 0x09 in some places, and assigned 0x0A

local link_is_moving = ram.Unsigned(0x7E034A, 1)
  -- Flag indicating whether Link is moving or not. (I think)

local unknown_collision_related_01 = ram.Unsigned(0x7E0334, 1)
local unknown_collision_related_02 = ram.Unsigned(0x7E0335, 1)
local unknown_collision_related_03 = ram.Unsigned(0x7E0336, 1)
local unknown_collision_related_04 = ram.Unsigned(0x7E0337, 1)

local make_link_move = ram.Unsigned(0x7E0049, 1)
  -- This address is written to make Link move in any given direction. When
  -- indoors, it is cleared every frame. When outdoors, it is not cleared every
  -- frame so watch out.

local tired_of_pushing_wall_timer = ram.Unsigned(0x7E0371, 1)
  -- Countdown timer for frames it will take Link to become tired pushing
  -- against something solid. Once counted down, his appearance will look
  -- flushed and like he's dragging ass. Resets once you stop pushing or moving. 

local ledge_jump_timer = ram.Unsigned(0x7E0375, 1)
  -- This is the timer the is used to count down how long it takes before Link
  -- can jump off a ledge. It is typically set to 19 (0x13) frames, though I
  -- don't believe it decrements every frame.

local set_when_damaging_enemies = ram.Unsigned(0x7E0047, 1)
  -- Set when damaging enemies, unsure of exact usage yet.


local unknown_array_unknown_bounds = ram.Array(0x7E9CBF, 0x0A)
  -- Unknown... but it's indexed by 0x0A, so it's at least that big

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
  tmp_x:write(max_step(player_x:read(), x_dest:read()))
  tmp_y:write(max_step(player_y:read(), y_dest:read()))

  player_x:write(player_x:read() + tmp_x.read())
  player_y:write(player_y:read() + tmp_y.read())

  if player_y:read() == y_dest:read() and player_x:read() == x_dest:read() then
    sub_submodule_index:inc()  -- INC $B0
    incap_timer:write(0)  -- STZ $46
  end

  player_y_cycle:write(tmp_y:read())
  player_x_cycle:write(tmp_x:read())

  unknown_function_BB90()
  if ow_scr_transition_bf2:read() ~= 0 then
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
  -- TODO: these are being accessed as 8-bit
  player_y_cycle:write(tmp_y:read())  -- LDA $00 : STA $30
  player_x_cycle:write(tmp_x:read())  -- LDA $02 : STA $31

  -- TODO? checking if we need to scroll the map, maybe?  FOR LATER
  unknown_function_BB90()  -- JSR $BB90 ; $13B90 IN ROM
  -- LDA $0416
  if ow_scr_transition_bf2:read() ~= 0 then
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
  -- TODO: these are being accessed as 8-bit
  player_y_cycle:write(tmp_y:read())  -- LDA $00 : STA $30
  player_x_cycle:write(tmp_x:read())  -- LDA $02 : STA $31

  -- TODO? checking if we need to scroll the map, maybe?  FOR LATER
  unknown_function_BB90()  -- JSR $BB90 ; $13B90 IN ROM
  -- LDA $0416
  if ow_scr_transition_bf2:read() == 0 then
    goto BRANCH_ZETA  -- : BEQ BRANCH_ZETA
  end
  Overworld_ScrollMap()  -- JSR Overworld_ScrollMap     ; $17273 IN ROM
  ::BRANCH_ZETA::
  return  -- RTS
end

function unknown_function_9583()
  local A = nil

  -- via -- dw $9583 ; = $11583*
  error('unimplemented')
  -- A is 16-bit  -- REP #$20
  player_y:write(y_dest:read())  -- LDA $7EC184 : STA $20
  player_x:write(x_dest:read())  -- LDA $7EC186 : STA $22

  unknown_y_related_01:write(Unsigned(0x7EC188, 2):read())  -- LDA $7EC188 : STA $0600
  unknown_y_related_02:write(Unsigned(0x7EC18A, 2):read())  -- LDA $7EC18A : STA $0604
  unknown_x_related_01:write(Unsigned(0x7EC18C, 2):read())  -- LDA $7EC18C : STA $0608
  unknown_x_related_02:write(Unsigned(0x7EC18E, 2):read())  -- LDA $7EC18E : STA $060C
  transition_scroll_target_up:write(Unsigned(0x7EC190, 2):read())  -- LDA $7EC190 : STA $0610
  transition_scroll_target_down:write(Unsigned(0x7EC192, 2):read())  -- LDA $7EC192 : STA $0612
  transition_scroll_target_left:write(Unsigned(0x7EC194, 2):read())  -- LDA $7EC194 : STA $0614
  transition_scroll_target_right:write(Unsigned(0x7EC196, 2):read()) -- LDA $7EC196 : STA $0616

  -- LDA $1B : AND.w #$00FF
  if bit.band(ram.player_not_overworld:read(), 0xFF) == 0 then
    goto OUTDOORS  -- : BEQ .outdoors
  end

  A = mirror_y_scroll_lower_bound:read()  -- LDA $7EC198
  y_scroll_lower_bound:write(A)  -- : STA $0618
  A = A + 2  -- INC #2
  y_scroll_upper_bound:write(A)  -- : STA $061A

  A = mirror_x_scroll_lower_bound:read()  -- LDA $7EC19A
  x_scroll_lower_bound:write(A)  -- : STA $061C
  A = A + 2  -- INC #2
  x_scroll_upper_bound:write(A)  -- : STA $061E

  ::OUTDOORS::

  unknown_dungeon_scroll_layout:write(
      mirror_unknown_dungeon_scroll_layout:read())  -- LDA $7EC19C : STA $A6
  x_quadrant:write(mirror_x_quadrant:read())  -- LDA $7EC19E : STA $A9

  -- LDA $1B : AND.w #$00FF
  if bit.band(ram.player_not_overworld:read(), 0xFF) ~= 0 then
    goto INDOORS  -- : BNE .indoors
  end

  A = y_scroll_lower_bound:read()  -- LDA $0618
  A = A - 2  -- : DEC #2
  y_scroll_upper_bound:write(A)  -- : STA $061A

  A = x_scroll_lower_bound:read()  -- LDA $061C
  A = A - 2  -- : DEC #2
  x_scroll_upper_bound:write(A)  -- : STA $061E

  ::INDOORS::

  -- A is 8-bit  -- SEP #$20
  ram.player_facing:write(mirror_player_facing:read())  --  LDA $7EC1A6 : STA $2F
  bg_level:write(mirror_bg_level:read())  -- LDA $7EC1A7 : STA $EE
  pseudo_bg_level:write(mirror_pseudo_bg_level:read())  -- LDA $7EC1A8 : STA $0476

  link_in_doorway:write(mirror_link_in_doorway:read())  -- LDA $7EC1A9 : STA $6C
  link_dungeon_floor:write(mirror_link_dungeon_floor_mirror:read())  -- LDA $7EC1AA : STA $A4

  link_visibility_state:write(0)  -- STZ $4B

  A = 0x90  -- LDA.b #$90
  link_sprite_blink_timer:write(A)  -- : STA $031F

  unknown_8EC9()  -- JSR $8EC9 ; $10EC9 IN ROM

  hittable_by_sprites:write(0)  -- STZ $037B

  unknown_07984B()  -- JSL $07984B ; $3984B IN ROM

  tagalong_not_transforming:write(0)  -- STZ $02F9

  Tagalong_Init()  -- JSL Tagalong_Init

  unknown_water_puzzle_flag:write(0)  -- STZ $0642
  sub_submodule_index_for_mode_E:write(0)  -- STZ $0200
  sub_submodule_index:write(0)  -- STZ $B0
  ow_scr_transition_dir:write(0)  -- STZ $0418
  submodule_index:write(0)  -- STZ $11

  -- LDA $7EF36D
  if Unsigned(0x7EF36D, 1):read() ~= 0 then
    goto NOTDEAD  -- : BNE .notDead
  end

  Unsigned(0x7EF36D, 1):write(0)  --  LDA.b #$00 : STA $7EF36D
  mirror_main_screen_designation:write(main_screen_designation:read())  -- LDA $1C : STA $7EC211
  mirror_sub_screen_designation:write(sub_screen_designation:read())  -- LDA $1D : STA $7EC212

  tmp_module_index:write(module_index:read())  -- LDA $10 : STA $010C

  module_index:write(0x12)  -- LDA.b #$12 : STA $10
  submodule_index:write(0x01)  -- LDA.b #$01 : STA $11

  link_sprite_blink_timer:write(0)  -- STZ $031F

  ::NOTDEAD::
  return  -- RTS
end


function Player_ResetState(A)
  error('unimplemented')
  return A
end

-- NOTE: the 'return' is via carry.  If carry is set, you can't move
-- ; $382DA IN ROM; Checks whether Link can move.
-- ; *$382DA ALTERNATE ENTRY POINT
-- {
function can_move()
  local A = nil
  -- Pretty sure A is 8-bit here

  -- ; Has the tempbunny timer counted down yet?

  -- LDA $03F5 : ORA $03F6
  if tempbunny_timer:read() == 0 then  -- lua field reads 2 bytes, code reads 1
    -- TODO: where is this?
    goto ROUTINEABOVE_RETURN  -- : BEQ routineabove_return
  end

  -- ; Check if Link first needs to be transformed.
  if tempbunny_needs_poof:read() ~= 0 then  -- LDA $03F7
    --TODO: where is this?
    goto DOTRANSFORMATION  -- : BNE .doTransformation
  end

  -- ; Is Link a permabunny or tempbunny?
  A = link_handler_state:read()  -- LDA $5D

  if A == 0x17 then  -- CMP.b #$17
    -- 0x17 == permabunny
    goto INBUNNYFORM -- : BEQ .inBunnyForm
  end
  if A == 0x1C then -- CMP.b #$1C
    -- 0x1C == temporbunny
    goto INBUNNYFORM -- : BEQ .inBunnyForm
  end

  -- LDA $0309 : AND.b #$02
  if bit.band(link_pick_up_state:read(), 0x02) == 0 then
    goto NOTLIFTINGANYTHING  -- : BEQ .notLiftingAnything
  end

  link_carrying_bitfield:write(0)  -- STZ $0308

  ::NOTLIFTINGANYTHING::

  A = bit.band(link_carrying_bitfield:read(), 0x80)  -- LDA $0308 : AND.b #$80
  -- : PHA : JSL Player_ResetState : PLA
  A = Player_ResetState(A)
  link_carrying_bitfield:write(A)  -- : STA $0308

  X = 0x04  -- LDX.b #$04

  ::NEXTOBJECTSLOT::

  A = special_effects_array:read(X, false)  -- LDA $0C4A, X

  if A == 0x30 then  -- CMP.b #$30
    goto KILLBYRNAOBJECT  -- : BEQ .killByrnaObject
  end
  if A ~= 0x31 then  -- CMP.b #$31
    goto NOTBYRNAOBJECT  -- : BNE .notByrnaObject
  end

  ::KILLBYRNAOBJECT::
  special_effects_array:write(X, 0)  -- STZ $0C4A, X

  ::NOTBYRNAOBJECT::
  X = X - 1  -- DEX
  if X >= 0 then
    goto NEXTOBJECTSLOT  -- : BPL .nextObjectSlot
  end
  Player_HaltDashAttack()  -- JSR Player_HaltDashAttack
  Y = 0x04  -- LDY.b #$04
  A = 0x23  -- LDA.b #$23

  AddTransformationCloud()  --  JSL AddTransformationCloud ; $4912C IN ROM

  A = 0x14  -- LDA.b #$14
  Player_DoSfx2()  -- : JSR Player_DoSfx2

  -- ; It will take 20 frames for the transformation to finish
  bunny_transform_timer:write(0x14)  -- LDA.b #$14 : STA $02E2
  -- ; Indicate that a transformation is in progress by way of flags
  A = 0x01  -- LDA.b #$01
  hittable_by_sprites:write(A)  -- : STA $037B
  tempbunny_needs_poof:write(A)  -- : STA $03F7

  -- ; Make Link invisible during the transformation
  link_visibility_state:write(0x0C)  -- LDA.b #$0C : STA $4B

  ::DOTRANSFORMATION::

  -- ; $02E2 is a timer that counts down when Link changes shape.
  bunny_transform_timer:dec()  -- DEC $02E2

  if bunny_transform_timer:read() >= 0 then
    goto RETURN  -- : BPL .return
  end

  -- ; Turn Link into a temporary bunny
  link_handler_state:write(0x1C)  -- LDA.b #$1C : STA $5D

  -- ; Change Link's graphics to the bunny set
  A = 0x01  -- LDA.b #$01
  link_sprite_is_bunny:write(A)  -- : STA $02E0
  mirror_link_sprite_is_bunny:write(A)  -- : STA $56

  LoadGearPalettes_bunny()  -- JSL LoadGearPalettes.bunny

  link_visibility_state:write(0)  -- STZ $4B
  hittable_by_sprites:write(0)  -- STZ $037B

  -- ; Link no longer has to be changed into a bunny.
  tempbunny_needs_poof:write(0)  -- STZ $03F7

  goto RETURN  -- BRA .return

  ::INBUNNYFORM::

  -- ; Set the bunny timer to zero.
  -- takes 2 writes in asm as we're in 8-bit mode
  tempbunny_timer:write(0)  -- STZ $03F5 : STZ $03F6

  -- ; Link can move.
  return true -- CLC : RTS
  ::RETURN::
  -- ; Link can't move.
  return false -- SEC : RTS
end

-- ; *$3F514-$3F51C LOCAL
function cache_state_if_on_overworld()
  if ram.player_not_overworld:read() ~= 0 then
    goto INDOORS  -- LDA $1B : BNE .indoors
  end

  -- ; \task Find out why you'd only do this when outdoors...

  -- ; Caches a bunch of gameplay vars. I don't know why this is necessary
  -- ; during gameplay because this routine is surely time consuming.

  Player_CacheStatePriorToHandler()  -- JSL Player_CacheStatePriorToHandler
  ::INDOORS::
  return  -- RTS
end


-- ; *$3B5D6-$3B608 LONG
-- {
function unknown_B5D6()
  if bit.band(  -- LDA $3B : AND.b #$80
      A_button_bitfield:read(), 0x80) == 0 then
    goto ABUTTONNOTDOWN  -- : BEQ .aButtonNotDown
  end
  -- ; axlr----, bystudlr's distant cousin
  if bit.band(  -- LDA $F6 : AND.b #$80
      filtered_jp1_secondary:read(), 0x80) == 0 then
    goto ABUTTONNOTDOWN  -- : BEQ .aButtonNotDown
  end

  -- NOTE: this is basically "if picking up something", i think
  if bit.band(  -- LDA $0309 : AND.b #$01
      link_pick_up_state:read(), 0x01) ~= 0 then
    goto ABUTTONNOTDOWN  -- : BNE .aButtonNotDown
  end

  unknown_05:write(0)  -- STZ $030D
  seems_always_0:write(0)  -- STZ $030E
  throwing_and_desert_step_counter:write(0)  -- STZ $030A

  A_button_bitfield:write(0)  -- STZ $3B

  -- clear the low bit, so link can turn
  link_can_turn:write(  -- LDA $50 : AND.b #$FE : STA $50
      bit.band(link_can_turn:read(), 0xFE))

  -- ; appears to be a debug variable, so it should always be zero.
  -- LDA $0305 : CMP.b #$01
  if debug_variable_always_0:read() ~= 0x01 then
    goto DONT_DISABLE_MASKS  -- : BNE .dontDisableMasks
  end

  window_mask_activation:write(0)  -- STZ $1E
  subscreen_window_mask_activation:write(0)  -- STZ $1F

  ::DONT_DISABLE_MASKS::
  return true  -- SEC : RTS

  ::ABUTTONNOTDOWN::
  return false -- CLC : RTS
end


-- ; *$38109-$38364 JUMP LOCATION
-- {
-- RELEVANT: dw $8109 ; = $38109* 0x00 - Ground state (normal mode)
function ground_state_handler()  -- name?!
  cache_state_if_on_overworld()  -- JSR $F514 ; $3F514 IN ROM

  -- LDA $F5 : AND.b #$80
  if bit.band(filtered_jp2_main:read(), 0x80) == 0 then
    goto NOTDEBUGWALLWALK  -- : BEQ .notDebugWallWalk
  end

  -- ; \tcrf(confirmed, submitted) Debug feature where if you pressed the
  -- ; second control pad's B button It lets you walk through all walls.

  -- LDA $037F : EOR.b #$01 : STA $037F
  -- NOTE: could just set it to 1, i think
  debug_wall_walk:write(bit.bor(debug_wall_walk:read(), 0x01))

  ::NOTDEBUGWALLWALK::

  -- ; $382DA IN ROM; Checks whether Link can move.
  -- ; C clear = Link can move. C set = opposite.
  if can_move() then  -- JSR $82DA
    goto LINKCANMOVE  -- : BCC .linkCanMove
  end
  -- The below comments/labels are wrong, this is checking for PERMANENT BUNNY
  -- ; Link can't move... is Link in the Temp Bunny mode?
  -- ; No... so do nothing extra.
  if link_handler_state:read() ~= 0x17 then  -- LDA $5D : CMP.b #$17
    -- NOTE: the asm is incorrectly documented; this isn't tempbunny, it's
    -- permabunny mode!
    goto NOTPERMABUNNYCANTMOVE  -- : BNE .notTempBunnyCantMove
  end

  -- TODO ; How to handle a permabunny.
  -- TODO:  THIS IS ACTUALLY A GOTO IN THE CODE
  unknown_bunny_383A1()  -- BRL BRANCH_$383A1
  return -- ADDED THIS BECAUSE IT'S A JUMP

  ::NOTPERMABUNNYCANTMOVE::  -- .notTempBunnyCantMove

  return  -- RTS

  ::LINKCANMOVE::

  unknown_falling_hole_related:write(0)  -- STZ $02CA

  -- ; Is Link in a ground state? Yes...
  if link_aux_state:read() == 0 then  -- LDA $4D
    goto BRANCH_DELTA  -- : BEQ BRANCH_DELTA
  end


  -- ; *$38130 ALTERNATE ENTRY POINT

  link_brandished_item:write(0)  -- STZ $0301 ; Link is in some other submode.
  link_pose:write(0)  -- STZ $037A
  some_debug_value_01:write(0)  -- STZ $020B
  unused_but_written_to_01:write(0)  -- STZ $0350
  unknown_01:write(0)  -- STZ $030D
  seems_always_0:write(0)  -- STZ $030E
  throwing_and_desert_step_counter:write(0)  -- STZ $030A

  A_button_bitfield:write(0)  -- STZ $3B

  -- ; Ignore calls to the Y button in these submodes.
  -- This clears the 'Y' flag
  BY_button_bitfield:write(  -- LDA $3A : AND.b #$BF : STA $3A
      bit.band(BY_button_bitfield:read(), 0xBF))

  link_carrying_bitfield:write(0)  -- STZ $0308
  link_pick_up_state:write(0)  -- STZ $0309
  link_grabbing_wall:write(0)  -- STZ $0376

  link_grabbing_at_something:write(0)  -- STZ $48

  Player_ResetSwimState()  -- JSL Player_ResetSwimState

  -- clear the low bit (so link CAN turn)
  link_can_turn:write(  -- LDA $50 : AND.b #$FE : STA $50
      bit.band(link_can_turn:read(), 0xFE))

  unknown_02:write(0)  -- STZ $25

  if enemy_contact_electrocutes_link:read() == 0 then  -- LDA $0360
    goto BRANCH_EPSILON  -- : BEQ BRANCH_EPSILON
  end

  -- ; Is Link in cape mode?
  if cape_mode:read() == 0 then  -- LDA $55
    goto BRANCH_ZETA  -- : BEQ BRANCH_ZETA
  end

  unknown_cape_mode_function()  -- JSR $AE54 ; $3AE54 IN ROM; Link's in cape mode.

  ::BRANCH_ZETA::
  unknown_attack_related_function()  -- JSR $9D84 ; $39D84 IN ROM

  hittable_by_sprites:write(0x01)  -- LDA.b #$01 : STA $037B

  unknown_03:write(0)  -- STZ $0300

  attack_related_delay_timer:write(0x02)  -- LDA.b #$02 : STA $3D

  ram.animation_step_counter:write(0)  -- STZ $2E

  -- clears the low nibble... so no directions, I guess.. but why not just
  -- assign 0 if the high nibble is always zeroed?
  walking_dir_even_stationary:write(  -- LDA $67 : AND.b #$F0 : STA $67
      bit.band(walking_dir_even_stationary:read(), 0xF0))

  A = 0x2B  -- LDA.b #$2B
  Player_DoSfx3()  -- : JSR Player_DoSfx3

  -- ; Link got hit with the Agahnim bug zapper
  link_handler_state:write(0x07)  -- LDA.b #$07 : STA $5D

  -- ; GO TO ELECTROCUTION MODE
  -- TODO: this is actually a goto in the code!
  Player_Electrocution()  -- BRL Player_Electrocution
  return  -- NOTE: added this return, because the above was a GOTO

  ::BRANCH_EPSILON::

  -- ; Checking for indoors, but really \optimize Because it's doing nothing
  -- ; with this information. (Take out the branch)
  if ram.player_not_overworld:read() ~= 0 then  -- LDA $1B
    goto ZERO_LENGTH_BRANCH  -- : BNE .zero_length_branch
  end
  -- ; It is a secret to everybody.
  ::ZERO_LENGTH_BRANCH::

  moving_into_slanted_wall:write(0)  -- STZ $6B

  link_handler_state:write(0x02)  -- LDA.b #$02 : STA $5D

  -- TODO: this is actually a goto in the code!
  unknown_function_386B5()  --  BRL BRANCH_$386B5 ; go to recoil mode.
  return  -- NOTE: added this return, because the above was a GOTO

  -- ; Pretty much normal mode. Link standing there, ready to do stuff.
  ::BRANCH_DELTA::

  A = 0xFF  -- LDA.b #$FF
  z_coordinate:write(A)  -- : STA $24
  unknown_02:write(A)  -- STA $25
  vertical_resistance:write(A)  -- STA $29
  unknown_04:write(0)  -- STZ $02C6

  -- ; $3B5D6 IN ROM ; If Carry is set on Return, don't read the buttons.
  if unknown_B5D6() then  -- JSR $B5D6
    goto BRANCH_IOTA  -- : BCS BRANCH_IOTA
  end

  -- TODO: this function is well documented, but looks complex
  unknown_9BAA()  --  JSR $9BAA ; $39BAA IN ROM

  -- if grabbing a wall or carrying something
  if bit.bor(
      link_carrying_bitfield:read(),  -- LDA $0308
      link_grabbing_wall:read()) ~= 0 then  -- : ORA $0376
    goto BRANCH_IOTA  -- : BNE BRANCH_IOTA
  end

  if unknown_master_sword_ceremony:read() ~= 0 then  -- LDA $0377
    goto BRANCH_IOTA  -- : BNE BRANCH_IOTA
  end

  -- ; Is Link falling off of a ledge?    ; Yes...
  if link_handler_state:read() == 0x11 then  -- LDA $5D : CMP.b #$11
    goto BRANCH_IOTA  -- : BEQ BRANCH_IOTA
  end

  unknown_9B0E()  --  JSR $9B0E ; $39B0E IN ROM ; Handle Y button items?

  -- ; \hardcoded This is pretty unfair.
  -- ; \item Relates to ability to use the sword if you have one.
  -- If you haven't gotten the sword from your uncle yet (bed state)
  if srm_progress_indicator:read() == 0 then  -- LDA $7EF3C5
    goto CANT_USE_SWORD  -- : BEQ .cant_use_sword
  end

  Player_Sword()  -- JSR Player_Sword

  -- ; Is Link in spin attack mode?  No...
  if link_handler_state:read() ~= 0x03 then  -- LDA $5D : CMP.b #$03
    goto BRANCH_IOTA  -- : BNE BRANCH_IOTA
  end

  -- NOTE: I think this is basically what stops movement during spin attack

  ram.player_y_cycle:write(0)  -- STZ $30
  ram.player_x_cycle:write(0)  -- STZ $31

  unknown_382D2()  --  BRL BRANCH_$382D2
  return  -- NOTE: added this because above isn't a call, it's a goto

  ::CANT_USE_SWORD::
  ::BRANCH_IOTA::

  unknown_AE88()  -- JSR $AE88 ; $3AE88 IN ROM

  if incap_timer:read() == 0 then  -- LDA $46
    goto BRANCH_KAPPA  -- : BEQ BRANCH_KAPPA
  end

  -- This if seems pointless... it skips zeroing if already zero.. but why not
  -- just set it to zero and skip the check?
  if moving_into_slanted_wall:read() == 0 then  -- LDA $6B
    goto BRANCH_LAMBDA  -- : BEQ BRANCH_LAMBDA
  end
  moving_into_slanted_wall:write(0)  -- STZ $6B

  ::BRANCH_LAMBDA::

  unknown_05:write(0)  -- STZ $030D
  seems_always_0:write(0)  -- STZ $030E
  throwing_and_desert_step_counter:write(0)  -- STZ $030A
  A_button_bitfield:write(0)  -- STZ $3B
  link_pick_up_state:write(0)  -- STZ $0309
  link_carrying_bitfield:write(0)  -- STZ $0308
  link_grabbing_wall:write(0)  -- STZ $0376

  -- if B is down
  if bit.band(  -- LDA $3A : AND.b #$80
      BY_button_bitfield:read(), 0x80) ~= 0 then
    goto BRANCH_MU  -- : BNE BRANCH_MU
  end

  -- clear the low bit, so link can turn
  link_can_turn:write(  -- LDA $50 : AND.b #$FE : STA $50
      bit.band(link_can_turn:read(), 0xFE))

  ::BRANCH_MU::

  unknown_38711()  -- BRL BRANCH_$38711
  return -- NOTE: added this because above isn't a call, but a goto

  ::BRANCH_KAPPA::

  if unknown_master_sword_ceremony:read() == 0 then  -- LDA $0377
    goto BRANCH_NU  -- : BEQ BRANCH_NU
  end

  walking_dir_even_stationary:write(0)  -- STZ $67
  goto BRANCH_OMICRON  -- BRA BRANCH_OMICRON

  ::BRANCH_NU::

  if maybe_link_is_transforming:read() ~= 0 then  -- LDA $02E1
    goto BRANCH_OMICRON  -- : BNE BRANCH_OMICRON
  end

  -- TODO: this clears bit 1 before checking, but docs only show bit 0 being
  -- used to indicate grabbing a wall... why clear this bit?
  if bit.band(  -- LDA $0376 : AND.b #$FD
      link_grabbing_wall:read(), 0xFD) ~= 0 then
    goto BRANCH_OMICRON  -- : BNE BRANCH_OMICRON
  end

  -- TODO: Checks if any bits other than the high bit are set... high bit indicates
  -- carrying state, docs imply perhaps bit 1 is set when link is "praying"
  -- so I guess this is "if link is praying"?
  if bit.band(  -- LDA $0308 : AND.b #$7F
      link_carrying_bitfield:read(), 0x7F) ~= 0 then
    goto BRANCH_OMICRON  -- : BNE BRANCH_OMICRON
  end

  -- If link isn't carrying anything
  if bit.band(  -- LDA $0308 : AND.b #$80 : BEQ BRANCH_PI
      link_carrying_bitfield:read(), 0x80) == 0 then
    goto BRANCH_PI
  end

  -- If link is picking up something
  if bit.band(  -- LDA $0309 : AND.b #$01
      link_pick_up_state:read(), 0x01) ~= 0 then
    goto BRANCH_OMICRON  -- : BNE BRANCH_OMICRON
  end

  ::BRANCH_PI::

  if link_brandished_item:read() ~= 0 then  -- LDA $0301
    goto BRANCH_OMICRON  -- : BNE BRANCH_OMICRON
  end

  if link_pose:read() ~= 0 then  -- LDA $037A
    goto BRANCH_OMICRON  -- : BNE BRANCH_OMICRON
  end

  -- LDA $3C : CMP.b #$09
  if b_frames_held_and_spin_attack_nibble:read() >= 0x9 then
    goto BRANCH_RHO  -- : BCC BRANCH_RHO
  end

  -- TODO: checked bit documented as "checked in one place, not sure if ever set"
  if bit.band(  -- LDA $3A : AND.b #$20
      BY_button_bitfield:read(), 0x20) ~= 0 then
    goto BRANCH_RHO  -- : BNE BRANCH_RHO
  end

  -- if B button has been held down for one or more frames
  if bit.band(  -- LDA $3A : AND.b #$80
      BY_button_bitfield:read(), 0x80) == 0 then
    goto BRANCH_RHO  -- : BEQ BRANCH_RHO
  end

  ::BRANCH_OMICRON::
  goto BRANCH_PHI  -- BRA BRANCH_PHI

  ::BRANCH_RHO::

  if link_is_moving:read() == 0 then  -- LDA $034A
    goto BRANCH_TAU  -- : BEQ BRANCH_TAU
  end

  A = 0x01  -- LDA.b #$01
  unknown_collision_related_02:write(A)  -- : STA $0335
  unknown_collision_related_04:write(A)  -- : STA $0337
  A = 0x80  -- LDA.b #$80
  unknown_collision_related_01:write(A)  -- : STA $0334
  unknown_collision_related_03:write(A)  -- : STA $0336

  unknown_39715()  -- BRL BRANCH_$39715
  return -- ADDED because above is a branch, not a call

  ::BRANCH_TAU::

  Player_ResetSwimCollision()  -- JSR Player_ResetSwimCollision


  -- THIS A VALUE IS USED IN UPSILON
  A = bit.band(make_link_move:read(), 0x0F) -- LDA $49 : AND.b #$0F
  if A ~= 0 then  -- LDA $49 : AND.b #$0F
    goto BRANCH_UPLISON  -- : BNE BRANCH_UPSILON
  end

  if bit.band(  -- LDA $0376 : AND.b #$02
     link_grabbing_wall:read(), 0x02) ~= 0 then
    goto BRANCH_PHI  --  : BNE BRANCH_PHI
  end

  -- ; Branch if there are any directional buttons down.
  -- THIS A VALUE IS USED IN UPSILON
  A = bit.band(  -- LDA $F0 : AND.b #$0F
      ram.input_buffer_main:read(), 0x0F)

  if A ~= 0 then
    goto BRANCH_UPSILON  -- : BNE BRANCH_UPSILON
  end

  ram.player_y_cycle:write(A)  -- STA $30
  ram.player_x_cycle:write(A)  -- : STA $31
  walking_dir_even_stationary:write(A)  -- : STA $67
  ram.input_push_state:write(A)  -- : STA $26

  ram.animation_step_counter:write(0)  -- STZ $2E

  link_grabbing_at_something:write(bit.band(  -- LDA $48 : AND.b #$F0 : STA $48
      link_grabbing_at_something:read(), 0xF0))

  tired_of_pushing_wall_timer:write(0x20)  -- LDX.b #$20 : STX $0371

  -- ; Ledge countdown timer resets here because of lack of directional input...

  ledge_jump_timer:write(0x13)  -- LDX.b #$13 : STX $0375

  goto BRANCH_PHI  -- BRA BRANCH_PHI

  ::BRANCH_UPSILON::

  -- ; Store the directional data at $67. Is it equal to the previous reading?
  -- ; Yes, so branch.
  -- NOTE: A could be one of 2 different values from above, and is used again
  -- below in CHI
  walking_dir_even_stationary:write(A)  -- STA $67
  if A == ram.input_push_state:read() then  -- : CMP $26
    goto BRANCH_CHI  -- : BEQ BRANCH_CHI
  end

  -- ; If the reading changed, we have to do all this.
  ram.player_y_cycle_index:write(0)  -- STZ $2A
  ram.player_x_cycle_index:write(0)  -- STZ $2B
  moving_into_slanted_wall:write(0)  -- STZ $6B
  link_grabbing_at_something:write(0)  -- STZ $48

  tired_of_pushing_wall_timer:write(0x20)  -- LDX.b #$20 : STX $0371

  -- ; Reset ledge timer here because direction of ... (automated?) player
  -- ; changed?
  ledge_jump_timer:write(0x13)  -- LDX.b #$13 : STX $0375

  ::BRANCH_CHI::

  -- NOTE: A is the same value as it was in UPSILON
  ram.input_push_state:write(A)  -- STA $26

  ::BRANCH_PHI::

  unknown_B64F()  -- JSR $B64F   ; $3B64F IN ROM
  unknown_07E245()  -- JSL $07E245 ; $3E245 IN ROM
  unknown_B7C7()  -- JSR $B7C7   ; $3B7C7 IN ROM; Has to do with opening chests.
  unknown_07E6A6()  -- JSL $07E6A6 ; $3E6A6 IN ROM

  if unknown_master_sword_ceremony:read() == 0 then  -- LDA $0377
    goto BRANCH_PSI  -- : BEQ BRANCH_PSI
  end

  player_y_cycle:write(0)  -- STZ $30
  player_x_cycle:write(0)  -- STZ $31

  -- ; *$382D2 LONG BRANCH LOCATION
  ::BRANCH_PSI::

  unknown_06:write(0)  -- STZ $0302

  unknown_E8F0()  -- JSR $E8F0 ; $3E8F0 IN ROM

  ::BRANCH_OMEGA::

  -- TODO: WHY CLEAR THIS?  Do callers check for it?!
  C = 0  -- CLC

  return  -- RTS
end

--; *$39D84-$39E62 LOCAL
--{
-- NOTE: The alternate entry point uses 'A' as an argument!
function unknown_attack_related_function()
  ::BRANCH_EPSILON::

  -- ; Bring Link to stop
  -- Set movement type to 'normal'
  player_movement_type:write(0)  -- STZ $5E

  -- TODO: Clear bit 0 and 3 for some unknown reason??
  link_grabbing_at_something:write(bit.band(  -- LDA $48 : AND.b #$F6 : STA $48
      link_grabbing_at_something:read(), 0xF6))

  -- ; Stop any animations Link is doing
  attack_related_delay_timer:write(0)  -- STZ $3D
  b_frames_held_and_spin_attack_nibble:write(0)  -- STZ $3C

  -- ; Nullify button input on the B button
  -- clears both B pressed this frame, and B held down one or more frames
  BY_button_bitfield:write(bit.band(  -- LDA $3A : AND.b #$7E : STA $3A
      BY_button_bitfield:read(), 0x7E))

  -- ; Make it so Link can change direction if need be
  -- clears the low bit
  link_can_turn:write(bit.band(  -- LDA $50 : AND.b #$FE : STA $50
      link_can_turn:read(), 0xFE))

  goto BRANCH_ALPHA  -- BRL BRANCH_ALPHA

  -- ; *$39D9F ALTERNATE ENTRY POINT

  A=nil  -- TODO: PASSED IN
  -- NOTE: A isn't set in this function, must be set prior to calling
  if bit.band(A, link_grabbing_at_something:read()) ~= 0 then  -- BIT $48
    goto BRANCH_BETA  -- : BNE BRANCH_BETA
  end

  -- if bits 0 or 3 are set  (but what are these bits?!)
  if bit.band(  -- LDA $48 : AND.b #$09
      link_grabbing_at_something:read(), 0x09) ~= 0 then
    goto BRANCH_GAMMA  -- : BNE BRANCH_GAMMA
  end

  ::BRANCH_BETA::

  A = set_when_damaging_enemies:read()  -- LDA $47
  if A == 0 then
    goto BRANCH_DELTA  -- : BEQ BRANCH_DELTA
  end
  if A == 0x01 then  -- CMP.b #$01
    goto BRANCH_EPSILON  -- : BEQ BRANCH_EPSILON
  end

  ::BRANCH_GAMMA::

  -- LDA $3C : CMP.b #$09
  if b_frames_held_and_spin_attack_nibble:read() ~= 0x09 then
    goto BRANCH_ZETA  -- : BNE BRANCH_ZETA
  end

  X = 0xA  -- LDX.b #$0A
  b_frames_held_and_spin_attack_nibble:write(0x0A)  -- STX $3C

  attack_related_delay_timer:write(  -- LDA $9CBF, X : STA $3D
      unknown_array_unknown_bounds:read(X, false))

  ::BRANCH_ZETA::

  attack_related_delay_timer:dec()  -- DEC $3D
  if attack_related_delay_timer:read() >= 0 then
    goto BRANCH_THETA  -- BPL BRANCH_THETA
  end

    LDA $3C : INC A : CMP.b #$0D : BNE BRANCH_KAPPA

    LDA $7EF359 : INC A : AND.b #$FE : BEQ BRANCH_LAMBDA

    LDA $48 : AND.b #$09 : BEQ BRANCH_LAMBDA

    LDY.b #$01
    LDA.b #$1B

    JSL AddWallTapSpark ; $49395 IN ROM

    LDA $48 : AND.b #$08 : BNE BRANCH_MUNU

    LDA $05 : JSR Player_DoSfx2

    BRA BRANCH_XI

BRANCH_MUNU:

    LDA.b #$06 : JSR Player_DoSfx2

BRANCH_XI:

    ; Do sword interaction with tiles
    LDY.b #$01

    JSR $D077   ; $3D077 IN ROM

BRANCH_LAMBDA:

    LDA.b #$0A

BRANCH_KAPPA:

    STA $3C : TAX

    LDA $9CBF, X : STA $3D

BRANCH_THETA:

    BRA BRANCH_RHO

BRANCH_DELTA:

    LDA.b #$09 : STA $3C

    LDA.b #$01 : TSB $50

    STZ $3D

    LDA $5E

    CMP.b #$04 : BEQ BRANCH_RHO
    CMP.b #$10 : BEQ BRANCH_RHO

    LDA.b #$0C : STA $5E

    LDA $7EF359 : INC A : AND.b #$FE : BEQ BRANCH_ALPHA

    LDX.b #$04

BRANCH_PHI:

    LDA $0C4A, X

    CMP.b #$30 : BEQ BRANCH_ALPHA
    CMP.b #$31 : BEQ BRANCH_ALPHA

    DEX : BPL BRANCH_PHI

    LDA $79 : CMP.b #$06 : BCC BRANCH_CHI

    LDA $1A : AND.b #$03 : BNE BRANCH_CHI

    JSL AncillaSpawn_SwordChargeSparkle

BRANCH_CHI:

    LDA $79 : CMP.b #$40 : BCS BRANCH_ALPHA

    INC $79 : LDA $79 : CMP.b #$30 : BNE BRANCH_ALPHA

    LDA.b #$37 : JSR Player_DoSfx2

    JSL AddChargedSpinAttackSparkle

    BRA BRANCH_ALPHA

BRANCH_RHO:

    JSR $9E63 ; $39E63 IN ROM

BRANCH_ALPHA:

    RTS
}

; *$39E63-$39EEB LOCAL
{
    ; sword
    LDA $7EF359 : BEQ BRANCH_39D84_BRANCH_ALPHA ; RTS
    CMP.b #$FF  : BEQ BRANCH_39D84_BRANCH_ALPHA

    CMP.b #$02 : BCS BRANCH_ALPHA

BRANCH_GAMMA:

    LDY.b #$27

    LDA $3C : STA $02 : STZ $03

    CMP.b #$09 : BEQ BRANCH_39D84_BRANCH_ALPHA : bCC BRANCH_BETA

    LDA $02 : SUB.b #$0A : STA $02

    LDY.b #$03

BRANCH_BETA:

    REP #$30

    LDA $2F : AND.w #$00FF : TAX

    LDA $0DA030, X : STA $04

    TYA : AND.w #$00FF : ASL A : ADD $04 : TAX

    LDA $0D9EF0, X : ADD $02 : TAX

    SEP #$20

    LDA $0D98F3, X : STA $44
    LDA $0D9AF2, X : STA $45

    SEP #$10

    RTS

BRANCH_ALPHA:

    LDA $3C : CMP.b #$09 : BCS BRANCH_GAMMA

    ASL A : STA $04

    LDA $2F : LSR A : STA $0E

    ASL #3 : ADD $0E : ASL A : ADD $04 : TAX

    LDA $0DAC45, X : CMP.b #$FF : BEQ BRANCH_DELTA

    TXA : LSR A : TAX

    LDA $0DAC8D, X : STA $44
    LDA $0DACB1, X : STA $45

parallel pool LinkItem_Rod:

.quick_return

    RTS

BRANCH_DELTA:

    BRL BRANCH_GAMMA
}

; *$39B0E-$39B91 LOCAL
{
    LDA $3C    : BEQ BRANCH_ALPHA
    CMP.b #$09 : BCC BRANCH_39AE5

BRANCH_ALPHA:

    LDA $02E0 : BEQ BRANCH_BETA

    LDA $0303

    CMP.b #$0B : BEQ BRANCH_BETA
    CMP.b #$14 : BEQ BRANCH_BETA

    RTS

BRANCH_BETA:

    LDY $03FC : BEQ BRANCH_GAMMA

    LDA $02E0 : BNE BRANCH_GAMMA

    CPY.b #$02 : BEQ BRANCH_DELTA

    BRL LinkItem_Shovel

BRANCH_DELTA:

    BRL LinkItem_Bow

BRANCH_GAMMA:

    LDY $0304 : CMP $0303 : BEQ BRANCH_EPSILON

    LDA $0304 : CMP.b #$08 : BNE BRANCH_ZETA

    ; Does Link have the flute?
    LDA $7EF34C : AND.b #$02 : BEQ BRANCH_ZETA

    LDA $3A : AND.b #$BF : STA $3A

BRANCH_ZETA:

    LDA $0304 : CMP.b #$13 : BNE BRANCH_EPSILON

    LDA $55 : BEQ BRANCH_EPSILON

    JSR $AE47 ; $3AE47 IN ROM

BRANCH_EPSILON:

    LDA $0301 : ORA $037A : BNE BRANCH_THETA

    LDY $0303 : STY $0304

BRANCH_THETA:

                 BEQ BRANCH_IOTA
    CPY.b #$05 : BEQ BRANCH_KAPPA
    CPY.b #$06 : BNE BRANCH_LAMBDA

BRANCH_KAPPA:

    ; Only gets triggered if the previous item was one of the rods.
    LDA $0304 : SUB.b #$05 : INC A : STA $0307

BRANCH_LAMBDA:

    DEY : BMI BRANCH_IOTA

    TYA : ASL A : TAX

    JMP ($9AE6, X) ; $39AE6, X; USE JUMP TABLE

BRANCH_IOTA:

    RTS
}

; *$3AE88-$3AEBF LOCAL
{
    LDA $0308 : AND.b #$80 : BEQ BRANCH_BETA

; *$3AE8F ALTERNATE ENTRY POINT

    ; Check Link's invincibility status.
    ; He's not in the cape form..
    LDA $55 : BEQ BRANCH_BETA

    ; He is in cape form (invisible and invincible).
    ; Does Link need to transform into the cape form?
    LDA $0304 : CMP.b #$13 : BNE BRANCH_BETA

    ; Link might need to transform, but if he's already transformed, then not.
    CMP $0303 : BNE BRANCH_GAMMA

    ; It seems to me that the load is unnecessary... correct me if I'm
    ; wrong.
    DEC $4C : LDA $4C : BNE BRANCH_DELTA

    LDA $7EF37B : TAY

    LDA LinkItem_Cape.mp_depletion_timers, Y : STA $4C

    LDA $7EF36E : BEQ BRANCH_DELTA

    DEC A : STA $7EF36E : BNE BRANCH_DELTA

BRANCH_GAMMA:

    JSR $AE47 ; $3AE47 IN ROM

BRANCH_DELTA:

    RTS
}
