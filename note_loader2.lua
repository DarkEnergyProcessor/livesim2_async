-- NoteLoader2, OOP, efficient NoteLoader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

--[[
// Loader class
class NoteLoaderLoader
{
public:
	bool ProjectLoader;
	
	/// @brief Load specificed note from filename
	/// @returns Loaded note object on success, NULL on failure
	virtual NoteLoaderNoteObject* LoadNoteFromFilename(const char* filename) = 0;
	virtual const char* GetLoaderName() = 0;
};

// Returned from loader
class NoteLoaderNoteObject
{
public:
	/// \brief Get notes list
	/// \returns Notes list. This one never return NULL
	virtual std::vector<Livesim2::Note> GetNotesList() = 0;
	
	/// \brief Get beatmap name, or filename if no suitable filename found
	/// \returns Beatmap name. This one never return NULL
	virtual const char* GetName() = 0;
	
	/// \brief Get beatmap type name (friendly name)
	/// \returns Beatmap type name
	virtual const char* GetBeatmapTypename() = 0;
	
	/// \brief Get cover art information
	/// \returns Cover art information (or NULL)
	virtual Livesim2::CoverArt* GetCoverArt();
	
	/// \brief Get custom unit informmation
	/// \returns Custom unit information. Index 0 is rightmost (8 is leftmost). Some index may be NULL, but the returned pointer never NULL.
	/// \note Lua is 1-based, so it should be index 1 is rightmost.
	virtual Livesim2::Unit*[9] GetCustomUnitInformation();
	
	/// \brief Get score information sequence.
	/// \description This function returns unsigned integer with these index:
	///              - [0], score needed for C score
	///              - [1], score needed for B score
	///              - [2], score needed for A score
	///              - [3], score needed for S score
	/// \returns Score information array (or NULL if no score information present)
	virtual unsigned int* GetScoreInformation();
	
	virtual unsigned int* GetComboInformation();
	virtual bool HasStoryboard();
	virtual Livesim2::Storyboard* GetStoryboard();
	
	/// \brief Retrieves background ID
	/// \returns -1, if custom background present, 0 if no background ID (or video) present, otherwise the background ID
	virtual int GetBackgroundID();
	
	/// \brief Retrieves custom background
	/// \returns NULL if custom background not present, otherwise handle to custom background object
	virtual Livesim2::Background* GetCustomBackground();
	
	/// Returns the video handle or NULL if video not found
	virtual Livesim2::Video* GetVideoBackground();
	
	/// Returns score per tap or 0 to use from config
	virtual int GetScorePerTap();
	/// Returns stamina or 0 to use from config
	virtual char GetStamina();
	/// Returns: 1 = old, 2 = v5, 0 = no enforcing
	virtual int GetNotesStyle();
	
	virtual love::sound::SoundData* GetBeatmapAudio();
	virtual love::sound::SoundData* GetLiveClearSound();
	
	/// \brief Get star difficulty information.
	/// \param random Retrieve star difficulty information for random notes instead?
	/// \returns Star difficulty information, or 0 if not available
	virtual int GetStarDifficultyInfo(bool random);
	
	virtual void ReleaseBeatmapAudio();
	virtual void Release();
};
]]

--[[
Note for beatmap loaders:

For project-based loaders: LoadNoteFromFilename(path) returns 1 value
For file-based loaders: LoadNoteFromFilename(handle, path) returns 2 values:
	* The note object
	* Value to indicate that the file shouldn't be closed
]]

local AquaShine = ...
local love = love
local JSON = require("JSON")
local class = AquaShine.Class
local NoteLoader = {}
local NoteLoaderLoader = class("NoteLoader.NoteLoaderLoader")
local NoteLoaderNoteObject = class("NoteLoader.NoteLoaderNoteObject")
local NCache = assert(love.filesystem.load("noteloader_cache.lua"))(AquaShine, NoteLoader)

NoteLoader.NoteLoaderLoader = NoteLoaderLoader
NoteLoader.NoteLoaderNoteObject = NoteLoaderNoteObject
NoteLoader.FileLoaders = {}
NoteLoader.ProjectLoaders = {}

-- Use with string.gsub(str, ".", bin2hex)
local function bin2hex(x)
	return string.format("%02X", x:byte())
end

-- Use with string.gsub(str, "%x%x", hex2bin)
local function hex2bin(x)
	return string.char(tonumber(x, 16))
end

---------------------------
-- Note Loading Function --
---------------------------
function NoteLoader._GetBasenameWOExt(file)
	return ((file:match("^(.+)%..*$") or file):gsub("(.*/)(.*)", "%2"))
end

function NoteLoader._LoadDefaultAudioFromFilename(file)
	return AquaShine.LoadAudio("audio/"..NoteLoader._GetBasenameWOExt(file)..".wav")
end

