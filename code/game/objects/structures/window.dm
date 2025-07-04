/obj/structure/window
	name = "window"
	desc = "A glass window. It looks thin and flimsy. A few knocks with anything should shatter it."
	icon = 'icons/obj/structures/windows.dmi'
	icon_state = "window"
	hit_sound = 'sound/effects/Glasshit.ogg'
	density = TRUE
	anchored = TRUE
	layer = WINDOW_LAYER
	obj_flags = CAN_BE_HIT | BLOCKS_CONSTRUCTION_DIR | IGNORE_DENSITY
	atom_flags = ON_BORDER|DIRLOCK
	allow_pass_flags = PASS_GLASS
	resistance_flags = XENO_DAMAGEABLE | DROPSHIP_IMMUNE
	coverage = 20
	max_integrity = 15
	/// If we're dismantling the window properly no smashy smashy
	var/dismantle = FALSE
	///Optimization for dynamic explosion block values, for things whose explosion block is dependent on certain conditions.
	var/real_explosion_block = 0
	var/state = 2
	var/reinf = FALSE
	var/basestate = "window"
	var/shardtype = /obj/item/shard
	var/windowknock_cooldown = 0
	/// If true, can't move the window
	var/static_frame = FALSE
	/// Because everything is terrible, I'm making this a window-level var
	var/junction = 0
	var/damageable = TRUE
	var/deconstructable = TRUE

/obj/structure/window/ex_act(severity, direction)
	take_damage(severity * EXPLOSION_DAMAGE_MULTIPLIER_WINDOW, BRUTE, BOMB, attack_dir = direction)

/obj/structure/window/on_explosion_destruction(severity, direction)
	if(severity < 2000)
		return

	playsound(src, "windowshatter", 50, 1)
	create_shrapnel(loc, rand(1, 5), direction, shrapnel_type = /datum/ammo/bullet/shrapnel/light/glass)

/obj/structure/window/get_explosion_resistance(direction)
	if(CHECK_BITFIELD(resistance_flags, INDESTRUCTIBLE))
		return EXPLOSION_MAX_POWER

	if(atom_flags & ON_BORDER && (direction == turn(dir, 90) || direction == turn(dir, -90)))
		return 0
	return obj_integrity / EXPLOSION_DAMAGE_MULTIPLIER_WINDOW

/obj/structure/window/add_debris_element()
	AddElement(/datum/element/debris, DEBRIS_GLASS, -40, 5)

//I hate this as much as you do
/obj/structure/window/full
	dir = 10
	atom_flags = DIRLOCK

/obj/structure/window/Initialize(mapload, start_dir, constructed)
	. = ..()

	//player-constructed windows
	if(constructed)
		anchored = FALSE
		state = 0

	if(start_dir)
		setDir(start_dir)

	var/static/list/connections = list(
		COMSIG_ATOM_EXIT = PROC_REF(on_try_exit)
	)
	AddElement(/datum/element/connect_loc, connections)

	return INITIALIZE_HINT_LATELOAD

/obj/structure/window/LateInitialize()
	. = ..()
	update_nearby_icons()

/obj/structure/window/Destroy()
	density = FALSE
	update_nearby_icons()
	return ..()

/obj/structure/window/hitby(atom/movable/AM, speed = 5)
	var/throw_damage = speed
	var/mob/living/thrown_mob
	if(isobj(AM))
		var/obj/thrown_obj = AM
		throw_damage = thrown_obj.throwforce
	else if(isliving(AM))
		thrown_mob = AM
		throw_damage *= thrown_mob.mob_size * 8
	take_damage(throw_damage)
	AM.stop_throw()
	. = TRUE
	if(thrown_mob)
		thrown_mob.take_overall_damage(speed * 5, BRUTE, MELEE, !., FALSE, TRUE, 0, 4) //done here for dramatic effect, and to make the damage sharp if we broke the window
	return TRUE

