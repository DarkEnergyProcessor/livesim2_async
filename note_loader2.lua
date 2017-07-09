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
	
	/// \brief Retrieves background ID
	/// \returns -1, if custom background present, 0 if no background ID present, otherwise the background ID
	virtual int GetBackgroundID();
	
	/// \brief Retrieves custom background
	/// \returns NULL if custom background not present, otherwise handle to custom background object
	virtual Livesim2::Background* GetCustomBackground();
	
	virtual Livesim2::SoundData* GetBeatmapAudio();
	virtual Livesim2::SoundData* GetLiveClearSound();
	
	/// \brief Get star difficulty information.
	/// \param random Retrieve star difficulty information for random notes instead?
	/// \returns Star difficulty information, or 0 if not available
	virtual int GetStarDifficultyInfo(bool random);
	
	virtual void ReleaseBeatmapAudio();
	virtual void SetZIPMountPath(const char* path);
	virtual void Release();
};
]]

local AquaShine = ...
local love = love
local NoteLoader = {}
local NoteLoaderLoader = {}
local NoteLoaderNoteObject = {}

NoteLoaderLoader.__index = NoteLoaderLoader
NoteLoaderNoteObject.__index = NoteLoaderNoteObject

NoteLoader.NoteLoaderNoteObject = NoteLoaderNoteObject
NoteLoader.FileLoaders = {}
NoteLoader.ProjectLoaders = {}

---------------------------
-- Note Loading Function --
---------------------------
function NoteLoader._GetBasenameWOExt(file)
	return ((file:match("^(.+)%..*$") or file):gsub("(.*/)(.*)", "%2"))
end

function NoteLoader._LoadDefaultAudioFromFilename(file)
	return AquaShine.LoadAudio("audio/"..NoteLoader._GetBasenameWOExt(file)..".wav")
end

function NoteLoader.NoteLoader(file)
	local project_mode = love.filesystem.isDirectory(file)
	local destination = file
	local zip_path
	
	if select(2, file:find(".zip", 1, true)) == #file then
		-- ZIP mounting happends implictly, so beatmap loader doesn't need to worry about it
		-- But beatmap loader responsible to unmount it if necessary
		destination = "temp/.beatmap/"..file:gsub("(.*/)(.*)", "%2")
		project_mode = true
		zip_path = file
		
		assert(AquaShine.MountZip(file, destination), "Failed to open ZIP")
	end
	
	if project_mode then
		-- Project folder loading
		for i = 1, #NoteLoader.ProjectLoaders do
			local ldr = NoteLoader.ProjectLoaders[i]
			local _, nobj = pcall(ldr.LoadNoteFromFilename, destination)
			
			if _ then
				if zip_path then
					nobj:SetZIPMountPath(file)
				end
				
				return nobj
			end
			
			AquaShine.Log("NoteLoader2", "Failed to load %q with loader %s: %s", file, ldr.GetLoaderName(), nobj)
		end
		
		if zip_path then
			assert(AquaShine.MountZip(file, nil), "ZIP unmount failed")
		end
	else
		-- File loading
		for i = 1, #NoteLoader.FileLoaders do
			local ldr = NoteLoader.FileLoaders[i]
			local _, nobj = pcall(ldr.LoadNoteFromFilename, destination)
			
			if _ then
				return nobj
			end
			
			AquaShine.Log("NoteLoader2", "Failed to load %q with loader %s: %s", file, ldr.GetLoaderName(), nobj)
		end
	end
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
local function zeroret() return 0 end

-- Derive function
function NoteLoaderNoteObject._derive(tbl)
	return setmetatable(tbl, NoteLoaderNoteObject)
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

function NoteLoaderNoteObject.GetCustomUnitInformation()
	return {}
end

NoteLoaderNoteObject.GetStarDifficultyInfo = zeroret
NoteLoaderNoteObject.GetBackgroundID = zeroret

NoteLoaderNoteObject.GetCoverArt = nilret
NoteLoaderNoteObject.GetScoreInformation = nilret
NoteLoaderNoteObject.GetComboInformation = nilret
NoteLoaderNoteObject.GetStoryboard = nilret
NoteLoaderNoteObject.GetCustomBackground = nilret
NoteLoaderNoteObject.GetBeatmapAudio = nilret
NoteLoaderNoteObject.GetLiveClearSound = nilret
NoteLoaderNoteObject.SetZIPMountPath = nilret
NoteLoaderNoteObject.ReleaseBeatmapAudio = nilret
NoteLoaderNoteObject.Release = nilret

----------------
-- Initialize --
----------------

-- Load any note loaders with this glob: noteloader/load_*.lua
for _, f in ipairs(love.filesystem.getDirectoryItems("noteloader/")) do
	if f:find("load_", 1, true) == 1 and select(2, f:find(".lua", 4, true)) == #f then
		local loader = assert(love.filesystem.load("noteloader/"..f))(AquaShine, NoteLoader)
		local dest = loader.ProjectLoader and NoteLoader.ProjectLoaders or NoteLoader.FileLoaders
		
		dest[#dest + 1] = loader
		
		AquaShine.Log("NoteLoader2", "Registered note loader %s", loader.GetLoaderName())
	end
end

return NoteLoader
