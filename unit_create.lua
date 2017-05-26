-- Unit creation from custom image
-- Part of Live Simulator: 2

local UnitCreate = {}
local HSL

UnitCreate.Background = AquaShine.LoadImage("assets/image/background/liveback_5.png")
UnitCreate.MaskImage = AquaShine.LoadImage("assets/image/ui/unit_mask.png")
UnitCreate.Checkerboard = AquaShine.LoadImage("assets/image/ui/checkerboard.png")
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
	set_icon_01_gray = love.graphics.newImageData("assets/image/ui/set_icon_01.png")
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
local CustomHSV = {0, 127, 127}
local ToggleButton = {
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
		-- UR frame
	}
}
