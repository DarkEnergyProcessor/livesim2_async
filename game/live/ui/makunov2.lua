-- Makuno Live UI v.2.0.1
-- Contributed by Makuno
-- part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")

local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")
local vector = require("libs.nvec")

local AssetCache = require("asset_cache")
local AudioManager = require("audio_manager")
local Setting = require("setting")

local color = require("color")
local Util = require("util")

local UIBase = require("game.live.uibase")

---@class Livesim2.MakunoV2LiveUI: Livesim2.LiveUI
local MakunoV2UI = Luaoop.class("livesim2.MakunoV2LiveUI", UIBase)

------------------------------------
-- Local
local itf_score = {
    txt = {
        "D","C","B","A","S", -- Regular Rank
        "SS","SSS","SPI","UPI" -- Super Rank
    },

    color = {
        {235, 233, 235}, -- D
        {  0, 255, 255}, -- C
        {255, 165,  75}, -- B
        {255, 125, 125}, -- A
        {225, 135, 255}, -- S
        ----------------------
        {255, 220,  85}, -- SS  (x2 of S)
        {145, 235, 255}, -- SSS (x3 of S)
        {255,  10, 215}, -- SPI (x6 of S)
        {255,  50,  50}, -- UPI (x9 of S)
    },
}

-- Local Config
local itf_conf = {

    --[[    dy_usesuperrank - Display | Use Super Rank
        Use Super Rank after passed Rank S

        0 - Don't use Super Rank
        1 - Use Super Rank
    ]]
    dy_usesuperrank = 1,

    --[[    dy_rankdisplay - Display | Rank Display Mode
        Determinate how to display rank bar

        0 - Display Regular rank only
        1 - All rank display at once.
    ]]
    dy_rankdisplay = 0,

    --[[    dy_uselite - Display | Use Lite Mode
        Reduce amount of text on screen.

        0 - Don't use Lite Mode.
        1 - Use Lite Mode (No PIGI-Ratio, EX-Score)
    ]]
    dy_uselite = 0,

    --[[    dy_accdisplay - Display | Accuracy Display Mode
        Determinate how accuracy should be displayed.

        0 - Display as Percentage (Start from 0%)
        1 - Display as Percentage (Start from 100%)
        2 - Display as 1 Million Points
    ]]
    dy_accdisplay = 0,

    --[[    sy_sif2rank - Display | SIF2 Rank
        Mimic the SIF2 Score Rank system.
        (Which have a fixed score regardless of difficulty)
        (   
            SIF2 Score Rank:
            C - 25,000
            B - 100,000
            A - 250,000
            S - 350,000
        )

        0 - Don't use SIF2 Rank
        1 - Use SIF2 Rank
    ]]
    sy_sif2rank = 0,

    --[[    sy_comboaffectmultiply - System | Combo Affect Multiplier
        Determinate how Combo should affect score multiplier.

        0 - Combo won't use for Score Multiplier.
        1 - Combo will use for Score Multiplier (SIF rule).
        2 - Combo will use for Score Multiplier (Linear 800 Combo rule).
    ]]
    sy_comboaffectmultiply = 1,
    
    --[[    sy_useoverflow = System | Use Overflow Stamina
        Determinate to use Overflow Stamina bonus, If healer
        continue to refill stamina over the max value.

        0 - Don't use Overflow stamina.
        1 - Use Overflow stamina.
        2 - Mimic SIF2/Bandori/D4DJ Stamina Overflow (No Bonus).
    ]]
    sy_useoverflow = 0,

}

local fonts = {
    light = "fonts/Jost-Light.ttf",
    regular = "fonts/Jost-Regular.ttf",
    italic = "fonts/Jost-Italic.ttf",
    medium = "fonts/Jost-Medium.ttf",
}

------------------------------------
------------------------------------

---@param r number | table (-∞, ∞) or table data of color
---@param g number (-∞, ∞)
---@param b number (-∞, ∞)
---@param a number (-∞, ∞)
local function setColor(r, g, b, a)
    local c1, c2, c3, ap

    if type(r) == "table" then
        c1 = Util.clamp(r[1], 0, 255)
        c2 = Util.clamp(r[2], 0, 255)
        c3 = Util.clamp(r[3], 0, 255)
        ap = Util.clamp(r[4] or g or 255, 0, a or 255)
    else
        c1 = Util.clamp(r, 0, 255)
        c2 = Util.clamp(g, 0, 255)
        c3 = Util.clamp(b, 0, 255)
        ap = Util.clamp(a, 0, 1)
    end

    love.graphics.setColor(color.compat(c1, c2, c3, ap))
end

---Convert HSL (Hue, Saturation, Lightness) value 
---to RGB (Red, Green, Blue) value
---https://en.wikipedia.org/wiki/HSL_and_HSV
---@param h number (0 - 360)
---@param s number (0 - 1)
---@param l number (0 - 1)
---@return table RGB {r, g, b}
local function HSLtoRGB(h, s, l)
    local c = (1 - math.abs(2 * l - 1)) * s
    local hp = h / 60
    local x = c * (1 - math.abs(hp % 2 - 1))
    local m = l - c / 2
    local r, g, b

    if hp < 1 then
        r, g, b = c, x, 0
    elseif hp < 2 then
        r, g, b = x, c, 0
    elseif hp < 3 then
        r, g, b = 0, c, x
    elseif hp < 4 then
        r, g, b = 0, x, c
    elseif hp < 5 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end

    return {(r + m) * 255, (g + m) * 255, (b + m) * 255}
end

---Retrieve theme from itf_score "color" data
---'i' value will be 1 if not specified
---@param i integer (nil - 9)
---@return table RGB {r, g, b}
local function retrieveColor(i)
    -- somehow 'return itf_score.color[i]' carries color data to next play
    -- so I have to change to be sperate.
    if i then
        return {itf_score.color[i][1], itf_score.color[i][2], itf_score.color[i][3]}
    else
        return {itf_score.color[1][1], itf_score.color[1][2], itf_score.color[1][3]}
    end
end

