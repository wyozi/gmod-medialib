-- Note: build file expects these exact lines for them to be automatically replaced, so please don't change anything
local VERSION = "local"
local DISTRIBUTABLE = false

-- Check if medialib has already been defined
if medialib and medialib.VERSION ~= VERSION then
	print("[MediaLib] Warning: overwriting existing medialib. (local: " .. VERSION .. ", defined: " .. (medialib.VERSION or "-") .. ")")
end

medialib = {}

medialib.VERSION = VERSION
medialib.DISTRIBUTABLE = DISTRIBUTABLE

medialib.Modules = {}
medialib.DEBUG = false

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

function medialib.load(name)
	local mod = medialib.Modules[name]
	if mod then return mod end

	if medialib.DEBUG then
		print("[MediaLib] Loading unreferenced module " .. name)
	end

	local file = "medialib/" .. name .. ".lua"
	include(file)

	return medialib.Modules[name]
end

local real_file_meta = {
	read = function(self)
		return file.Read(self.lua_path, "LUA")
	end,
	load = function(self)
		include(self.lua_path)
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
		RunString(self.source)
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