//TODO: Make full windows a separate type of window.
//Once a full window, it will always be a full window, so there's no point
//having the same type for both.
/obj/structure/window/proc/is_full_window()
	if(!(atom_flags & ON_BORDER) || ISDIAGONALDIR(dir))
		return TRUE
	return FALSE

/obj/structure/window/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	if(user.a_intent == INTENT_HARM)

		if(istype(user,/mob/living/carbon/human))
			var/mob/living/carbon/human/H = user
			if(H.species.can_shred(H))
				attack_generic(H, 25)
				return

		if(windowknock_cooldown > world.time)
			return
		playsound(loc, 'sound/effects/glassknock.ogg', 25, 1)
		user.visible_message(span_warning("[user] bangs against [src]!"),
		span_warning("You bang against [src]!"),
		span_warning("You hear a banging sound."))
		windowknock_cooldown = world.time + 100
	else
		if(windowknock_cooldown > world.time)
			return
		playsound(loc, 'sound/effects/glassknock.ogg', 15, 1)
		user.visible_message(span_notice("[user] knocks on [src]."),
		span_notice("You knock on [src]."),
		span_notice("You hear a knocking sound."))
		windowknock_cooldown = world.time + 100

/obj/structure/window/grab_interact(obj/item/grab/grab, mob/user, base_damage = BASE_OBJ_SLAM_DAMAGE, is_sharp = FALSE)
	if(!isliving(grab.grabbed_thing))
		return

	var/mob/living/grabbed_mob = grab.grabbed_thing
	var/state = user.grab_state
	user.drop_held_item()
	step_towards(grabbed_mob, src)
	var/damage = (user.skills.getRating(SKILL_CQC) * CQC_SKILL_DAMAGE_MOD)
	switch(state)
		if(GRAB_PASSIVE)
			damage += base_damage
			grabbed_mob.visible_message(span_warning("[user] slams [grabbed_mob] against \the [src]!"))
			log_combat(user, grabbed_mob, "slammed", "", "against \the [src]")
		if(GRAB_AGGRESSIVE)
			damage += base_damage * 1.5
			grabbed_mob.visible_message(span_danger("[user] bashes [grabbed_mob] against \the [src]!"))
			log_combat(user, grabbed_mob, "bashed", "", "against \the [src]")
			if(prob(50))
				grabbed_mob.Paralyze(2 SECONDS)
		if(GRAB_NECK)
			damage += base_damage * 2
			grabbed_mob.visible_message(span_danger("<big>[user] crushes [grabbed_mob] against \the [src]!</big>"))
			log_combat(user, grabbed_mob, "crushed", "", "against \the [src]")
			grabbed_mob.Paralyze(2 SECONDS)
	grabbed_mob.apply_damage(damage, blocked = MELEE, updating_health = TRUE)
	take_damage(damage * 2, BRUTE, MELEE)
	return TRUE

/obj/structure/window/screwdriver_act(mob/living/user, obj/item/I)
	. = ..()
	if(!deconstructable)
		return
	dismantle = TRUE
	if(reinf && state >= 1)
		state = 3 - state
		playsound(loc, 'sound/items/screwdriver.ogg', 25, 1)
		to_chat(user, (state == 1 ? span_notice("You have unfastened the window from the frame.") : span_notice("You have fastened the window to the frame.")))
	else if(reinf && state == 0 && !static_frame)
		anchored = !anchored
		update_nearby_icons()
		playsound(loc, 'sound/items/screwdriver.ogg', 25, 1)
		to_chat(user, (anchored ? span_notice("You have fastened the frame to the floor.") : span_notice("You have unfastened the frame from the floor.")))
	else if(!reinf && !static_frame)
		anchored = !anchored
		update_nearby_icons()
		playsound(loc, 'sound/items/screwdriver.ogg', 25, 1)
		to_chat(user, (anchored ? span_notice("You have fastened the window to the floor.") : span_notice("You have unfastened the window.")))
	else if(!reinf || (static_frame && state == 0))
		deconstruct(TRUE)

