-- AquaShine configuration file
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

return {
	Entries = {
		-- List of entry points in form
		-- name = {minarg, "scriptfile.lua"}
		-- if minarg is -1, it can't be invoked from command-line
		livesim = {1, "livesim2_cliwrap.lua"},
		livesim_main = {-1, "livesim.lua"},
		settings = {0, "setting_view.lua"},
		main_menu = {0, "main_menu.lua"},
		beatmap_select = {0, "beatmap_select_wrapper.lua"},
		unit_editor = {0, "unit_editor.lua"},
		unit_selection = {-1, "unit_selection.lua"},
		about = {0, "about_screen.lua"},
		render = {3, "render_livesim.lua"},
		noteloader = {1, "invoke_noteloader.lua"},
		unit_create = {0, "unit_create.lua"},
	},
	-- Default entry point to be used if there's none specificed in command-line
	DefaultEntry = "main_menu",
	-- Allow entry points to be preloaded?
	-- Disabling entry preloading allows code that changed to be reflected without restarting
	EntryPointPreload = false,
	
	-- Logical screen width. Letterboxed if necessary.
	LogicalWidth = 960,
	-- Logical screen height. Letterboxed if necessary.
	LogicalHeight = 640,
	
	-- LOVE-specific configuration
	LOVE = {
		-- The name of the save directory
		Identity = "DEPLS",
		-- The LÖVE version this game was made for
		Version = "0.10.1",
		-- Enable external storage for Android
		AndroidExternalStorage = true,
		-- Window title name
		WindowTitle = "Live Simulator: 2",
		-- Window icon path
		WindowIcon = "assets/image/icon/icon.png",
		-- Default window width
		Width = 960,
		-- Default window height
		Height = 640,
		-- Let the window be user-resizable
		Resizable = true,
		-- Minimum window width if the window is resizable
		MinWidth = 320,
		-- Minimum window height if the window is resizable
		MinHeight = 240
	},
}
