-- Aquashine extension loader
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local ext = AquaShine.Config.Extensions

AquaShine.LoadModule("AquaShine.Composition")
AquaShine.LoadModule("AquaShine.EntryPoint")
AquaShine.LoadModule("AquaShine.Node")

if not(ext.DisableThreads) and not(ext.DisableDownload) then
	AquaShine.LoadModule("AquaShine.Download")
end

if not(ext.DisableFileDialog) then
	AquaShine.LoadModule("AquaShine.FileDialog")
end

if not(ext.DisableVideo) and not(ext.DisableFFX) then
	AquaShine.LoadModule("AquaShine.FFX2")
	
	if not(ext.DisableTempDirectory) then
		AquaShine.LoadModule("AquaShine.TempDirectory")
	end
end