/obj/structure/window/crowbar_act(mob/living/user, obj/item/I)
	. = ..()
	if(!reinf)
		return
	if(state > 1)
		return
	if(!deconstructable)
		return
	dismantle = TRUE
	state = 1 - state
	playsound(loc, 'sound/items/crowbar.ogg', 25, 1)
	to_chat(user, (state ? span_notice("You have pried the window into the frame.") : span_notice("You have pried the window out of the frame.")))

/obj/structure/window/deconstruct(disassembled = TRUE, mob/living/blame_mob)
	if(disassembled)
		if(reinf)
			new /obj/item/stack/sheet/glass/reinforced(loc, 2)
		else
			new /obj/item/stack/sheet/glass/glass(loc, 2)
	else
		new shardtype(loc)
		if(is_full_window())
			new shardtype(loc)
		if(reinf)
			new /obj/item/stack/rods(loc)
	return ..()

/obj/structure/window/verb/rotate()
	set name = "Rotate Window Counter-Clockwise"
	set category = "IC.Rotate"
	set src in oview(1)

	if(static_frame)
		return FALSE
	if(!deconstructable)
		return FALSE
	if(anchored)
		to_chat(usr, span_warning("It is fastened to the floor, you can't rotate it!"))
		return FALSE

	setDir(turn(dir, 90))

/obj/structure/window/verb/revrotate()
	set name = "Rotate Window Clockwise"
	set category = "IC.Rotate"
	set src in oview(1)

	if(static_frame)
		return FALSE
	if(!deconstructable)
		return FALSE
	if(anchored)
		to_chat(usr, span_warning("It is fastened to the floor, you can't rotate it!"))
		return FALSE

	setDir(turn(dir, 270))

//This proc is used to update the icons of nearby windows.
/obj/structure/window/proc/update_nearby_icons()
	update_icon()
	for(var/direction in GLOB.cardinals)
		for(var/obj/structure/window/W in get_step(src, direction))
			INVOKE_NEXT_TICK(W, TYPE_PROC_REF(/atom/movable, update_icon))

//merges adjacent full-tile windows into one (blatant ripoff from game/smoothwall.dm)
/obj/structure/window/update_icon_state()
	. = ..()
	if(!src)
		return
	if(!is_full_window())
		icon_state = "[basestate]"
		return
	if(anchored)
		for(var/obj/structure/window/W in orange(src, 1))
			if(W.anchored && W.density	&& W.is_full_window()) //Only counts anchored, not-destroyed fill-tile windows.
				if(abs(x - W.x) - abs(y - W.y)) //Doesn't count windows, placed diagonally to src
					junction |= get_dir(src, W)
	if(opacity)
		icon_state = "[basestate][junction]"
	else
		if(reinf)
			icon_state = "[basestate][junction]"
		else
			icon_state = "[basestate][junction]"

/obj/structure/window/fire_act(burn_level, flame_color)
	if(burn_level > 25)
		take_damage(burn_level, BURN, FIRE)

/obj/structure/window/GetExplosionBlock(explosion_dir)
	return (!explosion_dir || ISDIAGONALDIR(dir) || dir & explosion_dir || REVERSE_DIR(dir) & explosion_dir) ? real_explosion_block : 0

/obj/structure/window/effect_smoke(obj/effect/particle_effect/smoke/S)
	. = ..()
	if(CHECK_BITFIELD(S.smoke_traits, SMOKE_XENO_ACID))
		take_damage(1 * S.strength, BURN, ACID) // glass doesn't care about acid

/obj/structure/window/get_dumping_location()
	return null