---Retrieve position data to be use for draw
---@param lineamount number (amount of the line)
---@param scoredata table (table value that contain score value)
---@param barsize number (size of the bar for draw)
---@param offset number (use in case if the bar origin is not top-left)
---@return table linedata (table value that contain x value)
local function setLineData(lineamount, scoredata, barsize, offset)
    local linedata = {}

    for i = 1, lineamount do
        linedata[#linedata+1] = (Util.clamp(scoredata[i] / scoredata[lineamount], 0, 1) * barsize) + offset
    end

    return linedata
end

---Spaced Out the letters
---@param text string
local function spacedtext(text)

    local t = tostring(text)

    return string.gsub(t, ".", " %0"):sub(2)
end

------------------------------------
------------------------------------

function MakunoV2UI:__construct(aupy, mife)

    -- 1
    self.timer = timer:new()
    self.fonts = AssetCache.loadMultipleFonts({
        {fonts.medium, 12},     -- Top/Sub title text & Stamina
        {fonts.light, 31},      -- Score & Acc number
        {fonts.regular, 14},    -- Sub info number
        {fonts.regular, 20},    -- Combo number
        --
        {fonts.light, 48},      -- LIVE CLEAR/FAIL Text
        {fonts.italic, 18},     -- Additional Live Text
    })
    self.image = AssetCache.loadMultipleImages(
        {
            "assets/image/dummy.png",
        },  {mipmaps = true}
    )

    self.fonts_h = {
        self.fonts[1]:getHeight(),
        self.fonts[2]:getHeight(),
        self.fonts[3]:getHeight(),
        self.fonts[4]:getHeight(),
        --
        self.fonts[5]:getHeight(),
        self.fonts[6]:getHeight(),
    }

    self.bool_pauseEnabled = true
    self.effect_taplist = {}

    self.bool_staminafunc = Setting.get("STAMINA_FUNCTIONAL") == 1
    self.bool_mineffec = mife
    self.bool_autoplay = aupy

    self.time_prelive = 5
    self.time_postlive = -math.huge
    self.data_livecallback = nil
    self.data_liveopaque = nil

    -- 2
    self.display_text_opacity = 1
    self.display_element_opacity = 1

    self.display_text = {
        top = {
            ACC = "ACCURACY",
            SCO = "SCORE",
            PGR = "PIGI RATIO",
            EXS = "EX-SCORE",
        },

        judge = {
			Perfect = "PERFECT",
			Great = "GREAT",
			Good = "GOOD",
			Bad = "BAD",
			Miss = "MISS",
		},
    }

    self.display_global = {
        ---- Main Info
        L_toptext_x = 7, L_toptext_y = 0,
        R_toptext_x = 953, R_toptext_y = 0,
        --
        L_topnum_x = 7, L_topnum_y = 53,
        R_topnum_x = 953, R_topnum_y = 53,

        ---- Sub Info
        L_subtext_x = 10, L_subtext_y = 56,
        R_subtext_x = 950, R_subtext_y = 56,
        --
        L_subnum_x = 222, L_subnum_y = 55,
        R_subnum_x = 738, R_subnum_y = 55,

        ---- Stamina Bar
        mb_line_y1 = 56, mb_line_y2 = 68,
        lb_x1 = 281, 
        lb_x2 = 293, 
        rb_x1 = 697, 
        rb_x2 = 709, 
        bonus_opa = 0,
        stami_opa = 1,

        ---- Line
        L_line_x = 5, R_line_x = 955,
        M_bar_y = 50, T_bar_y = 44, B_bar_y = 56,

    }

    self.display_result = {
        bgcover_dim = 0, bgcover_color = {0, 0, 0},

        text1 = "", text2 = "",

        text2_x = 480 + math.random(-240, 240), 

        text1_y = 340,
        text2_y = 340,

        text1_scale = 1.25,

        text1_opacity = 0, text1_color = {255, 255, 255},
        text2_opacity = 0, text2_color = {255, 255, 255},

        fakeresultbox_y = 1000,
    }

    self.timer_global = {
        dy_num = 0.35,
        dy_tae = 0.25,
    }

    self.tween_text_opacity = nil
    self.tween_element_opacity = nil

    self.tween_display_global = nil

    -- 3
    self.data_currentscore = 0
    self.data_currentEXscore = 0

    self.display_score = self.data_currentscore
    self.display_EXscore = self.data_currentEXscore

    self.data_scorerank = {1, 2, 3, 4, 5, 6, 7, 8, 9}
    self.display_scorecolor = retrieveColor()
    self.display_ranktext = itf_score.txt[1]

    self.tween_display_currentscore = nil
    self.tween_display_EXscore = nil
    self.tween_display_colorrank = nil

    -- 4
    self.data_currentcombo = 0
    self.data_misscombo = 0
    self.data_highestcombo = 0

    self.display_combo_opacity = 1

    self.tween_combo = nil
    self.tween_combo2 = nil

    -- 5
    self.count_perfect = 0
    self.count_great = 0
    self.count_good = 0
    self.count_bad = 0
    self.count_miss = 0

    self.data_PIGI_ratio = 0
    self.display_PIGIRatio = 0

    self.display_judgement_text = ""
    self.display_judgement_opacity = 1
    self.display_judgement_scale = 1.1

    self.tween_judgement1 = nil
    self.tween_judgement2 = nil

    self.tween_PIGI_ratio = nil

    -- 6
    self.data_currentaccuracy = 0

    self.display_accuracy = self.data_currentaccuracy

    self.data_totalnote = 0
    self.data_remainingnote = 0
    self.data_notepassed = 0
    self.data_notepress = 0

    self.tween_display_accuracy = nil

    -- 7
    self.data_maximumstamina = 9
    self.data_currentstamina = 9

    self.data_currentoverflow = 0
    self.data_overflowbonus = 0
    self.data_overflowmultiply = 0
    self.data_overflowmaximum = 10

    self.display_stamina = self.data_currentstamina
    self.display_overflowstamina = self.data_currentoverflow

    self.tween_display_stamina = nil
    self.tween_display_overflow = nil
    self.tween_display_overflowbonus = nil

    -- 8
    self.data_playresult = {
        PL = true, -- PERFECT
        FC = true, -- FULL COMBO
        NM = true, -- NO MISS (MISSLESS)
    }

    self.display_pause_opacity = 1
    self.bool_pauseplayed = false

    self.voice_livecleared = nil
    self.bool_voiceplayed = false

end

------------------------------------
------------------------------------

---- Get Data
-- For other script
function MakunoV2UI:getNoteSpawnPosition()
    return vector(480, 160)
end

function MakunoV2UI:getLanePosition()
    -- Their origin is top-left
    return {--  X ,  Y
        vector(880, 160), -- 1
        vector(849, 313),
        vector(762, 442),
        vector(633, 529),
        vector(480, 560), -- 5
        vector(326, 529),
        vector(197, 442),
        vector(110, 313),
        vector(80,  160), -- 9
    }
end

function MakunoV2UI:getFailAnimation()
    local TL = {

        text1_ele = love.graphics.newText(self.fonts[5]),

        text1 = spacedtext("LIVE FAILED"),

        text1_color = {255, 255, 255},
        text1_size = 1.1,
        text1_opacity = 0,

        t = timer:new(),
    }

    TL.text1_ele:addf(TL.text1, 960, "center", 0, 0, 0, 1, 1, 480, self.fonts_h[5])

    function TL.update(_, dt)
        TL.t:update(dt)
    end

    function TL:draw(_, x, y)

        setColor(TL.text1_color, TL.text1_opacity)
        love.graphics.draw(TL.text1_ele, 480, 340, 0, TL.text1_size, TL.text1_size)

    end

    TL.t:tween(500, TL, {text1_opacity = 1, text1_size = 1}, "out-cubic")
    TL.t:tween(3000, TL, {text1_color = {255, 69, 0}}, "in-out-sine")

    TL.t:after(2750, function()
        TL.t:tween(250, TL, {text1_opacity = 0}, "in-quart")
    end)

    return TL
end

function MakunoV2UI:getScore()
    return self.data_currentscore
end

function MakunoV2UI:getCurrentCombo()
    return self.data_currentcombo
end

function MakunoV2UI:getMaxCombo()
    return self.data_highestcombo
end

function MakunoV2UI:getScoreComboMultipler()
    if itf_conf.sy_comboaffectmultiply == 1 then
        if self.data_currentcombo < 50 then
			return 1
		elseif self.data_currentcombo < 100 then
			return 1.1
		elseif self.data_currentcombo < 200 then
			return 1.15
		elseif self.data_currentcombo < 400 then
			return 1.2
		elseif self.data_currentcombo < 600 then
			return 1.25
		elseif self.data_currentcombo < 800 then
			return 1.3
		else
			return 1.35
		end
    elseif itf_conf.sy_comboaffectmultiply == 2 then
        return 1 + ((Util.clamp(self.data_currentcombo, 0, 800) / 800) * 0.35) 
    else
        return 1
    end
end

function MakunoV2UI:getOpacity()
    return self.display_element_opacity
end

function MakunoV2UI:getMaxStamina()
    return self.data_maximumstamina
end

function MakunoV2UI:getStamina()
    return self.data_currentstamina
end

------------------------------------
------------------------------------

---- Set Data

function MakunoV2UI:setScoreRange(c, b, a, s)
    if itf_conf.sy_sif2rank == 1 then
        self.data_scorerank = {
            25000, 
            100000, 
            250000, 
            350000, 
            735000, 
            1180000, 
            2400000, 
            3535000  
        }
    else
        self.data_scorerank = {
            c, 
            b, 
            a, 
            s, 
            (s*2)+(c*1.4), 
            (s*3)+(b*1.3), 
            (s*6)+(a*1.2), 
            (s*9)+(s*1.1)
        }
    end
end

function MakunoV2UI:setMaxStamina(value)
    self.data_maximumstamina = math.min(value, 99)
    self.data_currentstamina = self.data_maximumstamina
    self.display_stamina = self.data_currentstamina
end

function MakunoV2UI:setTextScaling(scale)
    
end

function MakunoV2UI:setOpacity(opacity)
   self.display_text_opacity = opacity
   self.display_element_opacity = opacity 
end

function MakunoV2UI:setComboCheer()
    
end

function MakunoV2UI:setTotalNotes(value)
    self.data_totalnote = value
    self.data_remainingnote = value
end

function MakunoV2UI:setLiveClearVoice(voice)
    self.voice_livecleared = voice
end

------------------------------------
------------------------------------

function MakunoV2UI:update(dt, paused)
    
    if not(paused) then
        self.timer:update(dt)
    end

    for i = (#itf_score.txt - 1), 1, -1 do
        if self.display_score >= self.data_scorerank[i] then
            if (itf_conf.dy_usesuperrank == 0) and i > 4 then i = 4 end

            if self.tween_display_colorrank then self.timer:cancel(self.tween_display_colorrank) end
            self.tween_display_colorrank = self.timer:tween(1, self.display_scorecolor, retrieveColor(1 + i), "out-expo")

            self.display_ranktext = itf_score.txt[1 + i]
            break
        end
    end

    if self.time_prelive > 0 and self.time_postlive == -math.huge then
        self.time_prelive = self.time_prelive - dt
    end

    if self.time_postlive ~= -math.huge then
        if self.time_postlive > 0 then
            self.time_postlive = self.time_postlive - dt
        end

        if self.voice_livecleared and not(self.bool_voiceplayed) then
            AudioManager.play(self.voice_livecleared)
            self.bool_voiceplayed = true
        end

        if self.time_postlive <= 0 and self.data_livecallback then
            self.data_livecallback(self.data_liveopaque)
            self.data_livecallback = nil 
            self.data_liveopaque = nil
        end
    end
end

function MakunoV2UI:startLiveClearAnimation(FC, callback, opaque)

    if self.time_postlive == -math.huge and self.time_prelive > 0 and self.data_totalnote == 0 then
        self.time_postlive = 0.05
        self.data_livecallback = callback
        self.data_liveopaque = opaque

        self.display_text_opacity = 0
        self.display_element_opacity = 0
    end

    if self.time_postlive == -math.huge then
        self.time_postlive = 5
        self.data_livecallback = callback
        self.data_liveopaque = opaque

        self.display_result.text1 = spacedtext("LIVE CLEAR")
        local text2_pickedcolor = {255, 255, 255}

        if FC and self.data_playresult.PL then
            self.display_result.text2 = spacedtext("PERFECT PERFORMANCE")
            text2_pickedcolor = {255, 195, 77}
        elseif FC and self.data_playresult.FC then
            self.display_result.text2 = spacedtext("GREAT FULL COMBO")
            text2_pickedcolor = {77, 220, 255}
        elseif not(FC) and self.data_playresult.NM then
            self.display_result.text2 = spacedtext("NO MISS")
            text2_pickedcolor = {236, 153, 255}
        end

        self.timer:tween(
            0.5, self.display_result,
            {
                bgcover_dim = 0.3,
            
                text1_scale = 1,
                text1_opacity = 1,
            }, "out-cubic"
        )

        self.timer:after(1, function() 
            self.timer:tween(
                0.55, self.display_result,
                {
                    text2_x = 480,
                    text2_opacity = 1,
                    text2_color = text2_pickedcolor,
                }, "out-quart"
            )
        end)

        self.timer:after(2.5, function()
            self.timer:tween(
                1, self.display_global,
                {
                    L_toptext_y = 80, R_toptext_y = 80,
                    L_topnum_y = 133, R_topnum_y = 133,

                    L_subtext_y = 11, R_subtext_y = 11,
                    L_subnum_y = 10, R_subnum_y = 10,

                    lb_x1 = 281, lb_x2 = 293,
                    rb_x1 = 667, rb_x2 = 679,
                },
                "in-quint"
            )
        end)

        self.timer:after(2.8, function() 
            self.timer:tween(
                0.5, self.display_global,
                {
                    bonus_opa = 0, stami_opa = 0,
                },
                "out-quint"
            )
        end)

        self.timer:after(3.5, function()
            self.timer:tween(
                0.5, self, {display_text_opacity = 0}, "out-quint"
            )
        end)

        self.timer:after(3.5, function()
            self.timer:tween(
                0.5, self.display_global,
                {
                    L_line_x = 225, R_line_x = 735,
                },
                "out-quint"
            )
        end)

        self.timer:after(4, function()
            self.timer:tween(
                0.95, self.display_global,
                {
                    M_bar_y = 50 - (100 * 9), T_bar_y = 44 - (100 * 9), B_bar_y = 56 - (100 * 9),
                    mb_line_y1 = 56 - (100 * 9), mb_line_y2 = 68 - (100 * 9),
                },
                "in-quart"
            )

            self.timer:tween(
                0.5, self.display_result, 
                {
                    text1_opacity = 0,
                    text2_opacity = 0,

                    text1_y = 160,
                    text2_y = 560,
                },
                "in-quart"
            )
        end)

        self.timer:after(4.5, function()
            self.timer:tween(0.5, self.display_result, {
                bgcover_dim = 0.667,
                bgcover_color = {100, 98, 98},
                fakeresultbox_y = 231,
            }, "out-quart")
        end)
    end
end

------------------------------------
------------------------------------

function MakunoV2UI:addScore(amount)
    
    local a = math.ceil(amount + (amount * self.data_overflowmultiply))

    if a == 0 then return end

    self.data_currentscore = self.data_currentscore + a
    --
    if self.tween_display_currentscore then
        self.timer:cancel(self.tween_display_currentscore)
        self.tween_display_currentscore = nil
    end

    self.tween_display_currentscore = self.timer:tween(self.timer_global.dy_num, self, {display_score = self.data_currentscore}, "out-quint")
end

function MakunoV2UI:comboJudgement(judgement, addcombo)
    local breakcombo = false
    local hold_bonus = (addcombo and 2) or 1

    if judgement == "perfect" then
        self.data_currentEXscore = self.data_currentEXscore + (2 * hold_bonus)
        self.display_judgement_text = self.display_text.judge.Perfect
    elseif judgement == "great" then
        self.data_currentEXscore = self.data_currentEXscore + (1 * hold_bonus)
        self.display_judgement_text = self.display_text.judge.Great
    elseif judgement == "good" then
        breakcombo = true
        self.data_currentEXscore = self.data_currentEXscore - (4 * hold_bonus)
        self.display_judgement_text = self.display_text.judge.Good
    elseif judgement == "bad" then
        breakcombo = true
        self.data_currentEXscore = self.data_currentEXscore - (1 * hold_bonus)
        self.display_judgement_text = self.display_text.judge.Bad
    elseif judgement == "miss" then
        breakcombo = true
        self.data_currentEXscore = self.data_currentEXscore - (2 * hold_bonus)
        self.display_judgement_text = self.display_text.judge.Miss
    end

    if breakcombo then
        
        self.data_remainingnote = self.data_remainingnote - 1
        self.data_notepassed = self.data_notepassed + 1
        self.data_currentcombo = 0

        self.data_playresult.FC = false
        self.data_playresult.PL = false

        if judgement == "good" then
            self.data_misscombo = 0
            self.data_currentaccuracy = self.data_currentaccuracy + 0.5
            self.count_good = self.count_good + 1
        elseif judgement == "bad" then
            self.data_misscombo = 0
            self.data_currentaccuracy = self.data_currentaccuracy + 0.25
            self.count_bad = self.count_bad + 1
        elseif judgement == "miss" then
            self.data_playresult.NM = false
            self.data_misscombo = self.data_misscombo + 1
            self.count_miss = self.count_miss + 1
        end

    elseif addcombo then

        self.data_remainingnote = self.data_remainingnote - 1
        self.data_notepassed = self.data_notepassed + 1
        self.data_notepress = self.data_notepress + 1
        self.data_currentcombo = self.data_currentcombo + 1
        self.data_misscombo = 0

        self.data_highestcombo = math.max(self.data_highestcombo, self.data_currentcombo)

        if judgement == "perfect" then
            self.data_currentaccuracy = self.data_currentaccuracy + 1
            self.count_perfect = self.count_perfect + 1
        elseif judgement == "great" then
            self.data_playresult.PL = false
            self.data_currentaccuracy = self.data_currentaccuracy + 0.75
            self.count_great = self.count_great + 1
        end
    end

    if judgement and addcombo then

        if self.tween_combo then
            self.timer:cancel(self.tween_combo)
            self.tween_combo = nil
            self.display_combo_opacity = 1
        end

        if self.display_combo_opacity > 0 then
            self.tween_combo = self.timer:tween(2, self, {display_combo_opacity = 0}, "in-expo")
        end
    end

    if judgement and not(addcombo) then

        if self.tween_combo then
            self.timer:cancel(self.tween_combo)
            self.tween_combo = nil
        end

        self.display_combo_opacity = 1
    end

    if self.tween_judgement1 and self.tween_judgement2 then
        self.timer:cancel(self.tween_judgement1)
        self.tween_judgement1 = nil
        self.display_judgement_opacity = 1

        self.timer:cancel(self.tween_judgement2)
        self.tween_judgement2 = nil
        self.display_judgement_scale = 1.1
    end

    self.tween_judgement1 = self.timer:tween(1, self, {display_judgement_opacity = 0}, "in-expo")
    self.tween_judgement2 = self.timer:tween(0.5, self, {display_judgement_scale = 0.95}, "in-bounce")

    if self.data_notepress > 0 then
        if self.tween_display_accuracy then
            self.timer:cancel(self.tween_display_accuracy)
            self.tween_display_accuracy = nil
        end

        self.data_PIGI_ratio = self.count_perfect / (self.count_great + self.count_good + self.count_bad + self.count_miss)

        if not(self.data_PIGI_ratio ~= self.data_PIGI_ratio or self.data_PIGI_ratio == (1/0) or self.data_PIGI_ratio == (-1/0)) then

            if self.tween_PIGI_ratio then
                self.timer:cancel(self.tween_PIGI_ratio)
                self.tween_PIGI_ratio = nil
            end

            self.tween_PIGI_ratio = self.timer:tween(self.timer_global.dy_num, self, {display_PIGIRatio = self.data_PIGI_ratio}, "out-quint")
        end

        if itf_conf.dy_accdisplay == 1 then
            self.tween_display_accuracy = self.timer:tween(self.timer_global.dy_num, self, {display_accuracy = (self.data_currentaccuracy/self.data_notepassed) * 100}, "out-quint")
        else
            self.tween_display_accuracy = self.timer:tween(self.timer_global.dy_num, self, {display_accuracy = (self.data_currentaccuracy/self.data_totalnote) * 100}, "out-quint")
        end
    end

    if self.tween_display_EXscore then
        self.timer:cancel(self.tween_display_EXscore)
        self.tween_display_EXscore = nil
    end

    self.tween_display_EXscore = self.timer:tween(self.timer_global.dy_num, self, {display_EXscore = self.data_currentEXscore}, "out-quint")

end

function MakunoV2UI:addStamina(value)
    
    local a = math.ceil(value)

    if (self.bool_staminafunc == false) or (a == 0) then return end

    if itf_conf.sy_useoverflow ~= 0 then
        if (self.data_currentstamina + a) > self.data_maximumstamina then
            -- Stamina Overflow refills
            local remainstamina = self.data_maximumstamina - self.data_currentstamina
            local remainforover = a - remainstamina

            if (self.data_currentoverflow + remainforover) >= self.data_maximumstamina and itf_conf.sy_useoverflow == 1 then
                -- Applies bonus (not) similar to SIF1 does
                local remaincurover = self.data_maximumstamina - self.data_currentoverflow
                local restover = remainforover - remaincurover
                
                self.data_currentoverflow = 0
                self.data_currentoverflow = Util.clamp(self.data_currentoverflow + restover, 0, self.data_maximumstamina)

                if self.data_overflowbonus >= self.data_overflowmaximum then
                    self.data_currentoverflow = self.data_maximumstamina
                    self.data_overflowbonus = self.data_overflowmaximum
                else
                    self.data_overflowbonus = self.data_overflowbonus + 1
                end

                self.data_overflowmultiply = (self.data_overflowbonus * 0.005) + ((self.data_maximumstamina + 10) / 500)

                if self.tween_display_overflowbonus then
                    self.timer:cancel(self.tween_display_overflowbonus)
                    self.tween_display_overflowbonus = nil
                end

                self.tween_display_overflowbonus = self.timer:tween(
                    self.timer_global.dy_num, self.display_global, {
                        lb_x1 = 251, lb_x2 = 263,
                        bonus_opa = 1,
                    }, "out-quart"
                )

            else
                -- Just Single Overflow with no bonus (Mimic SIF2 and other games)
                self.data_currentoverflow = Util.clamp(self.data_currentoverflow + remainforover, 0, self.data_maximumstamina)
            end
        else
            -- Stamina drain
            if itf_conf.sy_useoverflow == 1 then
                -- SIF1: Lost Overflow immediately upon Stamina Lost
                self.data_currentoverflow = 0
                self.data_currentstamina = Util.clamp(self.data_currentstamina + a, 0, self.data_maximumstamina)
            else
                -- SIF2: Basically Second Stamina
                if (self.data_currentoverflow + a) < 0 and self.data_currentoverflow > 0 then
                    local ripover = math.abs(a + self.data_currentoverflow)
                    
                    self.data_currentoverflow = 0
                    self.data_currentstamina = Util.clamp(self.data_currentstamina + ripover, 0, self.data_maximumstamina)
                elseif self.data_currentoverflow > 0 then
                    self.data_currentoverflow = Util.clamp(self.data_currentoverflow + a, 0, self.data_maximumstamina)
                else
                    self.data_currentstamina = Util.clamp(self.data_currentstamina + a, 0, self.data_maximumstamina)
                end
            end
        end

        if self.tween_display_overflow then
            self.timer:cancel(self.tween_display_overflow)
            self.tween_display_overflow = nil
        end

        self.tween_display_overflow = self.timer:tween(
            self.timer_global.dy_num, self, {
                display_overflowstamina = self.data_currentoverflow
            }, "out-quart"
        )

    else
        self.data_currentstamina = Util.clamp(self.data_currentstamina + a, 0, self.data_maximumstamina)
    end

    if self.tween_display_stamina then
        self.timer:cancel(self.tween_display_stamina)
        self.tween_display_stamina = nil
    end

    self.tween_display_stamina = self.timer:tween(
        self.timer_global.dy_num, self, {
            display_stamina = self.data_currentstamina
        }, "out-quart"
    )

end

function MakunoV2UI:addTapEffect(x, y, r, g, b, a)
    if not(self.bool_mineffec) then
        local ntap_e
        for ti = 1, #self.effect_taplist do
            local cti = self.effect_taplist[ti]
            if cti.done then
                ntap_e = table.remove(self.effect_taplist, ti)
                break
            end
        end

        if not(ntap_e) then
            ntap_e = {
                x = 0, y = 0, x_r = 0, y_r = 0,
                r = 255, g = 255, b = 255,
                o = 1, s = 1,
                done = false,
            }

            ntap_e.func = function()
                ntap_e.done = true
            end
        end

        ntap_e.x, ntap_e.y = x, y
        ntap_e.r, ntap_e.g, ntap_e.b = r, g, b
        ntap_e.o, ntap_e.s = 1, 1
        ntap_e.done = false

        self.timer:tween(self.timer_global.dy_tae, ntap_e, {
            s = 2, o = 0
        }, "out-quart", ntap_e.func)

        self.effect_taplist[#self.effect_taplist + 1] = ntap_e
    end
end

------------------------------------
------------------------------------

function MakunoV2UI:enablePause()
    self.bool_pauseEnabled = true
end

function MakunoV2UI:disablePause()
    self.bool_pauseEnabled = false
end

function MakunoV2UI:isPauseEnabled()
    return self.bool_pauseEnabled
end

function MakunoV2UI:checkPause(x, y)
    return self:isPauseEnabled() and x >= 155 and y >= 0 and x <= 800 and y <= 50
end

------------------------------------
------------------------------------

-- draw below note
function MakunoV2UI:drawHeader()

    if not(self.bool_mineffec) then
        for e = #self.effect_taplist, 1, -1 do
            local etli = self.effect_taplist[e]
            if etli.done then break end
            
            setColor(etli.r, etli.g, etli.b, etli.o)
            love.graphics.draw(self.image[1], etli.x, etli.y, 0, etli.s, etli.s, 64, 64)
        end
    end

end

-- draw above note
function MakunoV2UI:drawStatus()
    
    local dcs = {
        t_score = tostring(self.display_text.top.SCO.." - RANK "..self.display_ranktext),
        t_accscore = tostring(self.display_text.top.ACC.." "..self.display_text.top.SCO),
        t_acc = tostring(self.display_text.top.ACC),
        t_pigi = tostring(self.display_text.top.PGR),
        t_exsc = tostring(self.display_text.top.EXS),
        t_judge = spacedtext(self.display_judgement_text),

        t_pause = nil,

        n_score = string.format("%.0f", self.display_score):reverse():gsub("(%d%d%d)","%1,"):gsub(",(%-?)$", "%1"):reverse(),
        n_acc = string.format("%.2f", self.display_accuracy).."%",
        n_accscore = string.format("%.0f", self.display_accuracy*10000):reverse():gsub("(%d%d%d)","%1,"):gsub(",(%-?)$", "%1"):reverse(),
        n_pigi = nil,
        n_exsc = string.format("%.0f", self.display_EXscore),
        n_combo = tostring(self.data_currentcombo),

        b_score = nil,
        l_score = nil,

        g_bscor = Util.gradient("vertical", color.hex00000022, color.transparent),
        g_apaus = nil,
    }

    do
        if self.data_PIGI_ratio ~= self.data_PIGI_ratio then -- NaN
            dcs.n_pigi = "NaN:1"
        elseif self.data_PIGI_ratio == (1/0) or self.data_PIGI_ratio == (-1/0) then -- Infinity
            dcs.n_pigi = "∞:1"
        else
            dcs.n_pigi = string.format("%.2f", self.display_PIGIRatio)..":1"
        end
    end

    -- Four Triangle used to cut edge of score bar
    local stencil1 = function()
        love.graphics.polygon("fill", 225, self.display_global.M_bar_y, 225, self.display_global.T_bar_y, 231, self.display_global.T_bar_y)
        love.graphics.polygon("fill", 729, self.display_global.T_bar_y, 735, self.display_global.T_bar_y, 735, self.display_global.M_bar_y)
        love.graphics.polygon("fill", 225, self.display_global.M_bar_y, 225, self.display_global.B_bar_y, 231, self.display_global.B_bar_y)
        love.graphics.polygon("fill", 729, self.display_global.B_bar_y, 735, self.display_global.B_bar_y, 735, self.display_global.M_bar_y)
    end

    -- Rectangle Area for ACCURACY/SCORE Info
    local stencil2 = function()
        love.graphics.rectangle("fill", 5, 0, 220, 50)
        love.graphics.rectangle("fill", 735, 0, 220, 50)
        love.graphics.rectangle("fill", 225, 0, 510, 44) 
    end

    -- Rectangle Area for PIGI RATIO/EX-SCORE Info 
    local stencil3 = function()
        love.graphics.rectangle("fill", 5, 52, 220, 30)
        love.graphics.rectangle("fill", 735, 52, 220, 30)
    end

    -- Two Triangle for edge cut at stamina bar
    local stencil4 = function()
        love.graphics.polygon("fill", 281, self.display_global.mb_line_y1, 281, self.display_global.mb_line_y2, 293, self.display_global.mb_line_y2)
        love.graphics.polygon("fill", 679, self.display_global.mb_line_y1, 679, self.display_global.mb_line_y2, 667, self.display_global.mb_line_y2)
    end

    if itf_conf.dy_rankdisplay == 1 then
        dcs.b_score = Util.clamp(self.display_score/self.data_scorerank[8], 0, 1) * 506
        dcs.l_score = setLineData(8, self.data_scorerank, 506, 228)
    else
        dcs.b_score = Util.clamp(self.display_score/self.data_scorerank[4], 0, 1) * 506
        dcs.l_score = setLineData(4, self.data_scorerank, 506, 228)
    end
    
    ----------------------------------------
    --- Pause
    if self.time_prelive <= 0 and not(self.bool_pauseplayed) or self.time_postlive ~= -math.huge then
        self.bool_pauseplayed = true
        self.timer:tween(1, self, {display_pause_opacity = 0}, "out-quart")
    end

    if Util.isMobile() then
        dcs.t_pause = "Tap inside this area to pause"
    else
        dcs.t_pause = "Click inside this area to pause"
    end

    if self.bool_pauseEnabled then
        setColor(150, 210, 255, self.display_element_opacity * self.display_pause_opacity)
        dcs.g_apaus = Util.gradient("vertical",  color.transparent, color.hex99d5ffa0)
        love.graphics.draw(dcs.g_apaus, 231, 0, 0, 498, 44)
        love.graphics.printf(dcs.t_pause, self.fonts[3], 0, 2, 960, "center", 0)
    end

    ----------------------------------------
    --- Combo & Judgement
    if self.data_currentcombo > 0 then
        setColor(55, 55, 55, self.display_text_opacity * self.display_combo_opacity * 0.2)
        love.graphics.printf(dcs.n_combo, self.fonts[4], 480, 402, 240, "center", 0, 1, 1, 120, self.fonts_h[4]/2)
        setColor(255, 255, 255, self.display_text_opacity * self.display_combo_opacity * 0.9)
        love.graphics.printf(dcs.n_combo, self.fonts[4], 480, 400, 240, "center", 0, 1, 1, 120, self.fonts_h[4]/2)
    end

    if self.display_judgement_text and dcs.t_judge and self.display_judgement_opacity > 0 then
        setColor(55, 55, 55, self.display_text_opacity * self.display_judgement_opacity * 0.2)
        love.graphics.printf(dcs.t_judge, self.fonts[4], 480, 432, 240, "center", 0, self.display_judgement_scale, self.display_judgement_scale, 120, self.fonts_h[4]/2)
        setColor(255, 255, 255, self.display_text_opacity * self.display_judgement_opacity * 0.9)
        love.graphics.printf(dcs.t_judge, self.fonts[4], 480, 430, 240, "center", 0, self.display_judgement_scale, self.display_judgement_scale, 120, self.fonts_h[4]/2)
    end

    ----------------------------------------
    --- Score Bar
    love.graphics.stencil(stencil1, "increment", 1)
    love.graphics.setStencilTest("equal", 0)

    setColor(75, 75, 75, self.display_element_opacity * 0.1)
    love.graphics.rectangle("fill", 227, self.display_global.T_bar_y, 506, 12)

    if dcs.b_score > 0 then
        setColor(self.display_scorecolor, self.display_element_opacity * 0.9)
        love.graphics.rectangle("fill", 227, self.display_global.T_bar_y, dcs.b_score, 12)
    end

    setColor(255, 255, 255, self.display_element_opacity)
    love.graphics.draw(dcs.g_bscor, 227, self.display_global.T_bar_y, 0, 506, 11)

    love.graphics.setLineWidth(2.75)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")

    setColor(255, 255, 255, self.display_element_opacity * 0.5)
    if not(dcs.l_score == nil) then
        for i, v in pairs(dcs.l_score) do
            if (i < #dcs.l_score) then
                love.graphics.line(v, self.display_global.T_bar_y, v, self.display_global.B_bar_y)
            end
        end
    end

    love.graphics.setStencilTest()

    ----------------------------------------
    --- Bar/Line Shadow
    setColor(65, 65, 65, self.display_element_opacity * 0.2)

    love.graphics.line(225, self.display_global.M_bar_y + 2, self.display_global.L_line_x, self.display_global.M_bar_y + 2)
    love.graphics.line(735, self.display_global.M_bar_y + 2, self.display_global.R_line_x, self.display_global.M_bar_y + 2)

    love.graphics.line(225, self.display_global.M_bar_y + 2, 231, self.display_global.B_bar_y + 2, 729, self.display_global.B_bar_y + 2, 735, self.display_global.M_bar_y + 2)

    ----------------------------------------
    --- Stamina
    if self.bool_staminafunc then

        local dch_s = {
            b_stam = Util.clamp(self.display_stamina / self.data_maximumstamina, 0, 1) * 395,
            c_stam = Util.clamp(self.display_stamina / self.data_maximumstamina, 0, 1) * 120,
            b_over = Util.clamp(self.display_overflowstamina / self.data_maximumstamina, 0, 1) * 395,
            c_over = 120 + (Util.clamp(self.display_overflowstamina / self.data_maximumstamina, 0, 1) * 140),
            c_text = Util.clamp((self.display_stamina + self.display_overflowstamina) / (self.data_maximumstamina * 2), 0, 1) * 260,

            g_bsta = Util.gradient("vertical", color.transparent, color.hex00000022),

            n_stam = string.format("%.0f", self.display_stamina + self.display_overflowstamina),
            n_ovbon = tostring("x"..self.data_overflowbonus),
        }

        love.graphics.stencil(stencil4, "increment", 1)
        love.graphics.setStencilTest("equal", 0)
        
        setColor(75, 75, 75, self.display_element_opacity * 0.1)
        love.graphics.rectangle("fill", 284, self.display_global.mb_line_y1, 395, 12)
        setColor(HSLtoRGB(dch_s.c_stam, 0.85, 0.75), self.display_element_opacity * 0.9)
        love.graphics.rectangle("fill", 284, self.display_global.mb_line_y1, dch_s.b_stam, 12)

        setColor(HSLtoRGB(dch_s.c_over, 0.85, 0.8), self.display_element_opacity * 0.8)
        love.graphics.rectangle("fill", 284, self.display_global.mb_line_y1, dch_s.b_over, 12)
        
        setColor(255, 255, 255, self.display_element_opacity)
        love.graphics.draw(dch_s.g_bsta, 284, self.display_global.mb_line_y1, 0, 395, 11)

        love.graphics.setStencilTest()
        
        setColor(65, 65, 65, self.display_element_opacity * 0.2)
        love.graphics.line(self.display_global.lb_x1, self.display_global.mb_line_y1 + 2, self.display_global.lb_x2, self.display_global.mb_line_y2 + 2, self.display_global.rb_x1, self.display_global.mb_line_y2 + 2, self.display_global.rb_x2, self.display_global.mb_line_y1 + 2)

        setColor(255, 255, 255, self.display_element_opacity)

        love.graphics.polygon("fill", self.display_global.lb_x1, self.display_global.mb_line_y1, 281, self.display_global.mb_line_y1, 293, self.display_global.mb_line_y2, self.display_global.lb_x2, self.display_global.mb_line_y2)
        love.graphics.polygon("fill", 679, self.display_global.mb_line_y1, self.display_global.rb_x2, self.display_global.mb_line_y1, self.display_global.rb_x1, self.display_global.mb_line_y2, 667, self.display_global.mb_line_y2)

        love.graphics.line(self.display_global.lb_x1, self.display_global.mb_line_y1, self.display_global.lb_x2, self.display_global.mb_line_y2, 293, self.display_global.mb_line_y2)
        love.graphics.line(667, self.display_global.mb_line_y2, self.display_global.rb_x1, self.display_global.mb_line_y2, self.display_global.rb_x2, self.display_global.mb_line_y1)
        love.graphics.line(281, self.display_global.mb_line_y1, 293, self.display_global.mb_line_y2, 667, self.display_global.mb_line_y2, 679, self.display_global.mb_line_y1)
        
        setColor(25, 25, 25, self.display_element_opacity * self.display_global.stami_opa * 0.3)
        love.graphics.printf(dch_s.n_stam, self.fonts[1], 688, self.display_global.mb_line_y1 + 7, 75, "center", 0, 1, 1, 37.5, self.fonts_h[1] / 2)
        setColor(HSLtoRGB(dch_s.c_text, 0.85, 0.42), self.display_text_opacity * self.display_global.stami_opa * 0.9)
        love.graphics.printf(dch_s.n_stam, self.fonts[1], 688, self.display_global.mb_line_y1 + 6, 75, "center", 0, 1, 1, 37.5, self.fonts_h[1] / 2)

        if self.data_overflowbonus > 0 then
            setColor(25, 25, 25, self.display_element_opacity * self.display_global.bonus_opa * 0.3)
            love.graphics.printf(dch_s.n_ovbon, self.fonts[1], 274, self.display_global.mb_line_y1 + 7, 75, "center", 0, 1, 1, 37.5, self.fonts_h[1] / 2)
            setColor(HSLtoRGB(dch_s.c_text, 0.85, 0.42), self.display_text_opacity * self.display_global.bonus_opa * 0.9)
            love.graphics.printf(dch_s.n_ovbon, self.fonts[1], 274, self.display_global.mb_line_y1 + 6, 75, "center", 0, 1, 1, 37.5, self.fonts_h[1] / 2)
        end
    end

    ----------------------------------------
    --- Bar/Line
    setColor(255, 255, 255, self.display_element_opacity)

    love.graphics.line(225, self.display_global.M_bar_y, self.display_global.L_line_x, self.display_global.M_bar_y)
    love.graphics.line(735, self.display_global.M_bar_y, self.display_global.R_line_x, self.display_global.M_bar_y)

    love.graphics.line(225, self.display_global.M_bar_y, 231, self.display_global.T_bar_y, 729, self.display_global.T_bar_y, 735, self.display_global.M_bar_y)
    love.graphics.line(225, self.display_global.M_bar_y, 231, self.display_global.B_bar_y, 729, self.display_global.B_bar_y, 735, self.display_global.M_bar_y)
    
    ----------------------------------------
    --- Accuracy
    love.graphics.stencil(stencil2, "increment", 1)
    love.graphics.setStencilTest("gequal", 1)

    if itf_conf.dy_accdisplay == 2 then
        setColor(self.display_scorecolor, self.display_text_opacity * 0.3)
        love.graphics.printf(dcs.n_accscore, self.fonts[2], self.display_global.L_topnum_x - 1.2, self.display_global.L_topnum_y + 1.2, 360, "left", 0, 1, 1, 0, self.fonts_h[2])

        setColor(25, 25, 25, self.display_text_opacity * 0.3)
        love.graphics.printf(dcs.t_accscore, self.fonts[1], self.display_global.L_toptext_x  - 1.1, self.display_global.L_toptext_y + 1.1, 360, "left", 0, 1, 1, 0, 0)

        setColor(255, 255, 255, self.display_text_opacity * 0.9)
        love.graphics.printf(dcs.n_accscore, self.fonts[2], self.display_global.L_topnum_x, self.display_global.L_topnum_y, 360, "left", 0, 1, 1, 0, self.fonts_h[2])
        love.graphics.printf(dcs.t_accscore, self.fonts[1], self.display_global.L_toptext_x, self.display_global.L_toptext_y, 360, "left", 0, 1, 1, 0, 0)
    else
        setColor(self.display_scorecolor, self.display_text_opacity * 0.3)
        love.graphics.printf(dcs.n_acc, self.fonts[2], self.display_global.L_topnum_x - 1.2, self.display_global.L_topnum_y + 1.2, 360, "left", 0, 1, 1, 0, self.fonts_h[2])

        setColor(25, 25, 25, self.display_text_opacity * 0.3)
        love.graphics.printf(dcs.t_acc, self.fonts[1], self.display_global.L_toptext_x  - 1.1, self.display_global.L_toptext_y + 1.1, 360, "left", 0, 1, 1, 0, 0)

        setColor(255, 255, 255, self.display_text_opacity * 0.9)
        love.graphics.printf(dcs.n_acc, self.fonts[2], self.display_global.L_topnum_x, self.display_global.L_topnum_y, 360, "left", 0, 1, 1, 0, self.fonts_h[2])
        love.graphics.printf(dcs.t_acc, self.fonts[1], self.display_global.L_toptext_x, self.display_global.L_toptext_y, 360, "left", 0, 1, 1, 0, 0)
    end

    ----------------------------------------
    --- Score
    setColor(self.display_scorecolor, self.display_text_opacity * 0.3)
    love.graphics.printf(dcs.n_score, self.fonts[2], self.display_global.R_topnum_x + 1.2, self.display_global.R_topnum_y + 1.2, 480, "right", 0, 1, 1, 480, self.fonts_h[2])

    setColor(25, 25, 25, self.display_text_opacity * 0.3)
    love.graphics.printf(dcs.t_score, self.fonts[1], self.display_global.R_toptext_x + 1.1, self.display_global.R_toptext_y + 1.1, 360, "right", 0, 1, 1, 360, 0)

    setColor(255, 255, 255, self.display_text_opacity * 0.9)
    love.graphics.printf(dcs.t_score, self.fonts[1], self.display_global.R_toptext_x, self.display_global.R_toptext_y, 360, "right", 0, 1, 1, 360, 0)
    love.graphics.printf(dcs.n_score, self.fonts[2], self.display_global.R_topnum_x, self.display_global.R_topnum_y, 480, "right", 0, 1, 1, 480, self.fonts_h[2])

    love.graphics.setStencilTest()

    ----------------------------------------
    --- PIGI & EX-Score
    love.graphics.stencil(stencil3, "increment", 1)
    love.graphics.setStencilTest("gequal", 1)

    if itf_conf.dy_uselite == 0 then

        setColor(25, 25, 25, self.display_text_opacity * 0.3)
        love.graphics.printf(dcs.n_exsc, self.fonts[3], self.display_global.R_subnum_x + 1.1, self.display_global.R_subnum_y + 1.1, 240, "left", 0, 1, 1, 0, 0)
        love.graphics.printf(dcs.n_pigi, self.fonts[3], self.display_global.L_subnum_x - 1.1, self.display_global.L_subnum_y + 1.1, 240, "right", 0, 1, 1, 240, 0)

        setColor(255, 255, 255, self.display_text_opacity * 0.9)
        love.graphics.printf(dcs.n_exsc, self.fonts[3], self.display_global.R_subnum_x, self.display_global.R_subnum_y, 240, "left", 0, 1, 1, 0, 0)
        love.graphics.printf(dcs.n_pigi, self.fonts[3], self.display_global.L_subnum_x, self.display_global.L_subnum_y, 240, "right", 0, 1, 1, 240, 0)

        setColor(25, 25, 25, self.display_text_opacity * 0.3)
        love.graphics.printf(dcs.t_exsc, self.fonts[1], self.display_global.R_subtext_x + 1.1, self.display_global.R_subtext_y + 1.1, 180, "right", 0, 1, 1, 180, 0)
        love.graphics.printf(dcs.t_pigi, self.fonts[1], self.display_global.L_subtext_x - 1.1, self.display_global.L_subtext_y + 1.1, 180, "left", 0, 1, 1, 0, 0)

        setColor(255, 255, 255, self.display_text_opacity * 0.9)
        love.graphics.printf(dcs.t_exsc, self.fonts[1], self.display_global.R_subtext_x, self.display_global.R_subtext_y, 180, "right", 0, 1, 1, 180, 0)
        love.graphics.printf(dcs.t_pigi, self.fonts[1], self.display_global.L_subtext_x, self.display_global.L_subtext_y, 180, "left", 0, 1, 1, 0, 0)
        
    end

    love.graphics.setStencilTest()

    ----------------------------------------
    --- Result Screen
    if self.time_postlive ~= math.huge then
        
        setColor(self.display_result.bgcover_color, self.display_result.bgcover_dim)
        love.graphics.rectangle("fill", -88, -43, 1136, 726)

        setColor(255, 255, 255, 1)
		love.graphics.rectangle("fill", -88, self.display_result.fakeresultbox_y, 1136, 452)

        setColor(self.display_result.text1_color, self.display_result.text1_opacity)
        love.graphics.printf(self.display_result.text1, self.fonts[5], 480, self.display_result.text1_y, 480, "center", 0, self.display_result.text1_scale, self.display_result.text1_scale, 240, self.fonts_h[5])

        setColor(self.display_result.text2_color, self.display_result.text2_opacity)
        love.graphics.printf(self.display_result.text2, self.fonts[6], self.display_result.text2_x, self.display_result.text2_y, 480, "center", 0, 1, 1, 240, 0)

    end
end

return MakunoV2UI