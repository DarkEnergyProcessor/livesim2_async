return {
	name = "Encore",
	image = "ur_key.png",
	rarity = "UR",
	appeal = 5200,
	stamina = 3400,
	tech = 4600,
	skill = {trigger = {key = true}, chance = 1, effects = {{type = "score_mult", value = 2.0, duration = 10}, {type = "crit_chance_up", value = 0.3, duration = 10}}},
	passives = {{type = "skill_chance_up", value = 0.05, scope = "team"}},
}
