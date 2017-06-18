-- Note: build file expects these exact lines for them to be automatically replaced, so please don't change anything
local VERSION = "local"
local DISTRIBUTABLE = false

medialib = {}

medialib.VERSION = VERSION
medialib.DISTRIBUTABLE = DISTRIBUTABLE
medialib.INSTANCE = medialib.VERSION .. "_" .. tostring(10000 + math.random(90000))

medialib.Modules = {}

local cvar_debug = CreateConVar("medialib_debug", "0", FCVAR_ARCHIVE)
cvars.AddChangeCallback(cvar_debug:GetName(), function(_, _, val)
	medialib.DEBUG = val == "1"
end)
medialib.DEBUG = cvar_debug:GetBool()

function medialib.modulePlaceholder(name)
	medialib.Modules[name] = {}
end
function medialib.module(name, opts)
	if medialib.DEBUG then
		print("[MediaLib] Creating module " .. name)
	end

	local mod = medialib.Modules[name] or {
		name = name,
		options = opts,
	}

	medialib.Modules[name] = mod

	return mod
end

-- AddCSLuaFile all medialib modules
if SERVER then
	for _,fname in pairs(file.Find("medialib/*", "LUA")) do
		AddCSLuaFile("medialib/" .. fname)
	end
end

local file_Exists = file.Exists
function medialib.tryInclude(file)
	if file_Exists(file, "LUA") then
		include(file)
		return true
	end

	if medialib.DEBUG then
		print("[MediaLib] Attempted to include nonexistent file " .. file)
	end

	return false
end

function medialib.load(name)
	local mod = medialib.Modules[name]
	if mod then return mod end

	if medialib.DEBUG then
		print("[MediaLib] Loading unreferenced module " .. name)
	end

	local file = "medialib/" .. name .. ".lua"
	if not medialib.tryInclude(file) then return nil end

	return medialib.Modules[name]
end

local medialibg = setmetatable({medialib = medialib}, {__index = _G})

local real_file_meta = {
	read = function(self)
		return file.Read(self.lua_path, "LUA")
	end,
	load = function(self)
		--local str = self:read()
		--if not str then error("MedialibDynLoad: could not load " .. self.lua_path) end

		-- TODO this does not function correctly; embedded medialib loading real_file will use global medialib as its 'medialib' instance
		return include(self.lua_path)
	end,
	addcs = function(self)
		AddCSLuaFile(self.lua_path)
	end,
}
real_file_meta.__index = real_file_meta

local virt_file_meta = {
	read = function(self)
		return self.source
	end,
	load = function(self)
		local compiled = CompileString(self:read(), "MediaLib_DynFile_" .. self.name)
		setfenv(compiled, medialibg)
		return compiled()
	end,
	addcs = function() end
}
virt_file_meta.__index = virt_file_meta

-- Used for medialib packed into a single file
medialib.FolderItems = {}

-- Returns an iterator for files in folder
function medialib.folderIterator(folder)
	local files = {}
	for _,fname in pairs(file.Find("medialib/" .. folder .. "/*.lua", "LUA")) do
		table.insert(files, setmetatable({
			name = fname,
			lua_path = "medialib/" .. folder .. "/" .. fname
		}, real_file_meta))
	end

	for k,item in pairs(medialib.FolderItems) do
		local mfolder = k:match("^([^/]*).+")
		if mfolder == folder then
			table.insert(files, setmetatable({
				name = k:match("^[^/]*/(.+)"),
				source = item
			}, virt_file_meta))
		end
	end

	return pairs(files)
end

if CLIENT then
	local function Rainbow()
		for i=1, 30 do
			MsgC(HSVToColor(30*i, 0.5, 0.9), " " .. string.rep("SEE BELOW FOR INSTRUCTIONS  ", 3) .. "\n")
		end
	end
	concommand.Add("medialib_noflash", function(_, _, args)
		if args[1] == "rainbow" then Rainbow() end

		SetClipboardText("http://get.adobe.com/flashplayer/otherversions/")

		MsgN("[ MediaLib: How to get Flash Player ]")
		MsgN("1. Open this website in your browser (not the ingame Steam browser): http://get.adobe.com/flashplayer/otherversions/")
		MsgN("   (the link has been automatically copied to your clipboard)")
		MsgN("2. Download and install the NSAPI (for Firefox) version")
		MsgN("3. Restart your Garry's Mod and rejoin this server")
		MsgN("[ ======================= ]")
	end)

	concommand.Add("medialib_lowaudio", function(_, _, args)
		if args[1] == "rainbow" then Rainbow() end

		SetClipboardText("http://windows.microsoft.com/en-us/windows7/adjust-the-sound-level-on-your-computer")

		MsgN("[ MediaLib: How to fix muted sound ]")
		MsgN("1. Follow instructions here: http://windows.microsoft.com/en-us/windows7/adjust-the-sound-level-on-your-computer")
		MsgN("   (the link has been automatically copied to your clipboard, you can open it in the steam ingame browser)")
		MsgN("2. Increase the volume of a process called 'Awesomium Core'")
		MsgN("3. You should immediately start hearing sound if a mediaclip is playing")
		MsgN("[ ======================= ]")
	end)

	hook.Add("OnPlayerChat", "MediaLib.ShowInstructions", function(ply, text)
		if text:match("!ml_noflash") then
			RunConsoleCommand("medialib_noflash", "rainbow")
			RunConsoleCommand("showconsole")
		elseif text:match("!ml_lowvolume") then
			RunConsoleCommand("medialib_lowaudio", "rainbow")
			RunConsoleCommand("showconsole")
		end
	end)
end
