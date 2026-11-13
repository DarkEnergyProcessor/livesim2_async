return {
	name = "Lifeline",
	image = "ssr_heal.png",
	rarity = "SSR",
	appeal = 3400,
	stamina = 5600,
	tech = 3000,
	skill = {trigger = {hp_below = 0.5}, chance = 1, effects = {{type = "heal", fraction = 0.3}, {type = "combo_shield", value = 3}}},
}
