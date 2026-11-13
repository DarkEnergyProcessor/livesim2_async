-- Sleek UI kit: palette, Jost fonts, rounded panels, pill buttons and
-- circle-cropped card portraits. Shared by the restyled menus.
-- Part of the SIF gift fork

local love = require("love")
local Luaoop = require("libs.Luaoop")

local MainFont = require("main_font")
local Glow = require("game.afterglow")

local Sleek = {}

---------------------------------------------------------------- palette

local function hex(s, a)
	return {
		tonumber(s:sub(1, 2), 16) / 255,
		tonumber(s:sub(3, 4), 16) / 255,
		tonumber(s:sub(5, 6), 16) / 255,
		a or 1
	}
end
Sleek.hex = hex

-- Two themes. Every screen reads Sleek.color.* at draw time and the theme
-- switch rewrites these tables in place, so held references stay valid.
local themes = {
	light = {
		bg = "F3F4F8", panel = "FFFFFF", border = "E3E5EC", track = "EEF0F5",
		text = "23263A", muted = "5F6478", faint = "9AA0B2",
		accent = "E8508E", accentDark = "A8295E", accentSoft = "FBE6EF",
		blue = "4AA3DF", blueDark = "1F6AAE", blueSoft = "E6F0FA",
		green = "3DAA6E", gold = "D4A017", goldDark = "9A6E00", goldSoft = "FBF1D9",
		grey = "D5D8E1", gap = "FFFFFF", white = "FFFFFF",
		decorPink = "FBE6EF", decorBlue = "E6F0FA",
	},
	dark = {
		bg = "15161E", panel = "1F2130", border = "2E3143", track = "2B2E3F",
		text = "ECEDF3", muted = "A3A8BA", faint = "7C8296",
		accent = "EC5E98", accentDark = "F59BC0", accentSoft = "3A2232",
		blue = "5AB0E8", blueDark = "8CC4F0", blueSoft = "1D2B3D",
		green = "4DBB7E", gold = "E0B030", goldDark = "E8C25A", goldSoft = "352B16",
		grey = "3A3D50", gap = "1F2130", white = "FFFFFF",
		decorPink = "251A26", decorBlue = "18202E",
	},
}
local rarityThemes = {
	light = {
		R = {"A5ABBA", "EEF0F4", "4F5566"}, SR = {"4AA3DF", "E4F0FB", "1F6AAE"},
		SSR = {"9A7BEF", "EFEAFD", "5B3FC4"}, UR = {"D4A017", "FBF1D9", "8A6100"},
	},
	dark = {
		R = {"8E94A6", "2E3142", "C3C7D3"}, SR = {"4AA3DF", "1C3348", "8CC4F0"},
		SSR = {"9A7BEF", "2C2448", "B9A6F7"}, UR = {"D4A017", "3A2F14", "E8C25A"},
	},
}

Sleek.color = {}
Sleek.rarity = {}
for k, v in pairs(themes.light) do Sleek.color[k] = hex(v) end
for k, v in pairs(rarityThemes.light) do
	-- ring = circle outline around a card, chipBg/chipFg = the small rarity pill
	Sleek.rarity[k] = {ring = hex(v[1]), chipBg = hex(v[2]), chipFg = hex(v[3])}
end

local function copyInto(t, s)
	local c = hex(s)
	t[1], t[2], t[3], t[4] = c[1], c[2], c[3], c[4]
end

local currentTheme = "light"
function Sleek.applyTheme(name)
	if not themes[name] then name = "light" end
	currentTheme = name
	for k, v in pairs(themes[name]) do copyInto(Sleek.color[k], v) end
	for k, v in pairs(rarityThemes[name]) do
		copyInto(Sleek.rarity[k].ring, v[1])
		copyInto(Sleek.rarity[k].chipBg, v[2])
		copyInto(Sleek.rarity[k].chipFg, v[3])
	end
end

function Sleek.isDark()
	return currentTheme == "dark"
end

-- read the saved choice (setting SLEEK_DARK, per device)
function Sleek.loadTheme()
	local Setting = require("setting")
	local ok, v = pcall(Setting.get, "SLEEK_DARK")
	Sleek.applyTheme((ok and tonumber(v) == 1) and "dark" or "light")
end

function Sleek.toggleTheme()
	local Setting = require("setting")
	local dark = not Sleek.isDark()
	Setting.set("SLEEK_DARK", dark and 1 or 0)
	Sleek.applyTheme(dark and "dark" or "light")
end