/obj/structure/window/phoronbasic
	name = "phoron window"
	desc = "A phoron-glass alloy window. It looks insanely tough to break. It appears it's also insanely tough to burn through."
	basestate = "phoronwindow"
	icon_state = "phoronwindow"
	shardtype = /obj/item/shard/phoron
	max_integrity = 120
	explosion_block = EXPLOSION_BLOCK_PROC
	real_explosion_block = 2

/obj/structure/window/phoronbasic/fire_act(burn_level, flame_color)
	if(burn_level > 30)
		take_damage(burn_level * 0.5, BURN, FIRE)

/obj/structure/window/phoronreinforced
	name = "reinforced phoron window"
	desc = "A phoron-glass alloy window with a rod matrice. It looks hopelessly tough to break. It also looks completely fireproof, considering how basic phoron windows are insanely fireproof."
	basestate = "phoronrwindow"
	icon_state = "phoronrwindow"
	shardtype = /obj/item/shard/phoron
	reinf = TRUE
	max_integrity = 160
	explosion_block = EXPLOSION_BLOCK_PROC
	real_explosion_block = 4

/obj/structure/window/phoronreinforced/fire_act(burn_level, flame_color)
	return

/obj/structure/window/reinforced
	name = "reinforced window"
	desc = "A glass window with a rod matrice. It looks rather strong. Might take a few good hits to shatter it."
	icon_state = "rwindow"
	basestate = "rwindow"
	max_integrity = 40
	reinf = TRUE
	explosion_block = EXPLOSION_BLOCK_PROC
	real_explosion_block = 2
	layer = ABOVE_MOB_LAYER
	///are we tinted or not
	var/tinted = FALSE

/obj/structure/window/reinforced/north
	dir = NORTH

/obj/structure/window/reinforced/west
	dir = WEST

/obj/structure/window/reinforced/east
	dir = EAST

/obj/structure/window/reinforced/Initialize(mapload)
	. = ..()
	if(dir == NORTH)
		add_overlay(image(icon, "rwindow_overlay", layer = WINDOW_LAYER))
		layer = WINDOW_FRAME_LAYER
	if(dir == WEST || dir == EAST)
		var/turf/adj = get_step(src, SOUTH)
		if(isclosedturf(adj))
			return
		if(locate(/obj/structure) in adj)
			return
		if(locate(/obj/machinery) in adj)
			return
		if(tinted)
			add_overlay(image(icon, "twindowstake", layer = ABOVE_ALL_MOB_LAYER))
			return
		add_overlay(image(icon, "windowstake", layer = ABOVE_ALL_MOB_LAYER))

/obj/structure/window/reinforced/windowstake/Initialize(mapload)
	. = ..()
	add_overlay(image(icon, "windowstake", layer = ABOVE_ALL_MOB_LAYER))

/obj/structure/window/reinforced/toughened
	name = "safety glass"
	desc = "A very tough looking glass window with a special rod matrice, probably bullet proof."
	icon_state = "rwindow"
	basestate = "rwindow"
	max_integrity = 300
	reinf = TRUE

//For the sulaco and POS AI core.
/obj/structure/window/reinforced/extratoughened
	name = "protective AI glass"
	desc = "Heavily reinforced glass with many layers of a rod matrice. This is rarely used for anything but the most important windows"
	icon_state = "rwindow"
	basestate = "rwindow"
	max_integrity = 1500
	reinf = TRUE
	resistance_flags = UNACIDABLE|XENO_DAMAGEABLE

/obj/structure/window/reinforced/tinted
	name = "tinted window"
	desc = "A glass window with a rod matrice. It looks rather strong and opaque. Might take a few good hits to shatter it."
	icon_state = "twindow"
	basestate = "twindow"
	opacity = TRUE
	tinted = TRUE

/obj/structure/window/reinforced/tinted/frosted
	name = "frosted window"
	desc = "A glass window with a rod matrice. It looks rather strong and frosted over. Looks like it might take a few less hits then a normal reinforced window."
	icon_state = "fwindow"
	basestate = "fwindow"
	max_integrity = 30