--! @brief Load note object from specificed path
--! @param file The file path. Can be either file or directory
--! @param noproject Do not attempt to load beatmap as project beatmap?
--! @returns The note object, or nil on failure
--! @note Error message is printed to log
function NoteLoader.NoteLoader(file, noproject)
	local project_info_file = love.filesystem.getInfo(file)
	
	if project_info_file.type == "directory" then
		-- Project folder loading
		for i = 1, #NoteLoader.ProjectLoaders do
			local ldr = NoteLoader.ProjectLoaders[i]
			local success, nobj = xpcall(ldr.LoadNoteFromFilename, debug.traceback, file)
			
			if success then
				return nobj
			end
			
			AquaShine.Log("NoteLoader2", "Failed to load %q with loader %s: %s", file, ldr.GetLoaderName(), nobj)
		end
	elseif project_info_file.type == "file" then
		-- File loading
		local file_handle = love.filesystem.newFile(file, "r")
		
		if not(file_handle) then
			return nil, file..": Beatmap doesn't exist"
		end
		
		for i = 1, #NoteLoader.FileLoaders do
			local ldr = NoteLoader.FileLoaders[i]
			local success, nobj, noclose = xpcall(ldr.LoadNoteFromFilename, debug.traceback, file_handle, file)
			
			if success then
				if not(noclose) then file_handle:close() end
				return nobj
			end
			
			AquaShine.Log("NoteLoader2", "Failed to load %q with loader %s: %s", file, ldr.GetLoaderName(), nobj)
			file_handle:seek(0)
		end
		
		file_handle:close()
	end
	
	return nil, file..": No suitable beatmap format found"
end

function NoteLoader.Enumerate()
	local a = {}
	
	for _, f in ipairs(love.filesystem.getDirectoryItems("beatmap/")) do
		local b = NoteLoader.NoteLoader("beatmap/"..f)
		
		if b then
			a[#a + 1] = b
		end
	end
	
	return a
end

function NoteLoader.EnumerateCached()
	local a = {}
	
	for _, f in ipairs(love.filesystem.getDirectoryItems("beatmap/")) do
		local b = NCache.LoadCache("beatmap/"..f)
		
		if b then
			a[#a + 1] = b
		end
	end
	
	return a
end

function NoteLoader.GetLoader(name, file_first)
	local path = {NoteLoader.ProjectLoaders, NoteLoader.FileLoaders}
	if file_first then table.insert(path, 1, table.remove(path, 2)) end
	
	for i = 1, #path do
		for n, v in ipairs(path[i]) do
			if v.GetLoaderName() == name then
				return v
			end
		end
	end
end

------------------------
-- NoteLoader Loaders --
------------------------
function NoteLoaderLoader.LoadNoteFromFilename()
	error("Pure virtual method NoteLoaderLoader:LoadNoteFromFilename", 2)
end

function NoteLoaderLoader.GetLoaderName()
	error("Pure virtual method NoteLoaderLoader:GetLoaderName", 2)
end

----------------------------
-- NoteLoader Note Object --
----------------------------
local function nilret() return nil end
local function zeroret() return 0 end

function NoteLoaderNoteObject.GetNotesList()
	error("Pure virtual method NoteLoaderNoteObject:GetNotesList", 2)
end

function NoteLoaderNoteObject.GetName()
	error("Pure virtual method NoteLoaderNoteObject:GetName", 2)
end

function NoteLoaderNoteObject.GetBeatmapTypename()
	error("Pure virtual method NoteLoaderNoteObject:GetBeatmapTypename", 2)
end

function NoteLoaderNoteObject.GetCustomUnitInformation()
	return {}
end

function NoteLoaderNoteObject.HasStoryboard()
	return false
end

NoteLoaderNoteObject.GetStarDifficultyInfo = zeroret
NoteLoaderNoteObject.GetBackgroundID = zeroret
NoteLoaderNoteObject.GetScorePerTap = zeroret
NoteLoaderNoteObject.GetStamina = zeroret
NoteLoaderNoteObject.GetNotesStyle = zeroret

NoteLoaderNoteObject.GetCoverArt = nilret
NoteLoaderNoteObject.GetScoreInformation = nilret
NoteLoaderNoteObject.GetComboInformation = nilret
NoteLoaderNoteObject.GetStoryboard = nilret
NoteLoaderNoteObject.GetCustomBackground = nilret
NoteLoaderNoteObject.GetVideoBackground = nilret
NoteLoaderNoteObject.GetBeatmapAudio = nilret
NoteLoaderNoteObject.GetLiveClearSound = nilret
NoteLoaderNoteObject.ReleaseBeatmapAudio = nilret
NoteLoaderNoteObject.Release = nilret

----------------
-- Initialize --
----------------

-- Load any note loaders with this glob: noteloader/load_*.lua
for _, f in ipairs(love.filesystem.getDirectoryItems("noteloader/")) do
	if f:find("load_", 1, true) == 1 and select(2, f:find(".lua", 4, true)) == #f then
		local loader = assert(love.filesystem.load("noteloader/"..f))(AquaShine, NoteLoader, class)
		local dest = loader.ProjectLoader and NoteLoader.ProjectLoaders or NoteLoader.FileLoaders
		
		dest[#dest + 1] = loader
		
		AquaShine.Log("NoteLoader2", "Registered note loader %s", loader.GetLoaderName())
	end
end

return NoteLoader
