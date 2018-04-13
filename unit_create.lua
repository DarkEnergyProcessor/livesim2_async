-- Unit creation from custom image
-- Part of Live Simulator: 2

local AquaShine = ...
local UnitCreate = {}
local love = love
local HSL

UnitCreate.Background = {AquaShine.LoadImage(
	"assets/image/background/liveback_5.png",
	"assets/image/background/b_liveback_005_01.png",
	"assets/image/background/b_liveback_005_02.png",
	"assets/image/background/b_liveback_005_03.png",
	"assets/image/background/b_liveback_005_04.png"
)}
UnitCreate.MaskImage = AquaShine.LoadImage("assets/image/ui/unit_mask.png")
UnitCreate.Checkerboard = AquaShine.GetCachedData("ui_checkerboard", love.graphics.newImage, "assets/image/ui/checkerboard.png")
UnitCreate.ShaderCode = love.graphics.newShader [[
extern Image mask;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec4 maskpos = Texel(mask, texture_coords);
	vec4 col = Texel(texture, texture_coords);
	
	return vec4(col.rgb, (maskpos.r + maskpos.g + maskpos.g) / 3.0);
}
]]
UnitCreate.ShaderCode:send("mask", UnitCreate.MaskImage)

-- UI related
local Font24px = AquaShine.LoadFont("MTLmr3m.ttf", 24)
local Font14px = AquaShine.LoadFont("MTLmr3m.ttf", 14)
local set_win_11 = AquaShine.LoadImage("assets/image/ui/set_win_11.png")
local s_button_03 = AquaShine.LoadImage("assets/image/ui/s_button_03.png")
local set_icon_01 = AquaShine.LoadImage("assets/image/ui/set_icon_01.png")

local set_icon_01_gray = AquaShine.CacheTable.set_icon_01_gray

if not(set_icon_01_gray) then
	set_icon_01_gray = love.image.newImageData("assets/image/ui/set_icon_01.png")
	set_icon_01_gray:mapPixel(function(x, y, r, g, b, a)
		local lum = math.floor(r * 0.2125 + g * 0.7154 + b * 0.0721)
		return lum, lum, lum, a
	end)
	
	set_icon_01_gray = love.graphics.newImage(set_icon_01_gray)
	AquaShine.CacheTable.set_icon_01_gray = set_icon_01_gray
end

local CardRarity = {
	-- [attribute] = {frame, bg unidz, bg idz}
	-- attribute 4 = custom
	UR = {
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_UR_1.png",
			"assets/image/cbf/star4foreURSmile.png",
			"assets/image/cbf/star4foreURSmile.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_UR_2.png",
			"assets/image/cbf/star4foreURPure.png",
			"assets/image/cbf/star4foreURPure.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_UR_3.png",
			"assets/image/cbf/star4foreURCool.png",
			"assets/image/cbf/star4foreURCool.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/cbf/star4circleUREmpty.png",
			"assets/image/cbf/star4foreURSmile_empty.png",
			"assets/image/cbf/star4foreURSmile_empty.png"
		)},
	},
	SSR = {
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_SSR_1.png",
			"assets/image/cbf/star4foreURSmile.png",
			"assets/image/cbf/star4foreURSmile.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_SSR_2.png",
			"assets/image/cbf/star4foreURPure.png",
			"assets/image/cbf/star4foreURPure.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_SSR_3.png",
			"assets/image/cbf/star4foreURCool.png",
			"assets/image/cbf/star4foreURCool.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/ssr_custom.png",
			"assets/image/cbf/star4foreURSmile_empty.png",
			"assets/image/cbf/star4foreURSmile_empty.png"
		)},
	},
	SR = {
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_SR_1.png",
			"assets/image/unit_icon/b_smile_SR_001.png",
			"assets/image/unit_icon/b_smile_SR_002.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_SR_2.png",
			"assets/image/unit_icon/b_pure_SR_001.png",
			"assets/image/unit_icon/b_pure_SR_002.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_SR_3.png",
			"assets/image/unit_icon/b_cool_SR_001.png",
			"assets/image/unit_icon/b_cool_SR_002.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/cbf/star4circleSR_Custom.png",
			"assets/image/unit_icon/sr_custom_bg01.png",
			"assets/image/unit_icon/sr_custom_bg02.png"
		)},
	},
	R = {
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_R_1.png",
			"assets/image/unit_icon/b_smile_R_001.png",
			"assets/image/unit_icon/b_smile_R_002.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_R_2.png",
			"assets/image/unit_icon/b_pure_R_001.png",
			"assets/image/unit_icon/b_pure_R_002.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_R_3.png",
			"assets/image/unit_icon/b_cool_R_001.png",
			"assets/image/unit_icon/b_cool_R_002.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/r_custom.png",
			"assets/image/unit_icon/r_custom_bg01.png",
			"assets/image/cbf/star4circleSR_Custom_fore.png"
		)},
	},
	N = {
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_N_1.png",
			"assets/image/unit_icon/b_smile_N_001.png",
			"assets/image/unit_icon/b_smile_N_002.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_n_2.png",
			"assets/image/unit_icon/b_pure_N_001.png",
			"assets/image/unit_icon/b_pure_N_002.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/f_n_3.png",
			"assets/image/unit_icon/b_cool_N_001.png",
			"assets/image/unit_icon/b_cool_N_002.png"
		)},
		{AquaShine.LoadImage(
			"assets/image/unit_icon/n_custom.png",
			"assets/image/unit_icon/n_custom_bg01.png",
			"assets/image/unit_icon/n_custom_bg01.png"
		)},
	}
}

