/obj/structure/lamarr
	name = "Lab Cage"
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "labcage1"
	desc = "A glass lab container for storing interesting creatures."
	density = TRUE
	anchored = TRUE
	resistance_flags = UNACIDABLE
	max_integrity = 30
	var/occupied = FALSE

/obj/structure/lamarr/deconstruct(disassembled = TRUE, mob/living/blame_mob)
	new /obj/item/shard(loc)
	if(occupied)
		new /obj/item/clothing/mask/facehugger/lamarr(loc)
		occupied = FALSE
		icon_state = "labcageb0"
	if(disassembled)
		return ..()

/obj/structure/lamarr/destroyed
	icon_state = "labcageb0"
	density = FALSE
	occupied = FALSE

/obj/structure/lamarr/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	user.visible_message(span_warning("[user] kicks the lab cage."), span_notice("You kick the lab cage."))
	take_damage(2, BRUTE, MELEE)

/obj/item/clothing/mask/facehugger/lamarr
	name = "Lamarr"
	desc = "The worst she might do is attempt to... couple with your head."//hope we don't get sued over a harmless reference, rite?
	sterile = TRUE
	gender = FEMALE

/obj/item/clothing/mask/facehugger/lamarr/check_lifecycle()
	return TRUE
