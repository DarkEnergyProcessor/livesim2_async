-- Base Live UI class
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- Live UI handles almost everything.
-- Combo counter, score display, stamina display, ...

local Luaoop = require("libs.Luaoop")
local uibase = Luaoop.class("Livesim2.LiveUI")

-- luacheck: no unused args

-----------------
-- Base system --
-----------------

function uibase.__construct(autoplay, mineff)
	-- constructor must run in async manner!
	error("attempt to construct abstract class 'Livesim2.LiveUI'", 2)
end

function uibase:update(dt, paused)
	error("pure virtual method 'update'", 2)
end

function uibase:getNoteSpawnPosition()
	error("pure virtual method 'getNoteSpawnPosition'")
	return -- vector
end

function uibase:getLanePosition()
	-- 1 is leftmost, 9 is rightmost
	error("pure virtual method 'getLanePosition'")
	return -- {vector, vector, ...}
end

--------------------
-- Scoring System --
--------------------

function uibase:setScoreRange(cs, bs, as, ss)
	error("pure virtual method 'setScoreRange'", 2)
end

function uibase:addScore(amount)
	error("pure virtual method 'addScore'", 2)
end

function uibase:getScore()
	error("pure virtual method 'getScore'", 2)
	return 0
end

------------------
-- Combo System --
------------------

function uibase:comboJudgement(judgement, addCombo)
	-- handle whetever to increment combo or break
	error("pure virtual method 'comboJudgement'", 2)
end

function uibase:getCurrentCombo()
	error("pure virtual method 'getCurrentCombo'", 2)
	return 222
end

function uibase:getMaxCombo()
	error("pure virtual method 'getMaxCombo'", 2)
	return 255
end

function uibase:getScoreComboMultipler()
	error("pure virtual method 'getScoreComboMultipler'", 2)
	return 1.15
end

-------------
-- Stamina --
-------------

function uibase:setMaxStamina(stamina)
	error("pure virtual method 'setMaxStamina'", 2)
end

function uibase:getMaxStamina()
	error("pure virtual method 'getMaxStamina'", 2)
	return 45
end

function uibase:getStamina()
	error("pure virtual method 'getStamina'", 2)
	return 32
end

function uibase:addStamina(amount)
	-- amount can be positive or negative
	error("pure virtual method 'addStamina'", 2)
	return 32+5
end

------------------
-- Pause button --
------------------

function uibase:enablePause()
	error("pure virtual method 'enablePause'", 2)
end

function uibase:disablePause()
	error("pure virtual method 'disablePause'", 2)
end

function uibase:isPauseEnabled()
	error("pure virtual method 'isPauseEnabled'", 2)
end

function uibase:checkPause(x, y)
	error("pure virtual method 'checkPause'", 2)
	return true or false
end

------------------
-- Other things --
------------------

function uibase:addTapEffect(x, y, r, g, b, a)
	error("pure virtual method 'addTapEffect'", 2)
end

function uibase:setTextScaling(scale)
	error("pure virtual method 'setTextScaling'", 2)
end

function uibase:getOpacity()
	error("pure virtual method 'getOpacity'", 2)
end

function uibase:setOpacity(opacity)
	error("pure virtual method 'setOpacity'", 2)
end

function uibase:setComboCheer(enable)
	error("pure virtual method 'setComboCheer'", 2)
end

function uibase:setTotalNotes(total)
	error("pure virtual method 'setTotalNotes'", 2)
end

-- this will always be called multiple times, it's UI responsible to handle it
function uibase:startLiveClearAnimation(fullcombo, donecb, opaque)
	error("pure virtual method 'startLiveClearAnimation'", 2)
end

-------------
-- Drawing --
-------------

function uibase:drawHeader()
	error("pure virtual method 'drawHeader'", 2)
end

function uibase:drawStatus()
	error("pure virtual method 'drawStatus'", 2)
end

return uibase