local CurrentAttribute = 1
local CurrentRarity = "UR"
local CustomHSV = {0, 127, 127}
local ToggleButton
ToggleButton = {
	-- Attribute
	{
		-- Smile button. Default
		X = 92, Y = 317, W = 51, H = 51, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/com_button_51.png"),
		Image2 = AquaShine.LoadImage("assets/image/ui/com_button_51di.png"),
		
		Enabled = true,
		Disable = function(this)
			if this.Enabled then
				this.Enabled = false
				this.Image, this.Image2 = this.Image2, this.Image
			end
		end,
		Click = function(this)
			if not(this.Enabled) then
				this.Enabled = true
				this.Image, this.Image2 = this.Image2, this.Image
			end
			
			ToggleButton[2]:Disable()
			ToggleButton[3]:Disable()
			ToggleButton[4]:Disable()
			
			CurrentAttribute = 1
		end,
	},
	{
		-- Pure button.
		X = 143, Y = 317, W = 51, H = 51, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/com_button_52di.png"),
		Image2 = AquaShine.LoadImage("assets/image/ui/com_button_52.png"),
		
		Enabled = false,
		Disable = function(this)
			if this.Enabled then
				this.Enabled = false
				this.Image, this.Image2 = this.Image2, this.Image
			end
		end,
		Click = function(this)
			if not(this.Enabled) then
				this.Enabled = true
				this.Image, this.Image2 = this.Image2, this.Image
			end
			
			ToggleButton[1]:Disable()
			ToggleButton[3]:Disable()
			ToggleButton[4]:Disable()
			
			CurrentAttribute = 2
		end,
	},
	{
		-- Cool button.
		X = 194, Y = 317, W = 51, H = 51, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/com_button_53di.png"),
		Image2 = AquaShine.LoadImage("assets/image/ui/com_button_53.png"),
		
		Enabled = false,
		Disable = function(this)
			if this.Enabled then
				this.Enabled = false
				this.Image, this.Image2 = this.Image2, this.Image
			end
		end,
		Click = function(this)
			if not(this.Enabled) then
				this.Enabled = true
				this.Image, this.Image2 = this.Image2, this.Image
			end
			
			ToggleButton[1]:Disable()
			ToggleButton[2]:Disable()
			ToggleButton[4]:Disable()
			
			CurrentAttribute = 3
		end,
	},
	{
		-- Custom button.
		X = 245, Y = 317, W = 51, H = 51, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/custom_attribute.png"),
		
		Enabled = false,
		Disable = function(this)
			this.Enabled = false
		end,
		Click = function(this)
			this.Enabled = true
			
			ToggleButton[1]:Disable()
			ToggleButton[2]:Disable()
			ToggleButton[3]:Disable()
			
			CurrentAttribute = 4
		end,
		Draw = function(this)
			if this.Enabled then
				love.graphics.setColor(HSL(CustomHSV[1], CustomHSV[2], CustomHSV[3]))
			end
			
			love.graphics.draw(this.Image, this.X, this.Y, 0, this.Scale)
		end
	},
	
	-- Frame
	{
		-- Idolized/unidolized frame. Unidolized default
		X = 164, Y = 188, W = 51, H = 51, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/u_button_30.png"),
		Image2 = AquaShine.LoadImage("assets/image/ui/u_button_31.png"),
		Idolized = false,
		
		Click = function(this)
			this.Idolized = not(this.Idolized)
			this.Image, this.Image2 = this.Image2, this.Image
		end,
	},
	{
		-- UR frame. On by default
		X = 92, Y = 239, W = 48, H = 48, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/com_button_55.png"),
		Image2 = AquaShine.LoadImage("assets/image/ui/com_button_55di.png"),
		
		Enabled = true,
		Disable = function(this)
			if this.Enabled then
				this.Enabled = false
				this.Image, this.Image2 = this.Image2, this.Image
			end
		end,
		Click = function(this)
			if not(this.Enabled) then
				this.Enabled = true
				this.Image, this.Image2 = this.Image2, this.Image
			end
			
			ToggleButton[7]:Disable()
			ToggleButton[8]:Disable()
			ToggleButton[9]:Disable()
			ToggleButton[10]:Disable()
			
			CurrentRarity = "UR"
		end,
	},
	{
		-- SSR frame
		X = 140, Y = 239, W = 48, H = 48, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/com_button_56di.png"),
		Image2 = AquaShine.LoadImage("assets/image/ui/com_button_56.png"),
		
		Enabled = false,
		Disable = function(this)
			if this.Enabled then
				this.Enabled = false
				this.Image, this.Image2 = this.Image2, this.Image
			end
		end,
		Click = function(this)
			if not(this.Enabled) then
				this.Enabled = true
				this.Image, this.Image2 = this.Image2, this.Image
			end
			
			ToggleButton[6]:Disable()
			ToggleButton[8]:Disable()
			ToggleButton[9]:Disable()
			ToggleButton[10]:Disable()
			
			CurrentRarity = "SSR"
		end,
	},
	{
		-- SR frame
		X = 188, Y = 239, W = 48, H = 48, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/com_button_57di.png"),
		Image2 = AquaShine.LoadImage("assets/image/ui/com_button_57.png"),
		
		Enabled = false,
		Disable = function(this)
			if this.Enabled then
				this.Enabled = false
				this.Image, this.Image2 = this.Image2, this.Image
			end
		end,
		Click = function(this)
			if not(this.Enabled) then
				this.Enabled = true
				this.Image, this.Image2 = this.Image2, this.Image
			end
			
			ToggleButton[6]:Disable()
			ToggleButton[7]:Disable()
			ToggleButton[9]:Disable()
			ToggleButton[10]:Disable()
			
			CurrentRarity = "SR"
		end,
	},
	{
		-- R frame
		X = 236, Y = 239, W = 48, H = 48, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/com_button_58di.png"),
		Image2 = AquaShine.LoadImage("assets/image/ui/com_button_58.png"),
		
		Enabled = false,
		Disable = function(this)
			if this.Enabled then
				this.Enabled = false
				this.Image, this.Image2 = this.Image2, this.Image
			end
		end,
		Click = function(this)
			if not(this.Enabled) then
				this.Enabled = true
				this.Image, this.Image2 = this.Image2, this.Image
			end
			
			ToggleButton[6]:Disable()
			ToggleButton[7]:Disable()
			ToggleButton[8]:Disable()
			ToggleButton[10]:Disable()
			
			CurrentRarity = "R"
		end,
	},
	{
		-- N frame
		X = 284, Y = 239, W = 48, H = 48, Scale = 0.75,
		
		Image = AquaShine.LoadImage("assets/image/ui/com_button_59di.png"),
		Image2 = AquaShine.LoadImage("assets/image/ui/com_button_59.png"),
		
		Enabled = false,
		Disable = function(this)
			if this.Enabled then
				this.Enabled = false
				this.Image, this.Image2 = this.Image2, this.Image
			end
		end,
		Click = function(this)
			if not(this.Enabled) then
				this.Enabled = true
				this.Image, this.Image2 = this.Image2, this.Image
			end
			
			ToggleButton[6]:Disable()
			ToggleButton[7]:Disable()
			ToggleButton[8]:Disable()
			ToggleButton[9]:Disable()
			
			CurrentRarity = "N"
		end,
	}
}