/obj/structure/window/shuttle
	name = "shuttle window"
	desc = "A shuttle glass window with a rod matrice specialised for heat resistance. It looks rather strong. Might take a few good hits to shatter it."
	icon = 'icons/obj/podwindows.dmi'
	icon_state = "window"
	basestate = "window"
	max_integrity = 40
	reinf = TRUE
	atom_flags = NONE

/obj/structure/window/shuttle/update_icon_state()
	return

//Framed windows

/obj/structure/window/framed
	name = "theoretical window"
	layer = TABLE_LAYER
	static_frame = TRUE
	atom_flags = NONE //This is not a border object; it takes up the entire tile.
	explosion_block = 2
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = list(
		SMOOTH_GROUP_WINDOW_FULLTILE,
		SMOOTH_GROUP_SURVIVAL_TITANIUM_WALLS,
	)
	canSmoothWith = list(
		SMOOTH_GROUP_SURVIVAL_TITANIUM_WALLS,
		SMOOTH_GROUP_WINDOW_FULLTILE,
		SMOOTH_GROUP_AIRLOCK,
		SMOOTH_GROUP_WINDOW_FRAME,
		SMOOTH_GROUP_ESCAPESHUTTLE,
	)
	///For perspective windows,so the window frame doesn't magically disappear.
	var/window_frame

/obj/structure/window/framed/update_nearby_icons()
	QUEUE_SMOOTH_NEIGHBORS(src)

/obj/structure/window/framed/update_icon_state()
	QUEUE_SMOOTH(src) //we update icon state through the smoothing system exclusively

/obj/structure/window/framed/deconstruct(disassembled = TRUE, leave_frame = TRUE)
	if(window_frame && leave_frame)
		var/obj/structure/window_frame/WF = new window_frame(loc, TRUE)
		WF.icon_state = "[WF.basestate][junction]_frame"
		WF.setDir(dir)
	return ..()

/obj/structure/window/framed/crushed_special_behavior()
	if(window_frame)
		return STOP_CRUSHER_ON_DEL
	else
		return ..()

/obj/structure/window/framed/mainship
	name = "reinforced window"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	icon = 'icons/obj/smooth_objects/ship_window.dmi'
	icon_state = "ship_window-0"
	basestate = "ship_window"
	base_icon_state = "ship_window"
	max_integrity = 100 //Was 600
	reinf = TRUE
	dir = 5
	window_frame = /obj/structure/window_frame/mainship

/obj/structure/window/framed/mainship/talos
	icon = 'icons/obj/smooth_objects/alt_ship_window.dmi'
	icon_state = "alt_ship_window-0"
	base_icon_state = "alt_ship_window"
	window_frame = /obj/structure/window_frame/mainship/talos

/obj/structure/window/framed/mainship/canterbury //So we can wallsmooth properly.

/obj/structure/window/framed/mainship/escapeshuttle
	smoothing_groups = list(SMOOTH_GROUP_ESCAPESHUTTLE)
	canSmoothWith = list(
		SMOOTH_GROUP_ESCAPESHUTTLE,
		SMOOTH_GROUP_WINDOW_FULLTILE,
	)

/obj/structure/window/framed/mainship/escapeshuttle/prison
	resistance_flags = RESIST_ALL
	icon_state = "window-invincible"

/obj/structure/window/framed/mainship/toughened
	name = "safety glass"
	desc = "A very tough looking glass window with a special rod matrice, probably bullet proof."
	max_integrity = 300

/obj/structure/window/framed/mainship/spaceworthy
	name = "cockpit window"
	desc = "A very tough looking glass window with a special rod matrice, made to be space worthy."
	max_integrity = 500
	icon_state = "ship_window-0"
	basestate = "ship_window"

/obj/structure/window/framed/mainship/spaceworthy/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/windowshutter/cokpitshutters)