function Sleek.rarityStyle(r)
	return Sleek.rarity[tostring(r or ""):upper()] or Sleek.rarity.R
end

---------------------------------------------------------------- fonts

local fontFiles = {
	light = "fonts/Jost-Light.ttf",
	regular = "fonts/Jost-Regular.ttf",
	medium = "fonts/Jost-Medium.ttf",
}
local fontData = {}
local fontCache = {}

-- Jost with Noto CJK / Sarabun fallbacks so Japanese song titles still render
function Sleek.font(size, weight)
	weight = weight or "regular"
	local key = weight..size
	local f = fontCache[key]
	if f then return f end

	if not fontData[weight] then
		fontData[weight] = love.filesystem.newFileData(fontFiles[weight] or fontFiles.regular)
	end
	local dpi = MainFont.dpiScale
	f = love.graphics.newFont(fontData[weight], size, "normal", dpi)
	f:setFallbacks(
		love.graphics.newFont(MainFont.notoSansCJK, size, "normal", dpi),
		love.graphics.newFont(MainFont.sarabun, size, "normal", dpi)
	)
	fontCache[key] = f
	return f
end

---------------------------------------------------------------- drawing

function Sleek.setColor(c, alphaMul)
	love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (alphaMul or 1))
end

-- full-screen light ground with two soft decorative circles
function Sleek.background(variant)
	Sleek.setColor(Sleek.color.bg)
	love.graphics.rectangle("fill", -88, -43, 1136, 726)
	if variant ~= "plain" then
		Sleek.setColor(Sleek.color.decorPink)
		love.graphics.circle("fill", 80, 640 + 0, 260, 96)
		Sleek.setColor(Sleek.color.decorBlue)
		love.graphics.circle("fill", 1030, -10, 210, 96)
	end
end

-- white rounded panel with a faint shadow and hairline border
function Sleek.panel(x, y, w, h, r, opts)
	r = r or 24
	opts = opts or {}
	local s = opts.shadow ~= false
	if s then
		local sa = Sleek.isDark() and 0.09 or 0.022
		for i = 1, 3 do
			love.graphics.setColor(0, 0, 0.08, sa)
			love.graphics.rectangle("fill", x - i, y + 2 + i * 2, w + i * 2, h + i, r + i, r + i, 32)
		end
	end
	Sleek.setColor(opts.fill or Sleek.color.panel)
	love.graphics.rectangle("fill", x, y, w, h, r, r, 32)
	if opts.border ~= false then
		Sleek.setColor(opts.borderColor or Sleek.color.border)
		love.graphics.setLineWidth(opts.borderWidth or 1)
		love.graphics.rectangle("line", x, y, w, h, r, r, 32)
		love.graphics.setLineWidth(1)
	end
end

-- small rounded label, e.g. a rarity chip. Returns its width.
function Sleek.chip(text, x, y, bg, fg, size)
	local font = Sleek.font(size or 12, "medium")
	local w = font:getWidth(text) + 18
	local h = font:getHeight() + 4
	Sleek.setColor(bg)
	love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2, 16)
	Sleek.setColor(fg)
	love.graphics.setFont(font)
	love.graphics.print(text, x + 9, y + 2)
	return w, h
end

function Sleek.chevron(x, y, dir, size, col)
	size = size or 8
	Sleek.setColor(col or Sleek.color.faint)
	love.graphics.setLineWidth(2)
	love.graphics.setLineJoin("miter")
	if dir == "left" then
		love.graphics.line(x + size * 0.5, y - size, x - size * 0.5, y, x + size * 0.5, y + size)
	else
		love.graphics.line(x - size * 0.5, y - size, x + size * 0.5, y, x - size * 0.5, y + size)
	end
	love.graphics.setLineWidth(1)
end

-- horizontal stat bar
function Sleek.bar(x, y, w, h, frac, col)
	Sleek.setColor(Sleek.color.track)
	love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2, 12)
	frac = math.max(math.min(frac or 0, 1), 0)
	if frac > 0 then
		Sleek.setColor(col)
		love.graphics.rectangle("fill", x, y, math.max(w * frac, h), h, h / 2, h / 2, 12)
	end
end

---------------------------------------------------------------- circle cards

local circleShader
local function getCircleShader()
	if circleShader == nil then
		-- mask computed in the image's own pixel space, so it is independent of
		-- screen size, DPI and whatever transform is active
		local ok, res = pcall(love.graphics.newShader, [[
			extern vec2 center;
			extern vec2 size;
			extern number radius;
			extern number aa;
			vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
			{
				number d = length(tc * size - center);
				number a = clamp((radius - d) / aa + 0.5, 0.0, 1.0);
				vec4 c = Texel(tex, tc) * color;
				return vec4(c.rgb, c.a * a);
			}
		]])
		circleShader = ok and res or false
	end
	return circleShader or nil