-- Converts HSL to RGB. (input and output range: 0 - 255)
-- https://love2d.org/wiki/HSL_color
function HSL(h, s, l, a)
	if s<=0 then return l,l,l,a end
	h, s, l = h/256*6, s/255, l/255
	local c = (1-math.abs(2*l-1))*s
	local x = (1-math.abs(h%2-1))*c
	local m,r,g,b = (l-.5*c), 0,0,0
	if h < 1     then r,g,b = c,x,0
	elseif h < 2 then r,g,b = x,c,0
	elseif h < 3 then r,g,b = 0,c,x
	elseif h < 4 then r,g,b = 0,x,c
	elseif h < 5 then r,g,b = x,0,c
	else              r,g,b = c,0,x
	end return (r+m)*255,(g+m)*255,(b+m)*255,a
end

function UnitCreate.Start()
	UnitCreate.Checkerboard:setMipmapFilter()
	UnitCreate.Checkerboard:setFilter("nearest", "nearest", 0)
end

function UnitCreate.Update(deltaT) end

function UnitCreate.Draw()
	-- Draw something white at first
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(UnitCreate.Background[1])
	love.graphics.draw(UnitCreate.Background[2], -88, 0)
	love.graphics.draw(UnitCreate.Background[3], 960, 0)
	love.graphics.draw(UnitCreate.Background[4], 0, -43)
	love.graphics.draw(UnitCreate.Background[5], 0, 640)
	love.graphics.rectangle("fill", 408, 53, 514, 514)
	love.graphics.rectangle("fill", 79, 90, 282, 282)
	love.graphics.rectangle("fill", 4, 379, 394, 207)
	love.graphics.rectangle("fill", 36, 53, 362, 32)
	
	for i = 1, #ToggleButton do
		local btn = ToggleButton[i]
		
		if btn.Draw then
			btn:Draw()
			love.graphics.setColor(255, 255, 255)
		else
			love.graphics.draw(btn.Image, btn.X, btn.Y, 0, btn.Scale)
		end
	end
	
	-- Texts
	love.graphics.setFont(Font14px)
	love.graphics.draw(s_button_03, 706, 586, 0, 0.5)
	love.graphics.print("Save", 714, 594)
	
	if AquaShine.FileSelection then
		love.graphics.draw(s_button_03, 706, 6, 0, 0.5)
		love.graphics.print("Load Image", 714, 14)
	end
	
	-- Texts (2). Black color
	love.graphics.setFont(Font24px)
	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", 218, 101, 132, 132)
	love.graphics.print("Name:", 41, 57)
	love.graphics.print("Preview", 92, 103)
	love.graphics.print("Frame", 92, 209)
	love.graphics.print("Attribute", 92, 291)
	
	-- White color again
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(UnitCreate.Checkerboard, 220, 103)
end

function UnitCreate.MouseReleased(x, y, button, touch_id)
	if x >= 706 and x < 922 then
		if AquaShine.FileSelection and y >= 6 and y < 46 then
			AquaShine.FileSelection("Select Images to Load", nil, "*.png *.jpg *.jpeg")
		elseif y >= 586 and y < 626 then
			-- TODO
		end
	else
		for i = 1, #ToggleButton do
			local btn = ToggleButton[i]
			
			if x >= btn.X and y >= btn.Y and x < btn.X + btn.W and y < btn.Y + btn.H then
				btn:Click()
				break
			end
		end
	end
end

return UnitCreate, "Unit Creation"
