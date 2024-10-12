/obj/vehicle/sealed/armored/multitile/boris_upp
	name = "\improper MBT-波利斯 Boris"
	desc = "An old battle tank modernized for the needs of UPP, designed to effectively counter the largest possible list of possible enemies. A very formidable weapon in the hands of an experienced crew and very frightening for its own troops in the hands of not particularly experienced crew."
	icon = 'icons/obj/armored/3x3/tank_upp.dmi'
	turret_icon = 'icons/obj/armored/3x3/tank_gun_upp.dmi'
	damage_icon_path = 'icons/obj/armored/3x3/tank_damage_upp.dmi'
	max_integrity = 600
	permitted_weapons = list(/obj/item/armored_weapon/knyaz, /obj/item/armored_weapon/secondary_weapon/boris)
	soft_armor = list(MELEE = 50, BULLET = 99 , LASER = 99, ENERGY = 60, BOMB = 70, BIO = 60, FIRE = 50, ACID = 30)
	hard_armor = list(MELEE = 0, BULLET = 20, LASER = 20, ENERGY = 20, BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
	max_occupants = 3
	move_delay = 0.70 SECONDS
	ram_damage = 60
	permitted_mods = list(/obj/item/tank_module/overdrive, /obj/item/tank_module/ability/zoom/boris, /obj/item/tank_module/ability/zoom/boris/driver, /obj/item/tank_module/ability/smoke/tanglefoot/boris)
