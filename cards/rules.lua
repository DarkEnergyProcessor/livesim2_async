-- Global scoring rules. Edit freely; the game reads this at the start of every live.
-- A copy of this file in the save folder's "cards" directory overrides this one.
return {
	-- Note score = appeal * appealScale * judgement * comboBonus * crit * (1 + scoreUp mods)
	-- appeal is the card in the lane the note lands on.
	appealScale = 0.1,

	judgement = {
		perfect = 1.0,
		great   = 0.88,
		good    = 0.7,
		bad     = 0.4,
		miss    = 0,
	},

	-- Combo bonus tiers: {combo at which the tier starts, multiplier}
	comboBonus = {
		{0,   1.00},
		{10,  1.05},
		{30,  1.10},
		{50,  1.15},
		{100, 1.20},
		{200, 1.25},
		{300, 1.30},
		{500, 1.35},
	},

	-- Hold releases and simultaneous notes
	holdBonus = 1.25,
	swingPenalty = 0.5,

	-- Crits. Chance comes from the card's tech: chance = tech * techToCritChance
	-- (5000 tech -> 25%). Crit-profile cards (tech > appeal) get critProfileBonus extra.
	techToCritChance = 0.00005,
	critProfileBonus = 0.15,
	critMultiplier = 1.5,
	maxCritChance = 0.95,

	-- HP. Team HP = sum of stamina * staminaScale; damage is a fraction of max HP.
	staminaScale = 1.0,
	damage = {
		perfect = 0,
		great   = 0,
		good    = 0.01,
		bad     = 0.03,
		miss    = 0.05,
	},
	starDamageMultiplier = 2,

	-- Skills whose trigger is ready fire at this chance on a key note (1 = always)
	keyNoteChance = 1.0,

	-- Cards with no "trigger" field get this one
	defaultTrigger = {notes = 20},
}
