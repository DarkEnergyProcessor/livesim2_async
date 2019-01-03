-- Color macro management
-- Donated to public domain

-- Some forms:
-- * <color name>
-- * hexRRGGBB(AA)
-- * <color name><percent_transparency>PT (can't be done for hex)

-- Hex color cache
local colorCache = {}

-- LOVE color division util
local div = 1
local haslove, love = pcall(require, "love")
local loveV11 = haslove and love._version >= "11.0"
if loveV11 then
	div = 1/255
end

local function hexCache(hexcode)
	local v = colorCache[hexcode]
	if not(v) then
		v = {
			tonumber(hexcode:sub(1, 2), 16) * div,
			tonumber(hexcode:sub(3, 4), 16) * div,
			tonumber(hexcode:sub(5, 6), 16) * div,
			tonumber(hexcode:sub(7, 8), 16) * div
		}
		colorCache[hexcode] = v
	end

	return v
end

local color = setmetatable({}, {
	__index = function(color, var)
		if var:find("hex", 1, true) == 1 then
			local hexcode = var:sub(4):lower()
			-- If the code is 3 chars then it's in form "RGB". Add "f"
			if #hexcode == 3 then
				hexcode = hexcode.."f"
			end
			-- If the code is 4 chars then it's in form "RGBA". Make it "RRGGBBAA"
			if #hexcode == 4 then
				hexcode = hexcode:gsub(".", "%1%1")
			end
			-- If the code is 6 chars, then it's in form "RRGGBB". Add "ff"
			if #hexcode == 6 then
				hexcode = hexcode.."ff"
			end

			if #hexcode == 8 then
				local v = hexCache(hexcode)
				rawset(color, var, v)
				return v
			end
		end

		-- <colorname><transparency_percent>PT variant
		if var:find("%d+P[T|A]") then
			local s, _, alpha = var:find("(%d+)P[T|A]")
			local name = var:sub(1, s-1)
			local colval = color[name] -- recursive __index

			if colval then
				local cmodv = hexCache(string.format("%02x%02x%02x%02x",
					colval[1] / div, colval[2] / div, colval[3] / div,
					math.floor(255 * alpha / 100)
				))
				rawset(color, var, cmodv)
				return cmodv
			else
				return nil
			end
		end

		-- Normal
		return rawget(color, var) or rawget(color, var:lower())
	end
})

-- Uncached. Return 4 values instead of table
function color.get(r, g, b, a, premultiplied)
	a = math.min(math.max(a or 1 + 0.0005, 0), 1)
	local v = hexCache(string.format("%02x%02x%02xff", r, g, b))
	if premultiplied then
		return
			math.floor(v[1] * a),
			math.floor(v[2] * a),
			math.floor(v[3] * a),
			math.floor(255 * a) * div
	else
		return v[1], v[2], v[3], math.floor(255 * a) * div
	end
end

-- Like color.get, but does color range conversion
-- based on LOVE version
if loveV11 then
	function color.compat(r, g, b, a, premul)
		a = math.min(math.max(a or 1 + 0.0005, 0), 1)
		if premul then
			return r * a / 255, g * a / 255, b * a / 255, a
		else
			return r / 255, g / 255, b / 255, a
		end
	end
else
	function color.compat(r, g, b, a, premul)
		a = math.min(math.max(a or 1 + 0.0005, 0), 1)
		if premul then
			return r * a, g * a, b * a, a * 255
		else
			return r, g, b, a * 255
		end
	end
end

-- Pre-defined colors from HTML (undefined order)
color.tan = color.hexD2B48C
color.steelBlue = color.hex4682B4
color.ghostWhite = color.hexF8F8FF
color.sandyBrown = color.hexF4A460
color.rebeccaPurple = color.hex663399
color.mistyRose = color.hexFFE4E1
color.antiqueWhite = color.hexFAEBD7
color.bisque = color.hexFFE4C4
color.fireBrick = color.hexB22222
color.gainsboro = color.hexDCDCDC
color.cornflowerBlue = color.hex6495ED
color.lightYellow = color.hexFFFFE0
color.orange = color.hexFFA500
color.lightPink = color.hexFFB6C1
color.gold = color.hexFFD700
color.darkOliveGreen = color.hex556B2F
color.aliceBlue = color.hexF0F8FF
color.lightSeaGreen = color.hex20B2AA
color.blueViolet = color.hex8A2BE2
color.gray = color.hex808080
color.darkKhaki = color.hexBDB76B
color.green = color.hex008000
color.powderBlue = color.hexB0E0E6
color.dodgerBlue = color.hex1E90FF
color.lightCyan = color.hexE0FFFF
color.midnightBlue = color.hex191970
color.snow = color.hexFFFAFA
color.navy = color.hex000080
color.darkSlateGray = color.hex2F4F4F
color.moccasin = color.hexFFE4B5
color.crimson = color.hexDC143C
color.deepPink = color.hexFF1493
color.lightBlue = color.hexADD8E6
color.darkOrange = color.hexFF8C00
color.darkTurquoise = color.hex00CED1
color.darkBlue = color.hex00008B
color.grey = color.hex808080
color.indigo = color.hex4B0082
color.lightGray = color.hexD3D3D3
color.honeyDew = color.hexF0FFF0
color.lightSalmon = color.hexFFA07A
color.indianRed = color.hexCD5C5C
color.thistle = color.hexD8BFD8
color.darkRed = color.hex8B0000
color.paleGoldenRod = color.hexEEE8AA
color.deepSkyBlue = color.hex00BFFF
color.darkSeaGreen = color.hex8FBC8F
color.blue = color.hex0000FF
color.lavender = color.hexE6E6FA
color.lightGreen = color.hex90EE90
color.red = color.hexFF0000
color.goldenRod = color.hexDAA520
color.yellow = color.hexFFFF00
color.slateBlue = color.hex6A5ACD
color.mediumAquaMarine = color.hex66CDAA
color.lightGrey = color.hexD3D3D3
color.cyan = color.hex00FFFF
color.darkGoldenRod = color.hexB8860B
color.darkGray = color.hexA9A9A9
color.violet = color.hexEE82EE
color.white = color.hexFFFFFF
color.wheat = color.hexF5DEB3
color.maroon = color.hex800000
color.forestGreen = color.hex228B22
color.limeGreen = color.hex32CD32
color.mediumBlue = color.hex0000CD
color.mediumSpringGreen = color.hex00FA9A
color.blanchedAlmond = color.hexFFEBCD
color.peru = color.hexCD853F
color.mediumTurquoise = color.hex48D1CC
color.darkCyan = color.hex008B8B
color.lightCoral = color.hexF08080
color.darkOrchid = color.hex9932CC
color.turquoise = color.hex40E0D0
color.darkSlateBlue = color.hex483D8B
color.paleVioletRed = color.hexDB7093
color.sienna = color.hexA0522D
color.burlyWood = color.hexDEB887
color.mediumPurple = color.hex9370DB
color.silver = color.hexC0C0C0
color.yellowGreen = color.hex9ACD32
color.royalBlue = color.hex4169E1
color.whiteSmoke = color.hexF5F5F5
color.tomato = color.hexFF6347
color.chartreuse = color.hex7FFF00
color.teal = color.hex008080
color.springGreen = color.hex00FF7F
color.navajoWhite = color.hexFFDEAD
color.orangeRed = color.hexFF4500
color.slateGray = color.hex708090
color.mediumVioletRed = color.hexC71585
color.skyBlue = color.hex87CEEB
color.chocolate = color.hexD2691E
color.khaki = color.hexF0E68C
color.pink = color.hexFFC0CB
color.greenYellow = color.hexADFF2F
color.ivory = color.hexFFFFF0
color.rosyBrown = color.hexBC8F8F
color.fuchsia = color.hexFF00FF
color.darkGrey = color.hexA9A9A9
color.darkSalmon = color.hexE9967A
color.azure = color.hexF0FFFF
color.paleTurquoise = color.hexAFEEEE
color.dimGrey = color.hex696969
color.olive = color.hex808000
color.hotPink = color.hexFF69B4
color.darkViolet = color.hex9400D3
color.brown = color.hexA52A2A
color.plum = color.hexDDA0DD
color.oldLace = color.hexFDF5E6
color.lemonChiffon = color.hexFFFACD
color.slateGrey = color.hex708090
color.lightSteelBlue = color.hexB0C4DE
color.mintCream = color.hexF5FFFA
color.lightSlateGrey = color.hex778899
color.coral = color.hexFF7F50
color.darkMagenta = color.hex8B008B
color.seaGreen = color.hex2E8B57
color.cadetBlue = color.hex5F9EA0
color.salmon = color.hexFA8072
color.lavenderBlush = color.hexFFF0F5
color.dimGray = color.hex696969
color.beige = color.hexF5F5DC
color.cornsilk = color.hexFFF8DC
color.darkSlateGrey = color.hex2F4F4F
color.lightGoldenRodYellow = color.hexFAFAD2
color.paleGreen = color.hex98FB98
color.seaShell = color.hexFFF5EE
color.aqua = color.hex00FFFF
color.lightSlateGray = color.hex778899
color.black = color.hex000000
color.mediumSlateBlue = color.hex7B68EE
color.magenta = color.hexFF00FF
color.oliveDrab = color.hex6B8E23
color.mediumSeaGreen = color.hex3CB371
color.mediumOrchid = color.hexBA55D3
color.linen = color.hexFAF0E6
color.aquamarine = color.hex7FFFD4
color.peachPuff = color.hexFFDAB9
color.lime = color.hex00FF00
color.lawnGreen = color.hex7CFC00
color.lightSkyBlue = color.hex87CEFA
color.darkGreen = color.hex006400
color.floralWhite = color.hexFFFAF0
color.papayaWhip = color.hexFFEFD5
color.purple = color.hex800080
color.orchid = color.hexDA70D6
color.saddleBrown = color.hex8B4513
color.transparent = color.hex00000000

return color
