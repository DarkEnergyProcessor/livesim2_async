-- AquaShine entry point class base
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local class = require("30log")

AquaShine.EntryPoint = class("AquaShine.EntryPoint")

function AquaShine.EntryPoint:Update()
	error("Pure virtual method AquaShine.EntryPoint:Update")
end

function AquaShine.EntryPoint:Update()
	error("Pure virtual method AquaShine.EntryPoint:Draw")
end