/obj/structure/window/framed/mainship/hull
	name = "hull window"
	desc = "A glass window with a special rod matrice inside a wall frame. This one was made out of exotic materials to prevent hull breaches. No way to get through here."
	icon_state = "ship_window_invincible"
	damageable = FALSE
	deconstructable = FALSE
	resistance_flags = RESIST_ALL
	max_integrity = 1000000 //Failsafe, shouldn't matter

/obj/structure/window/framed/mainship/hull/canterbury //So we can wallsmooth properly.
	smoothing_groups = list(SMOOTH_GROUP_CANTERBURY)
	canSmoothWith = list(
		SMOOTH_GROUP_AIRLOCK,
		SMOOTH_GROUP_WINDOW_FRAME,
		SMOOTH_GROUP_WINDOW_FULLTILE,
		SMOOTH_GROUP_SHUTTERS,
		SMOOTH_GROUP_CANTERBURY,
	)

/obj/structure/window/framed/mainship/requisitions
	name = "kevlar-weave infused bulletproof window"
	desc = "A borosilicate glass window infused with kevlar fibres and mounted within a special shock-absorbing frame, this is gonna be seriously hard to break through."
	max_integrity = 1000
	deconstructable = FALSE

/obj/structure/window/framed/mainship/white
	icon = 'icons/obj/smooth_objects/wwindow.dmi'
	icon_state = "white_rwindow-0"
	base_icon_state = "white_rwindow"
	window_frame = /obj/structure/window_frame/mainship/white

/obj/structure/window/framed/mainship/white/canterbury //So we can wallsmooth properly.
	smoothing_groups = list(SMOOTH_GROUP_CANTERBURY)
	canSmoothWith = list(
		SMOOTH_GROUP_CANTERBURY,
		SMOOTH_GROUP_AIRLOCK,
	)

/obj/structure/window/framed/mainship/gray
	icon = 'icons/obj/smooth_objects/ship_gray_window.dmi'
	icon_state = "ship_gray_window-0"
	basestate = "ship_gray_window"
	base_icon_state = "ship_gray_window"
	window_frame = /obj/structure/window_frame/mainship/gray
	reinf = FALSE
	smoothing_groups = list(SMOOTH_GROUP_WINDOW_FULLTILE)
	canSmoothWith = list(
		SMOOTH_GROUP_WINDOW_FULLTILE,
		SMOOTH_GROUP_AIRLOCK,
		SMOOTH_GROUP_WINDOW_FRAME,
		SMOOTH_GROUP_ESCAPESHUTTLE,
		SMOOTH_GROUP_SURVIVAL_TITANIUM_WALLS,
	)

/obj/structure/window/framed/mainship/gray/toughened
	name = "safety glass"
	desc = "A very tough looking glass window with a special rod matrice, probably bullet proof."
	max_integrity = 300
	reinf = TRUE
	icon_state = "window-reinforced"
	basestate = "ship_gray_window"

/obj/structure/window/framed/mainship/gray/toughened/hull
	name = "hull window"
	desc = "A glass window with a special rod matrice inside a wall frame. This one was made out of exotic materials to prevent hull breaches. No way to get through here."
	damageable = FALSE
	deconstructable = FALSE
	resistance_flags = RESIST_ALL
	icon_state = "window-invincible"

/obj/structure/window/framed/mainship/gray/toughened/hull/talos
	icon = 'icons/obj/smooth_objects/alt_ship_rwindow.dmi'
	icon_state = "alt_ship_rwindow-0"
	base_icon_state = "alt_ship_rwindow"

/obj/structure/window/framed/mainship/white/toughened/hull
	name = "hull window"
	icon_state = "window-invincible"
	desc = "A glass window with a special rod matrice inside a wall frame. This one was made out of exotic materials to prevent hull breaches. No way to get through here."
	damageable = FALSE
	deconstructable = FALSE
	resistance_flags = RESIST_ALL

