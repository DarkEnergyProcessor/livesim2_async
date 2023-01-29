-- Base Live UI class
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- Live UI handles almost everything.
-- Combo counter, score display, stamina display, ...

local Luaoop = require("libs.Luaoop")
---@class Livesim2.LiveUI
local UIBase = Luaoop.class("Livesim2.LiveUI")

-- luacheck: no unused args

-----------------
-- Base system --
-----------------

function UIBase.__construct(autoplay, mineff)
	-- constructor must run in async manner!
	error("attempt to construct abstract class 'Livesim2.LiveUI'", 2)
end

function UIBase:update(dt, paused)
	error("pure virtual method 'update'", 2)
end

function UIBase:getNoteSpawnPosition()
	error("pure virtual method 'getNoteSpawnPosition'")
	return -- vector
end

function UIBase:getLanePosition()
	-- 1 is leftmost, 9 is rightmost
	error("pure virtual method 'getLanePosition'")
	return -- {vector, vector, ...}
end

function UIBase:getFailAnimation()
	-- object that has :update(ms) and :draw(x, y)
	error("pure virtual method 'getFailAnimation'")
	return --{:update, :draw}
end

--------------------
-- Scoring System --
--------------------

function UIBase:setScoreRange(cs, bs, as, ss)
	error("pure virtual method 'setScoreRange'", 2)
end

function UIBase:addScore(amount)
	error("pure virtual method 'addScore'", 2)
end

function UIBase:getScore()
	error("pure virtual method 'getScore'", 2)
	return 0
end

------------------
-- Combo System --
------------------

function UIBase:comboJudgement(judgement, addCombo)
	-- handle whetever to increment combo or break
	error("pure virtual method 'comboJudgement'", 2)
end

function UIBase:getCurrentCombo()
	error("pure virtual method 'getCurrentCombo'", 2)
	return 222
end

function UIBase:getMaxCombo()
	error("pure virtual method 'getMaxCombo'", 2)
	return 255
end

function UIBase:getScoreComboMultipler()
	error("pure virtual method 'getScoreComboMultipler'", 2)
	return 1.15
end

-------------
-- Stamina --
-------------

function UIBase:setMaxStamina(stamina)
	error("pure virtual method 'setMaxStamina'", 2)
end

function UIBase:getMaxStamina()
	error("pure virtual method 'getMaxStamina'", 2)
	return 45
end

function UIBase:getStamina()
	error("pure virtual method 'getStamina'", 2)
	return 32
end

function UIBase:addStamina(amount)
	-- amount can be positive or negative
	error("pure virtual method 'addStamina'", 2)
	return 32+5
end

------------------
-- Pause button --
------------------

function UIBase:enablePause()
	error("pure virtual method 'enablePause'", 2)
end

function UIBase:disablePause()
	error("pure virtual method 'disablePause'", 2)
end

function UIBase:isPauseEnabled()
	error("pure virtual method 'isPauseEnabled'", 2)
end

function UIBase:checkPause(x, y)
	error("pure virtual method 'checkPause'", 2)
	return true or false
end

------------------
-- Other things --
------------------

function UIBase:addTapEffect(x, y, r, g, b, a)
	error("pure virtual method 'addTapEffect'", 2)
end

function UIBase:setTextScaling(scale)
	error("pure virtual method 'setTextScaling'", 2)
end

function UIBase:getOpacity()
	error("pure virtual method 'getOpacity'", 2)
end

function UIBase:setOpacity(opacity)
	error("pure virtual method 'setOpacity'", 2)
end

function UIBase:setComboCheer(enable)
	error("pure virtual method 'setComboCheer'", 2)
end

function UIBase:setTotalNotes(total)
	error("pure virtual method 'setTotalNotes'", 2)
end

-- this will always be called multiple times, it's UI responsible to handle it
function UIBase:startLiveClearAnimation(fullcombo, donecb, opaque)
	error("pure virtual method 'startLiveClearAnimation'", 2)
end

function UIBase:setLiveClearVoice(voice)
	error("pure virtual method 'setLiveClearVoice'", 2)
end

-------------
-- Drawing --
-------------

function UIBase:drawHeader()
	error("pure virtual method 'drawHeader'", 2)
end

function UIBase:drawStatus()
	error("pure virtual method 'drawStatus'", 2)
end

return UIBase
