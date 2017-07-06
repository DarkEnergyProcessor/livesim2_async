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
	virtual Livesim2::Unit*[9] GetCustomUnitInformation();
	
	/// \brief Get score information sequence.
	/// \description This function returns unsigned integer with these index:
	///              - [0], score needed for C score
	///              - [1], score needed for B score
	///              - [2], score needed for A score
	///              - [3], score needed for S score
	/// \returns Score information array (or NULL if no score information present)
	virtual unsigned int* GetScoreInformation();
	
	virtual Livesim2::ComboInfo** GetComboInformation();
	virtual Livesim2::Storyboard* GetStoryboard();
	virtual Livesim2::Background* GetCustomBackground();
	virtual Livesim2::SoundData* GetBeatmapAudio();
	virtual Livesim2::SoundData* GetLiveClearSound();
	
	/// \brief Get star difficulty information.
	/// \param random Retrieve star difficulty information for random notes instead?
	/// \returns Star difficulty information, or 0 if not available
	virtual int GetStarDifficultyInfo(bool random);
}
]]
local AquaShine = ...
local love = love
local NoteLoader = {}
local NoteLoaderLoader = {}
local NoteLoaderNoteObject = {}

NoteLoaderLoader.__index = NoteLoaderLoader
NoteLoaderNoteObject.__index = NoteLoaderNoteObject

NoteLoader.FileLoaders = {}
NoteLoader.ProjectLoaders = {}

-- Load any note loaders with this glob: noteloader/load_*.lua
for _, f in ipairs(love.filesystem.getDirectoryItems("noteloader/")) do
	if f:find("load_", 1, true) == 1 and select(2, f:find(".lua", 4, true)) == #f then
		local loader = assert(love.filesystem.load("noteloader/"..f))(AquaShine, NoteLoader)
		local dest = loader.ProjectLoader and NoteLoader.ProjectLoaders or NoteLoader.FileLoaders
		
		dest[#dest + 1] = loader
		
		AquaShine.Log("NoteLoader2", "Registered note loader %s", loader.GetLoaderName())
	end
end

--------------------
-- Utils Function --
--------------------
function NoteLoader._GetBasenameWOExt(file)
	return (file:match("(.+)([%.$]+)"):gsub("(.*/)(.*)", "%2"))
end

------------------------
-- NoteLoader Loaders --
------------------------
function NoteLoaderLoader.LoadNoteFromFilename()
	assert(false, "Derive NoteLoaderLoader then implement LoadNoteFromFilename")
end

function NoteLoaderLoader.GetLoaderName()
	assert(false, "Derive NoteLoaderLoader then implement GetLoaderName")
end

----------------------------
-- NoteLoader Note Object --
----------------------------
local function nilret() return nil end

-- Derive function
function NoteLoaderNoteObject.__call(_)
	return setmetatable({}, NoteLoaderNoteObject)
end

function NoteLoaderNoteObject.GetNotesList()
	assert(false, "Derive NoteLoaderNoteObject then implement GetNotesList")
end

function NoteLoaderNoteObject.GetName()
	assert(false, "Derive NoteLoaderNoteObject then implement GetName")
end

function NoteLoaderNoteObject.GetBeatmapTypename()
	assert(false, "Derive NoteLoaderNoteObject then implement GetBeatmapTypename")
end

function NoteLoaderNoteObject.GetStarDifficultyInfo()
	return 0
end

function NoteLoaderNoteObject.GetCustomUnitInformation()
	return {}
end

NoteLoaderNoteObject.GetCoverArt = nilret
NoteLoaderNoteObject.GetScoreInformation = nilret
NoteLoaderNoteObject.GetComboInformation = nilret
NoteLoaderNoteObject.GetStoryboard = nilret
NoteLoaderNoteObject.GetCustomBackground = nilret
NoteLoaderNoteObject.GetBeatmapAudio = nilret
NoteLoaderNoteObject.GetLiveClearSound = nilret

return NoteLoader