/obj/structure/window/framed/colony
	name = "window"
	icon = 'icons/obj/smooth_objects/col_window.dmi'
	icon_state = "col_window0"
	base_icon_state = "col_window"
	window_frame = /obj/structure/window_frame/colony

/obj/structure/window/framed/colony/reinforced
	name = "reinforced window"
	icon = 'icons/obj/smooth_objects/col_rwindow.dmi'
	icon_state = "window-reinforced"
	base_icon_state = "col_rwindow"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	max_integrity = 100
	reinf = 1
	window_frame = /obj/structure/window_frame/colony/reinforced

/obj/structure/window/framed/colony/reinforced/tinted
	name = "tinted reinforced window"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it. This one is opaque. You have an uneasy feeling someone might be watching from the other side."
	opacity = TRUE

/obj/structure/window/framed/colony/reinforced/hull
	name = "hull window"
	desc = "A glass window with a special rod matrice inside a wall frame. This one was made out of exotic materials to prevent hull breaches. No way to get through here."
	//icon_state = "rwindow0_debug" //Uncomment to check hull in the map editor
	damageable = FALSE
	deconstructable = FALSE
	resistance_flags = RESIST_ALL
	max_integrity = 1000000 //Failsafe, shouldn't matter
	icon_state = "window-invincible"

//Chigusa windows

/obj/structure/window/framed/chigusa
	name = "reinforced window"
	icon = 'icons/obj/smooth_objects/chigusa_window.dmi'
	icon_state = "window-reinforced"
	basestate = "chigusa_wall"
	base_icon_state = "chigusa_wall"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	max_integrity = 100
	reinf = TRUE
	window_frame = /obj/structure/window_frame/chigusa

/obj/structure/window/framed/wood
	name = "window"
	icon = 'icons/obj/smooth_objects/wood_regular.dmi'
	icon_state = "wood_regular-0"
	basestate = "wood_regular"
	base_icon_state = "wood_regular"
	window_frame = /obj/structure/window_frame/wood

/obj/structure/window/framed/wood/reinforced
	name = "reinforced window"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	max_integrity = 100
	reinf = TRUE
	icon = 'icons/obj/smooth_objects/wood_reinforced.dmi'
	icon_state = "wood_reinforced-0"
	basestate = "wood_reinforced"
	base_icon_state = "wood_reinforced"
	window_frame = /obj/structure/window_frame/wood

//Prison windows

/obj/structure/window/framed/prison
	name = "window"
	icon = 'icons/obj/smooth_objects/wood_reinforced.dmi'
	icon_state = "wood_reinforced-0"
	basestate = "wood_reinforced"
	base_icon_state = "wood_reinforced"
	window_frame = /obj/structure/window_frame/prison

/obj/structure/window/framed/prison/reinforced
	name = "reinforced window"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	max_integrity = 100
	reinf = TRUE
	icon = 'icons/obj/smooth_objects/prison_rwindow.dmi'
	icon_state = "window-reinforced"
	base_icon_state = "prison_rwindow"
	basestate = "prison_rwindow"
	window_frame = /obj/structure/window_frame/prison/reinforced

/obj/structure/window/framed/prison/reinforced/hull
	name = "hull window"
	desc = "A glass window with a special rod matrice inside a wall frame. This one has an automatic shutter system to prevent any atmospheric breach."
	max_integrity = 200
	//icon_state = "rwindow0_debug" //Uncomment to check hull in the map editor
	icon_state = "window-invincible"

/obj/structure/window/framed/prison/reinforced/hull/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/windowshutter)

/obj/structure/window/framed/prison/reinforced/nonshutter_hull
	name = "hull window"
	desc = "A glass window with a special rod matrice inside a wall frame. This one was made out of exotic materials to prevent hull breaches. No way to get through here."
	damageable = FALSE
	deconstructable = FALSE
	resistance_flags = RESIST_ALL