end

-- Draw `image` cropped into a circle of radius r centered on cx, cy.
-- crop (optional, from the card file): {x = 0..1, y = 0..1, zoom = >=1}
-- x/y is the point of the picture that should sit in the middle of the circle.
-- Default puts the upper-middle (where a face usually is) in the middle.
function Sleek.drawCircleImage(image, cx, cy, r, crop, alpha)
	crop = crop or {}
	local iw, ih = image:getDimensions()
	local zoom = math.max(tonumber(crop.zoom) or 1, 1)
	local scale = (2 * r) / math.min(iw, ih) * zoom
	local fx = tonumber(crop.x) or 0.5
	local fy = tonumber(crop.y) or (ih > iw * 1.05 and 0.3 or 0.5)
	if iw > ih * 1.05 and crop.y == nil then
		-- landscape art (SIFAS card art): faces sit a little above the middle
		fy = 0.4
	end

	-- top-left of the picture so the focus point lands on the center,
	-- clamped so the picture always fills the whole circle
	local dw, dh = iw * scale, ih * scale
	local x = cx - fx * dw
	local y = cy - fy * dh
	x = math.min(math.max(x, cx + r - dw), cx - r)
	y = math.min(math.max(y, cy + r - dh), cy - r)

	local shader = getCircleShader()
	love.graphics.setColor(1, 1, 1, alpha or 1)
	if shader then
		-- one screen pixel, measured in image pixels, for a soft edge
		local x0 = love.graphics.transformPoint(0, 0)
		local x1 = love.graphics.transformPoint(1, 0)
		local screenPerUnit = math.max(math.abs(x1 - x0) * love.graphics.getDPIScale(), 0.01)
		shader:send("center", {(cx - x) / scale, (cy - y) / scale})
		shader:send("size", {iw, ih})
		shader:send("radius", r / scale)
		shader:send("aa", 1 / (scale * screenPerUnit))
		local prev = love.graphics.getShader()
		love.graphics.setShader(shader)
		love.graphics.draw(image, x, y, 0, scale, scale)
		love.graphics.setShader(prev)
	else
		love.graphics.draw(image, x, y, 0, scale, scale)
	end
end

-- SIF unit icon frames (128px, ring from radius 56 to 63). UR cards use these,
-- colored by the card's attribute; other rarities get the sleek ring.
local sifFrames = {}
local frameIndex = {smile = 1, pure = 2, cool = 3, all = 4}
local function getSifFrame(rarity, attribute)
	local n = frameIndex[tostring(attribute or "all"):lower()] or 4
	local key = rarity..n
	if sifFrames[key] == nil then
		local ok, img = pcall(love.graphics.newImage, "assets/image/unit_icon/f_"..rarity.."_"..n..".png", {mipmaps = true})
		sifFrames[key] = ok and img or false
	end
	return sifFrames[key] or nil
end

-- Card portrait: white gap + rarity ring around a circle-cropped image.
-- opts: ringWidth, gap, selected (accent halo), alpha, fallback (image when card has none)
function Sleek.drawCard(card, image, cx, cy, r, opts)
	opts = opts or {}
	local ringW = opts.ringWidth or math.max(2, math.floor(r / 14 + 0.5))
	local gap = opts.gap or math.max(2, math.floor(r / 16 + 0.5))
	local alpha = opts.alpha or 1
	local style = Sleek.rarityStyle(card and card.rarity)

	if opts.selected then
		Sleek.setColor(opts.selectedColor or Sleek.color.accent, alpha)
		love.graphics.circle("fill", cx, cy, r + 7, 64)
		Sleek.setColor(opts.haloGap or Sleek.color.bg, alpha)
		love.graphics.circle("fill", cx, cy, r + 4, 64)
	end
	if opts.shadow ~= false then
		love.graphics.setColor(0, 0, 0, (Sleek.isDark() and 0.25 or 0.08) * alpha)
		love.graphics.circle("fill", cx, cy + 3, r + 1, 64)
	end

	local frame = card and tostring(card.rarity):upper() == "UR" and getSifFrame("UR", card.attribute)
	if frame then
		local s = r / 64
		local inner = 57 * s
		Sleek.setColor(opts.gapColor or Sleek.color.gap, alpha)
		love.graphics.circle("fill", cx, cy, inner + 1, 64)
		if image then
			Sleek.drawCircleImage(image, cx, cy, inner, card and card.crop, alpha)
		else
			Sleek.setColor(Sleek.color.grey, alpha)
			love.graphics.circle("fill", cx, cy, inner, 64)
		end
		love.graphics.setColor(1, 1, 1, alpha)
		love.graphics.draw(frame, cx, cy, 0, s, s, 64, 64)
		return
	end

	Sleek.setColor(style.ring, alpha)
	love.graphics.circle("fill", cx, cy, r, 64)
	Sleek.setColor(opts.gapColor or Sleek.color.gap, alpha)
	love.graphics.circle("fill", cx, cy, r - ringW, 64)

	local inner = r - ringW - gap
	if image then
		Sleek.drawCircleImage(image, cx, cy, inner, card and card.crop, alpha)
	else
		Sleek.setColor(Sleek.color.grey, alpha)
		love.graphics.circle("fill", cx, cy, inner, 64)
	end
