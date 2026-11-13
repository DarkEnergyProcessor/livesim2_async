# Cards

Each `.lua` file here is one card. Put your own cards (and their images) in the
`cards` folder inside the game's save directory; files there override these.
`rules.lua` holds the global scoring numbers.

```lua
return {
	name    = "Kanan - Dancing Night",   -- shown in menus
	image   = "kanan_dn.png",            -- square image in the same folder
	rarity  = "UR",                      -- R / SR / SSR / UR (cut-in style only)
	appeal  = 5200,                      -- score when a note lands on this card's lane
	stamina = 3100,                      -- adds to team HP
	tech    = 5900,                      -- crit chance; tech > appeal = crit profile (+15%)

	skill = {
		text    = "Every 15 notes: 33% chance of +4000 score",   -- optional, auto-generated if missing
		trigger = {notes = 15},   -- see triggers below
		chance  = 0.33,
		effects = {
			{type = "score", value = 4000},
			{type = "score_mult", value = 1.5, duration = 8, scope = "lane"},
		},
	},

	passives = {                 -- always on; "scope" defaults to "lane" (this card only)
		{type = "crit_damage_up", value = 0.10, scope = "team"},
	},
}
```

## Triggers

| trigger             | fires                                           |
|---------------------|-------------------------------------------------|
| `{notes = N}`       | every N notes (hit or missed)                   |
| `{combo = N}`       | every N combo (counter resets on a combo break) |
| `{perfect = N}`     | every N perfects                                |
| `{great = N}` etc.  | every N of that judgement                       |
| `{crit = N}`        | every N crits (any lane)                        |
| `{lane_notes = N}`  | every N notes on this card's own lane           |
| `{time = N}`        | every N seconds                                 |
| `{score = N}`       | every N points scored                           |
| `{hp_below = 0.5}`  | once, the first time HP drops below 50%         |
| `{start = true}`    | once, when the live starts                      |
| `{key = true}`      | only on key notes (always ready)                |

Key notes come from `keynotes/<beatmap file name>.lua` in the save folder, a
list of `{start, stop}` times in seconds (the song's "key part"). On the first
key note of a section, every ready skill fires at `keyNoteChance` (default
100%): `key` skills are always ready, counter skills are ready when their
counter is at least half full. Each skill fires at most once per section.

A timed effect fired again by the same card refreshes its duration instead of
stacking. Effects from different cards do stack.

## Effects

Every effect takes an optional `duration` (seconds; omit for instant effects)
and `scope` (`"lane"` = this card's lane, `"team"` = every lane; default `"team"`).

| type               | value means                                            |
|--------------------|--------------------------------------------------------|
| `score`            | flat points added                                      |
| `score_mult`       | multiply note score by `value` while active            |
| `appeal_up`        | +`value` fraction of appeal (0.1 = +10%)               |
| `crit_chance_up`   | +`value` crit chance (0.2 = +20 points)                |
| `crit_damage_up`   | +`value` on the crit multiplier (0.5: 1.5x -> 2.0x)    |
| `skill_chance_up`  | +`value` to every skill's activation chance            |
| `heal`             | +`value` HP (or `fraction = 0.1` for 10% of max)       |
| `perfect_lock`     | greats count as perfects                               |
| `perfect_lock_strong` | goods count as perfects too                         |
| `guaranteed_crit`  | the next `value` notes (in scope) all crit             |
| `combo_shield`     | the next `value` misses don't break combo              |
| `custom`           | `fn = function(live, card, slot) ... end`              |

For a `custom` effect, `live` is the live-time card state (see
`game/cards/live.lua`: `live:addModifier`, `live:addScore`, `live:heal`,
`live:getTeam()`), `card` is this card's table and `slot` its lane (1 = rightmost).