// dont even ask
/obj/structure/window/framed/prison/reinforced/hull/tyson
	icon_state = "col_window0"
	basestate = "col_window"
	window_frame = /obj/structure/window_frame/colony

// no really
/obj/structure/window/framed/prison/reinforced/hull/tyson/reinforced
	icon_state = "col_rwindow0"
	basestate = "col_rwindow"
	window_frame = /obj/structure/window_frame/colony/reinforced

/obj/structure/window/framed/prison/cell
	name = "cell window"
	icon = 'icons/obj/smooth_objects/cell_rwindow.dmi'
	icon_state = "prison_rwindow-0"
	base_icon_state = "prison_rwindow"
	basestate = "prison_rwindow"
	desc = "A glass window with a special rod matrice inside a wall frame. Has no reachable screws to prevent enterprising prisoners from deconstructing it."
	//icon_state = "rwindow0_debug" //Uncomment to check hull in the map editor
	deconstructable = FALSE
	max_integrity = 300

/obj/structure/window/framed/mainship/canterbury/dropship
	name = "orbital insertion safety window"
	desc = "A glass window with a reinforced rod matrice inside a wall frame, 3 times as strong as a normal window to be spaceworthy."
	max_integrity = 300 // 13 hunter slashes
	smoothing_groups = list(SMOOTH_GROUP_CANTERBURY)
	canSmoothWith = list(
		SMOOTH_GROUP_AIRLOCK,
		SMOOTH_GROUP_WINDOW_FRAME,
		SMOOTH_GROUP_WINDOW_FULLTILE,
		SMOOTH_GROUP_SHUTTERS,
		SMOOTH_GROUP_CANTERBURY,
	)
	window_frame = /obj/structure/window_frame/mainship/dropship

/obj/structure/window/framed/mainship/canterbury/dropship/reinforced
	name = "reinforced orbital insertion safety window"
	desc = "A durable glass window with a specialized reinforced rod matrice inside a wall frame, 6 times as strong as a normal window to be spaceworthy and withstand impacts."
	max_integrity = 600 // 25 hunter slashes

/obj/structure/window/framed/kutjevo
	name = "window"
	icon = 'icons/obj/smooth_objects/kutjevo_window_blue.dmi'
	icon_state = "chigusa_wall-0"
	base_icon_state = "chigusa_wall"
	window_frame = /obj/structure/window_frame/kutjevo

/obj/structure/window/framed/kutjevo/orange
	icon = 'icons/obj/smooth_objects/kutjevo_window_orange.dmi'

/obj/structure/window/framed/kutjevo/reinforced
	name = "reinforced window"
	icon = 'icons/obj/smooth_objects/kutjevo_window_blue_reinforced.dmi'
	icon_state = "window-reinforced"
	max_integrity = 100
	reinf = TRUE
	window_frame = /obj/structure/window_frame/kutjevo/reinforced

/obj/structure/window/framed/kutjevo/reinforced/orange
	icon = 'icons/obj/smooth_objects/kutjevo_window_orange_reinforced.dmi'

/obj/structure/window/framed/kutjevo/reinforced/hull
	name = "hull window"
	icon = 'icons/obj/smooth_objects/kutjevo_window_orange_reinforced.dmi'
	desc = "A glass window with a special rod matrice inside a wall frame. This one was made out of exotic materials to prevent hull breaches. No way to get through here."
	icon_state = "window-invincible"
	resistance_flags = RESIST_ALL

//pred
/obj/structure/window/framed/colony/reinforced/hull/pred
	basestate = "pred_window"
	icon_state = "pred_window-0"
	icon = 'icons/obj/smooth_objects/pred_window.dmi'
	base_icon_state = "pred_window"

/obj/structure/window/phoronreinforced/pred
	icon_state = "phoronrwindow"
	resistance_flags = INDESTRUCTIBLE