end

---------------------------------------------------------------- buttons

-- Generic rounded button element. opts: w, h, radius, text, size, weight,
-- fill, textColor, border (bool), icon (function(x, y, w, h)), align ("center"|"left")
local Button = Luaoop.class("Livesim2.Sleek.Button", Glow.Element)

function Button:new(opts)
	self.opts = opts
	self.width, self.height = opts.w or 200, opts.h or 48
	self.isPressed = false
	self.font = Sleek.font(opts.size or 18, opts.weight or "medium")
	self:addEventListener("mousepressed", function() self.isPressed = true end)
	self:addEventListener("mousecanceled", function() self.isPressed = false end)
	self:addEventListener("mousereleased", function() self.isPressed = false end)
end

function Button:setText(t)
	self.opts.text = t
end

function Button:render(x, y)
	local o = self.opts
	local r = o.radius or self.height / 2
	local fill = o.fill or Sleek.color.panel
	if o.shadow then
		love.graphics.setColor(fill[1], fill[2], fill[3], 0.12)
		love.graphics.rectangle("fill", x + 8, y + 5, self.width - 16, self.height, r, r, 32)
	end
	Sleek.setColor(fill)
	love.graphics.rectangle("fill", x, y, self.width, self.height, r, r, 32)
	if o.border then
		Sleek.setColor(Sleek.color.border)
		love.graphics.rectangle("line", x, y, self.width, self.height, r, r, 32)
	end
	if o.icon then
		o.icon(x, y, self.width, self.height)
	end
	if o.text then
		Sleek.setColor(o.textColor or Sleek.color.text)
		love.graphics.setFont(self.font)
		local ty = y + (self.height - self.font:getHeight()) / 2
		if o.align == "left" then
			love.graphics.print(o.text, x + (o.padLeft or 20), ty)
		else
			love.graphics.printf(o.text, x + (o.textOffset or 0), ty, self.width, "center")
		end
	end
	if self.isPressed then
		love.graphics.setColor(0.137, 0.149, 0.227, 0.08)
		love.graphics.rectangle("fill", x, y, self.width, self.height, r, r, 32)
	end
end

Sleek.Button = Button

-- round back button (44px) with a left chevron
function Sleek.backButton()
	return Button({
		w = 44, h = 44, border = true,
		icon = function(x, y, w, h)
			Sleek.chevron(x + w / 2 - 1, y + h / 2, "left", 8, Sleek.color.text)
		end
	})
end

-- header used by every sleek screen: back button + title + optional subtitle
function Sleek.header(title, subtitle)
	love.graphics.setFont(Sleek.font(28, "medium"))
	Sleek.setColor(Sleek.color.text)
	love.graphics.print(title, 84, subtitle and 14 or 22)
	if subtitle then
		love.graphics.setFont(Sleek.font(14))
		Sleek.setColor(Sleek.color.muted)
		love.graphics.print(subtitle, 85, 50)
	end
end

-- Swap a Glow frame's chunky 30px scrollbars for thin rounded ones.
-- Call after frame:update(dt) (sliders are created lazily there).
local function slimRender(self, x, y)
	local pct = self.sliderMaxValue > 0 and (self.sliderValue / self.sliderMaxValue) or 0
	local len, handle = self.sliderLength, 64
	if self.sliderType == "vertical" then
		Sleek.setColor(Sleek.color.track)
		love.graphics.rectangle("fill", x + 13, y + 4, 4, len - 8, 2, 2)
		Sleek.setColor(Sleek.color.faint)
		love.graphics.rectangle("fill", x + 12, y + 4 + pct * (len - 8 - handle), 6, handle, 3, 3)
	else
		Sleek.setColor(Sleek.color.track)
		love.graphics.rectangle("fill", x + 4, y + 13, len - 8, 4, 2, 2)
		Sleek.setColor(Sleek.color.faint)
		love.graphics.rectangle("fill", x + 4 + pct * (len - 8 - handle), y + 12, handle, 6, 3, 3)
	end
end

function Sleek.slimScrollbars(frame)
	for _, k in ipairs({"sliderV", "sliderH"}) do
		local sl = frame[k]
		if sl and sl.element.render ~= slimRender then
			sl.element.render = slimRender
		end
	end
end

---------------------------------------------------------------- icons (line art)

function Sleek.iconPlay(cx, cy, s, col)
	Sleek.setColor(col)
	love.graphics.polygon("fill", cx - s * 0.32, cy - s * 0.5, cx - s * 0.32, cy + s * 0.5, cx + s * 0.52, cy)
end

function Sleek.iconPeople(cx, cy, s, col)
	Sleek.setColor(col)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", cx - s * 0.12, cy - s * 0.18, s * 0.16, 32)
	love.graphics.arc("line", "open", cx - s * 0.12, cy + s * 0.42, s * 0.3, math.pi * 1.05, math.pi * 1.95, 24)
	love.graphics.circle("line", cx + s * 0.25, cy - s * 0.1, s * 0.12, 32)
	love.graphics.arc("line", "open", cx + s * 0.25, cy + s * 0.36, s * 0.22, math.pi * 1.2, math.pi * 1.95, 24)
	love.graphics.setLineWidth(1)
end

function Sleek.iconGear(cx, cy, s, col)
	Sleek.setColor(col)
	love.graphics.setLineWidth(2)
	local pts = {}
	local teeth = 8
	for i = 0, teeth * 4 - 1 do
		local a = i / (teeth * 4) * math.pi * 2
		local rr = (i % 4 < 2) and s * 0.42 or s * 0.32
		pts[#pts + 1] = cx + math.cos(a) * rr
		pts[#pts + 1] = cy + math.sin(a) * rr
	end
	love.graphics.polygon("line", pts)
	love.graphics.circle("line", cx, cy, s * 0.13, 24)
	love.graphics.setLineWidth(1)
end

function Sleek.iconClock(cx, cy, s, col)
	Sleek.setColor(col)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", cx, cy + s * 0.04, s * 0.36, 40)
	love.graphics.line(cx, cy - s * 0.14, cx, cy + s * 0.06, cx + s * 0.13, cy + s * 0.18)
	love.graphics.line(cx - s * 0.12, cy - s * 0.44, cx + s * 0.12, cy - s * 0.44)
	love.graphics.setLineWidth(1)
end

function Sleek.iconNote(cx, cy, s, col)
	Sleek.setColor(col)
	love.graphics.setLineWidth(2)
	love.graphics.line(cx - s * 0.12, cy + s * 0.3, cx - s * 0.12, cy - s * 0.25, cx + s * 0.32, cy - s * 0.33, cx + s * 0.32, cy + s * 0.22)
	love.graphics.circle("fill", cx - s * 0.22, cy + s * 0.3, s * 0.12, 20)
	love.graphics.circle("fill", cx + s * 0.22, cy + s * 0.22, s * 0.12, 20)
	love.graphics.setLineWidth(1)
end

function Sleek.iconSearch(cx, cy, s, col)
	Sleek.setColor(col)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", cx - s * 0.08, cy - s * 0.08, s * 0.28, 32)
	love.graphics.line(cx + s * 0.13, cy + s * 0.13, cx + s * 0.38, cy + s * 0.38)
	love.graphics.setLineWidth(1)
end

function Sleek.iconRetry(cx, cy, s, col)
	Sleek.setColor(col)
	love.graphics.setLineWidth(2.2)
	love.graphics.arc("line", "open", cx, cy, s * 0.34, -math.pi * 0.75, math.pi * 1.1, 32)
	local ax, ay = cx + math.cos(-math.pi * 0.75) * s * 0.34, cy + math.sin(-math.pi * 0.75) * s * 0.34
	love.graphics.line(ax - s * 0.02, ay - s * 0.2, ax, ay, ax + s * 0.2, ay + s * 0.02)
	love.graphics.setLineWidth(1)
end

return Sleek
