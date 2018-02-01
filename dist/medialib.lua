local medialib

do
-- Note: build file expects these exact lines for them to be automatically replaced, so please don't change anything
local VERSION = "git@75ecf4d8"
local DISTRIBUTABLE = true

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

end

-- 'oop'; CodeLen/MinifiedLen 2927/2927; Dependencies []
medialib.modulePlaceholder("oop")
do
local oop = medialib.module("oop")
oop.Classes = oop.Classes or {}

function oop.class(name, parent)
	local cls = oop.Classes[name]
	if not cls then
		cls = oop.createClass(name, parent)
		oop.Classes[name] = cls

		if medialib.DEBUG then
			print("[MediaLib] Registering oopclass " .. name)
		end
	end

	return cls
end

function oop.resolveClass(obj)
	if obj == nil then
		return oop.Object
	end

	local t = type(obj)
	if t == "string" then
		local clsobj = oop.Classes[obj]
		if clsobj then return clsobj end

		error("Resolving class from inexistent class string '" .. tostring(obj) .. "'")
	end
	if t == "table" then
		return obj
	end

	error("Resolving class from invalid object '" .. tostring(obj) .. "'")
end

-- This is a special parent used to prevent oop.Object being parent of itself
local NIL_PARENT = {}

-- Credits to Middleclass
local metamethods = {'__add', '__call', '__concat', '__div', '__ipairs', '__le',
					 '__len', '__lt', '__mod', '__mul', '__pairs', '__pow', '__sub',
					 '__tostring', '__unm'}

function oop.createClass(name, parent)
	local cls = {}

	-- Get parent class
	local par_cls
	if parent ~= NIL_PARENT then
		par_cls = oop.resolveClass(parent)
	end

	-- Add metadata
	cls.name = name
	cls.super = par_cls

	-- Add a subtable for class members ie methods and class/super handles
	cls.members = setmetatable({}, {__index = cls.super})

	-- Add built-in "keywords" that Instances can access
	cls.members.class = cls
	cls.members.super = cls.super

	-- Instance metatable
	local cls_instance_meta = {}
	do
		cls_instance_meta.__index = cls.members

		-- Add metamethods. The class does not have members yet, so we need to use runtime lookup
		for _,name in pairs(metamethods) do
			cls_instance_meta[name] = function(...)
				local method = cls.members[name]
				if method then
					return method(...)
				end
			end
		end
	end

	-- Class metatable
	local class_meta = {}
	do
		class_meta.__index = cls.members
		class_meta.__newindex = cls.members

		class_meta.__tostring = function(self)
			return "class " .. self.name
		end

		-- Make the Class object a constructor.
		-- ie calling Class() creates a new instance
		function class_meta:__call(...)
			local instance = {}
			setmetatable(instance, cls_instance_meta)

			-- Call constructor if exists
			local ctor = instance.initialize
			if ctor then ctor(instance, ...) end

			return instance
		end
	end

	-- Set meta functions
	setmetatable(cls, class_meta)

	return cls
end

oop.Object = oop.createClass("Object", NIL_PARENT)

-- Get the hash code ie the value Lua prints when you call __tostring()
function oop.Object:hashCode()
	local meta = getmetatable(self)

	local old_tostring = meta.__tostring
	meta.__tostring = nil

	local hash = tostring(self):match("table: 0x(.*)")

	meta.__tostring = old_tostring

	return hash
end

function oop.Object:__tostring()
	return string.format("%s@%s", self.class.name, self:hashCode())
end
end
-- 'mediabase'; CodeLen/MinifiedLen 4305/4305; Dependencies [oop]
medialib.modulePlaceholder("mediabase")
do
local oop = medialib.load("oop")

local Media = oop.class("Media")

function Media:on(event, callback)
	self._events = self._events or {}
	self._events[event] = self._events[event] or {}
	self._events[event][callback] = true
end
function Media:emit(event, ...)
	if not self._events then return end

	local callbacks = self._events[event]
	if not callbacks then return end

	for k,_ in pairs(callbacks) do
		k(...)
	end
end

function Media:getServiceBase()
	error("Media:getServiceBase() not implemented!")
end
function Media:getService()
	return self._service
end
function Media:getUrl()
	return self._unresolvedUrl
end

-- If metadata is cached: return it
-- Otherwise either start a new metadata query, or if one is already going on
-- do nothing
function Media:lookupMetadata()
	local md = self._metadata

	-- Already fetched
	if type(md) == "table" then return md end

	-- Fetching or there was an error (TODO make error available to user)
	if md == true or type(md) == "string" then return nil end

	self._metadata = true
	self:getService():query(self:getUrl(), function(err, data)
		if err then
			self._metadata = err
		else
			self._metadata = data
		end
	end)

	return nil
end

-- True returned from this function does not imply anything related to how
-- ready media is to play, just that it exists somewhere in memory and should
-- at least in some point in the future be playable, but even that is not guaranteed
function Media:isValid()
	return false
end

-- The GMod global IsValid requires the uppercase version
function Media:IsValid()
	return self:isValid()
end

-- vol must be a float between 0 and 1
function Media:setVolume(vol) end
function Media:getVolume() end

-- "Quality" must be one of following strings: "low", "medium", "high", "veryhigh"
-- Qualities do not map equally between services (ie "low" in youtube might be "medium" in twitch)
-- Services are not guaranteed to change to the exact provided quality, or even to do anything at all
function Media:setQuality(quality) end

-- time must be an integer between 0 and duration
function Media:seek(time) end
function Media:getTime()
	return 0
end

-- This method can be called repeatedly to keep the media somewhat in sync
-- with given time, which makes it a great function to keep eg. synchronized
-- televisions in sync.
function Media:sync(time, margin)
	-- Only sync at most once per five seconds
	if self._lastSync and self._lastSync > CurTime() - 5 then
		return
	end

	local shouldSync = self:shouldSync(time, margin)
	if not shouldSync then return end

	self:seek(time + 0.1) -- Assume 0.1 sec loading time
	self._lastSync = CurTime()
end

function Media:shouldSync(time, margin)
	-- Check for invalid syncing state
	if not self:isValid() or not self:isPlaying() then
		return false
	end

	margin = margin or 2

	local curTime = self:getTime()
	local diff = math.abs(curTime - time)

	return diff > margin
end

-- Must return one of following strings: "error", "loading", "buffering", "playing", "paused", "ended"
-- Can also return nil if state is unknown or cannot be represented properly
-- If getState does not return nil, it should be assumed to be the correct current state
function Media:getState() end

-- Simplified function of above; simply returns boolean indicating playing state
function Media:isPlaying()
	return self:getState() == "playing"
end

function Media:play() end
function Media:pause() end
function Media:stop() end

-- Queue a function to run after media is loaded. The function should run immediately
-- if media is already loaded.
function Media:runCommand(fn) end

function Media:draw(x, y, w, h) end

function Media:getTag() return self._tag end
function Media:setTag(tag) self._tag = tag end
function Media:guessDefaultTag()
	for i=1, 10 do
		local info = debug.getinfo(i, "S")
		if not info then break end

		local src = info.short_src
		local addon = src:match("addons/(.-)/")
		if addon and addon ~= "medialib" then return string.format("addon:%s", addon) end
	end

	return "addon:medialib"
end
function Media:setDefaultTag()
	self:setTag(self:guessDefaultTag())
end

function Media:getDebugInfo()
	return string.format("[%s] Media [%s] valid:%s state:%s url:%s time:%d", self:getTag(), self.class.name, tostring(self:isValid()), self:getState(), self:getUrl(), self:getTime())
end

end
-- 'media'; CodeLen/MinifiedLen 746/746; Dependencies []
medialib.modulePlaceholder("media")
do
local media = medialib.module("media")
media.Services = {}

function media.registerService(name, cls)
	media.Services[name] = cls()
end
media.RegisterService = media.registerService -- alias

function media.service(name)
	return media.Services[name]
end
media.Service = media.service -- alias

function media.guessService(url, opts)
	for name,service in pairs(media.Services) do
		local isViable = true

		if opts and opts.whitelist then
			isViable = isViable and table.HasValue(opts.whitelist, name)
		end
		if opts and opts.blacklist then
			isViable = isViable and not table.HasValue(opts.blacklist, name)
		end

		if isViable and service:isValidUrl(url) then
			return service
		end
	end
end
media.GuessService = media.guessService -- alias

end
-- 'mediaregistry'; CodeLen/MinifiedLen 1246/1246; Dependencies []
medialib.modulePlaceholder("mediaregistry")
do
local mediaregistry = medialib.module("mediaregistry")

local cache = setmetatable({}, {__mode = "v"})

function mediaregistry.add(media)
	table.insert(cache, media)
end
function mediaregistry.get()
	return cache
end

concommand.Add("medialib_listall", function()
	hook.Run("MediaLib_ListAll")
end)
hook.Add("MediaLib_ListAll", "MediaLib_" .. medialib.INSTANCE, function()
	print("Media for medialib version " .. medialib.INSTANCE .. ":")
	for _,v in pairs(cache) do
		print(v:getDebugInfo())
	end
end)

concommand.Add("medialib_stopall", function()
	hook.Run("MediaLib_StopAll")
end)
hook.Add("MediaLib_StopAll", "MediaLib_" .. medialib.INSTANCE, function()
	for _,v in pairs(cache) do
		v:stop()
	end

	table.Empty(cache)
end)

local cvar_debug = CreateConVar("medialib_debugmedia", "0")
hook.Add("HUDPaint", "MediaLib_G_DebugMedia", function()
	if not cvar_debug:GetBool() then return end
	local counter = {0}
	hook.Run("MediaLib_DebugPaint", counter)
end)

hook.Add("MediaLib_DebugPaint", "MediaLib_" .. medialib.INSTANCE, function(counter)
	local i = counter[1]
	for _,media in pairs(cache) do
		local t = string.format("#%d %s", i, media:getDebugInfo())
		draw.SimpleText(t, "DermaDefault", 10, 10 + i*15)

		i=i+1
	end
	counter[1] = i
end)
end
-- 'servicebase'; CodeLen/MinifiedLen 2234/2234; Dependencies [oop,mediaregistry]
medialib.modulePlaceholder("servicebase")
do
local oop = medialib.load("oop")
local mediaregistry = medialib.load("mediaregistry")

local Service = oop.class("Service")

function Service:on(event, callback)
	self._events = {}
	self._events[event] = self._events[event] or {}
	self._events[event][callback] = true
end
function Service:emit(event, ...)
	for k,_ in pairs(self._events[event] or {}) do
		k(...)
	end

	if event == "error" then
		MsgN("[MediaLib] Video error: " .. table.ToString{...})
	end
end

function Service:load(url, opts) end
function Service:loadMediaObject(media, url, opts)
	media._unresolvedUrl = url
	media._service = self

	media:setDefaultTag()

	hook.Run("Medialib_ProcessOpts", media, opts or {})

	mediaregistry.add(media)

	self:resolveUrl(url, function(resolvedUrl, resolvedData)
		media:openUrl(resolvedUrl)

		if resolvedData and resolvedData.start and (not opts or not opts.dontSeek) then media:seek(resolvedData.start) end
	end)
end

function Service:isValidUrl(url) end

-- Sub-services should override this
function Service:directQuery(url, callback) end

-- A metatable for the callback chain
local _service_cbchain_meta = {}
_service_cbchain_meta.__index = _service_cbchain_meta
function _service_cbchain_meta:addCallback(cb)
	table.insert(self._callbacks, cb)
end
function _service_cbchain_meta:run(err, data)
	local first = table.remove(self._callbacks, 1)
	if not first then return end

	first(err, data, function(err, data)
		self:run(err, data)
	end)
end

-- Query calls direct query and then passes the data through a medialib hook
function Service:query(url, callback)
	local cbchain = setmetatable({_callbacks = {}}, _service_cbchain_meta)

	-- First add the data gotten from the service itself
	cbchain:addCallback(function(_, _, cb) return self:directQuery(url, cb) end)

	-- Then add custom callbacks
	hook.Run("Medialib_ExtendQuery", url, cbchain)

	-- Then add the user callback
	cbchain:addCallback(function(err, data) callback(err, data) end)

	-- Finally run the chain
	cbchain:run(url)
end

function Service:parseUrl(url) end

-- the second argument to cb() function call has some standard keys:
--   `start` the time at which to start media in seconds
function Service:resolveUrl(url, cb)
	cb(url, self:parseUrl(url))
end

end
-- 'timekeeper'; CodeLen/MinifiedLen 1016/1016; Dependencies [oop]
medialib.modulePlaceholder("timekeeper")
do
-- The purpose of TimeKeeper is to keep time where it is not easily available synchronously (ie. HTML based services)
local oop = medialib.load("oop")

local TimeKeeper = oop.class("TimeKeeper")

function TimeKeeper:initialize()
	self:reset()
end

function TimeKeeper:reset()
	self.cachedTime = 0

	self.running = false
	self.runningTimeStart = 0
end

function TimeKeeper:getTime()
	local time = self.cachedTime

	if self.running then
		time = time + (RealTime() - self.runningTimeStart)
	end

	return time
end

function TimeKeeper:isRunning()
	return self.running
end

function TimeKeeper:play()
	if self.running then return end

	self.runningTimeStart = RealTime()
	self.running = true
end

function TimeKeeper:pause()
	if not self.running then return end
	
	local runningTime = RealTime() - self.runningTimeStart
	self.cachedTime = self.cachedTime + runningTime

	self.running = false
end

function TimeKeeper:seek(time)
	self.cachedTime = time

	if self.running then
		self.runningTimeStart = RealTime()
	end
end
end
-- 'service_html'; CodeLen/MinifiedLen 8426/8426; Dependencies [oop,timekeeper]
medialib.modulePlaceholder("service_html")
do
local oop = medialib.load("oop")
medialib.load("timekeeper")

local HTMLService = oop.class("HTMLService", "Service")
function HTMLService:load(url, opts)
	local media = oop.class("HTMLMedia")()
	self:loadMediaObject(media, url, opts)
	return media
end

-- Whether or not we can trust that the HTML panel will send 'playing', 'paused'
-- and other playback related events. If this returns true, 'timekeeper' will
-- not be updated in playback related methods (except stop).
function HTMLService:hasReliablePlaybackEvents(media)
	return false
end

local HTMLPool = {instances = {}}
local function GetMaxPoolInstances()
	return medialib.MAX_HTMLPOOL_INSTANCES or 0
end

hook.Add("MediaLib_HTMLPoolInfo", medialib.INSTANCE, function()
	print(medialib.INSTANCE .. "> Free HTMLPool instance count: " .. #HTMLPool.instances .. "/" .. GetMaxPoolInstances())
end)
concommand.Add("medialib_htmlpoolinfo", function()
	hook.Run("MediaLib_HTMLPoolInfo")
end)

-- Automatic periodic cleanup of html pool objects
timer.Create("MediaLib." .. medialib.INSTANCE .. ".HTMLPoolCleaner", 60, 0, function()
	if #HTMLPool.instances == 0 then return end

	local inst = table.remove(HTMLPool.instances, 1)
	if IsValid(inst) then inst:Remove() end
end)
function HTMLPool.newInstance()
	return vgui.Create("DHTML")
end
function HTMLPool.get()
	if #HTMLPool.instances == 0 then
		if medialib.DEBUG then
			MsgN("[MediaLib] Returning new instance; htmlpool empty")
		end
		return HTMLPool.newInstance()
	end

	local inst = table.remove(HTMLPool.instances, 1)
	if not IsValid(inst) then
		if medialib.DEBUG then
			MsgN("[MediaLib] Returning new instance; instance was invalid")
		end
		return HTMLPool.newInstance()
	end
	if medialib.DEBUG then
		MsgN("[MediaLib] Returning an instance from the HTML pool")
	end
	return inst
end
function HTMLPool.free(inst)
	if not IsValid(inst) then return end

	if #HTMLPool.instances >= GetMaxPoolInstances() then
		if medialib.DEBUG then
			MsgN("[MediaLib] HTMLPool full; removing the freed instance")
		end
		inst:Remove()
	else
		if medialib.DEBUG then
			MsgN("[MediaLib] Freeing an instance to the HTMLPool")
		end
		inst:SetHTML("")
		table.insert(HTMLPool.instances, inst)
	end
end

local cvar_showAllMessages = CreateConVar("medialib_showallmessages", "0")

local HTMLMedia = oop.class("HTMLMedia", "Media")

local panel_width, panel_height = 1280, 720
function HTMLMedia:initialize()
	self.timeKeeper = oop.class("TimeKeeper")()

	self.panel = HTMLPool.get()

	local pnl = self.panel
	pnl:SetPos(0, 0)
	pnl:SetSize(panel_width, panel_height)

	local hookid = "MediaLib.HTMLMedia.FakeThink-" .. self:hashCode()
	hook.Add("Think", hookid, function()
		if not IsValid(self.panel) then
			hook.Remove("Think", hookid)
			return
		end

		self.panel:Think()
	end)

	local oldcm = pnl._OldCM or pnl.ConsoleMessage
	pnl._OldCM = oldcm
	pnl.ConsoleMessage = function(pself, msg)
		if msg and not cvar_showAllMessages:GetBool() then
			-- Filter some things out
			if string.find(msg, "XMLHttpRequest", nil, true) then return end
			if string.find(msg, "Unsafe JavaScript attempt to access", nil, true) then return end
			if string.find(msg, "Unable to post message to", nil, true) then return end
			if string.find(msg, "ran insecure content from", nil, true) then return end
			if string.find(msg, "Mixed Content:", nil, true) then return end
		end

		return oldcm(pself, msg)
	end

	pnl:AddFunction("console", "warn", function(param)
		-- Youtube seems to spam lots of useless stuff here (that requires this function still?), so block by default
		if not cvar_showAllMessages:GetBool() then return end

		pnl:ConsoleMessage(param)
	end)

	pnl:SetPaintedManually(true)
	pnl:SetVisible(false)

	pnl:AddFunction("medialiblua", "Event", function(id, jsonstr)
		self:handleHTMLEvent(id, util.JSONToTable(jsonstr))
	end)
end

function HTMLMedia:getBaseService()
	return "html"
end

function HTMLMedia:openUrl(url)
	self.panel:OpenURL(url)

	self.URLChanged = CurTime()
end
function HTMLMedia:runJS(js, ...)
	local code = string.format(js, ...)
	self.panel:QueueJavascript(code)
end

function HTMLMedia:handleHTMLEvent(id, event)
	if medialib.DEBUG then
		MsgN("[MediaLib] HTML Event: " .. id .. " (" .. table.ToString(event) .. ")")
	end
	if id == "stateChange" then
		local state = event.state
		local setToState

		if event.time then
			self.timeKeeper:seek(event.time)
		end
		if state == "playing" then
			setToState = "playing"
			self.timeKeeper:play()
		elseif state == "ended" or state == "paused" or state == "buffering" then
			setToState = state
			self.timeKeeper:pause()
		end

		if setToState then
			self.state = setToState
			self:emit(setToState)
		end
	elseif id == "playerLoaded" then
		for _,fn in pairs(self.commandQueue or {}) do
			fn()
		end
	elseif id == "error" then
		self:emit("error", {errorId = "service_error", errorName = "Error from service: " .. tostring(event.message)})
	else
		MsgN("[MediaLib] Unhandled HTML event " .. tostring(id))
	end
end
function HTMLMedia:getState()
	return self.state
end

local cvar_updatestride = CreateConVar("medialib_html_updatestride", "1", FCVAR_ARCHIVE)
function HTMLMedia:updateTexture()
	local framenumber = FrameNumber()

	local framesSinceUpdate = (framenumber - (self.lastUpdatedFrame or 0))
	if framesSinceUpdate >= cvar_updatestride:GetInt() then
		self.panel:UpdateHTMLTexture()
		self.lastUpdatedFrame = framenumber
	end
end

function HTMLMedia:getHTMLMaterial()
	if self._htmlMat then
		return self._htmlMat
	end
	local mat = self.panel:GetHTMLMaterial()
	self._htmlMat = mat
	return mat
end

function HTMLMedia:draw(x, y, w, h)
	self:updateTexture()

	local mat = self:getHTMLMaterial()

	-- [June 2017] CEF GetHTMLMaterial returns nil for some time after panel creation
	if not mat then
		return
	end

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)

	local w_frac, h_frac = panel_width / mat:Width(), panel_height / mat:Height()
	surface.DrawTexturedRectUV(x or 0, y or 0, w or panel_width, h or panel_height, 0, 0, w_frac, h_frac)
end

function HTMLMedia:getTime()
	return self.timeKeeper:getTime()
end

function HTMLMedia:setQuality(qual)
	if self.lastSetQuality and self.lastSetQuality == qual then
		return
	end
	self.lastSetQuality = qual

	self:runJS("medialibDelegate.run('setQuality', {quality: %q})", qual)
end

-- This applies the volume to the HTML panel
-- There is a undocumented 'internalVolume' variable, that can be used by eg 3d vol
function HTMLMedia:applyVolume()
	local ivol = self.internalVolume or 1
	local rvol = self.volume or 1

	local vol = ivol * rvol

	if self.lastSetVolume and self.lastSetVolume == vol then
		return
	end
	self.lastSetVolume = vol

	self:runJS("medialibDelegate.run('setVolume', {vol: %f})", vol)
end

-- This sets a volume variable
function HTMLMedia:setVolume(vol)
	self.volume = vol
	self:applyVolume()
end

function HTMLMedia:getVolume()
	-- could cookies potentially set the volume to something other than 1?
	return self.volume or 1
end

-- if we dont rely on callbacks from JS, this will be the 'buffer' time for seeks
local SEEK_BUFFER = 0.2

function HTMLMedia:seek(time)
	-- Youtube does not seem to properly callback with a 'seek' event (works in Chrome)
	-- Workaround by setting timeseeker time instantly here with a small buffer
	-- Using workaround is ok because if we somehow get event later, it'll correct
	-- the time that was set wrongly here
	self.timeKeeper:seek(time - SEEK_BUFFER)

	self:runJS("medialibDelegate.run('seek', {time: %.1f})", time)
end

-- See HTMLService:hasReliablePlaybackEvents()
function HTMLMedia:hasReliablePlaybackEvents()
	local service = self:getService()
	return service and service:hasReliablePlaybackEvents(self)
end

function HTMLMedia:play()
	if not self:hasReliablePlaybackEvents() then
		self.timeKeeper:play()
	end

	self:runJS("medialibDelegate.run('play')")
end
function HTMLMedia:pause()
	if not self:hasReliablePlaybackEvents() then
		self.timeKeeper:pause()
	end

	self:runJS("medialibDelegate.run('pause')")
end
function HTMLMedia:stop()
	HTMLPool.free(self.panel)
	self.panel = nil

	self.timeKeeper:pause()
	self:emit("ended", {stopped = true})
	self:emit("destroyed")
end

function HTMLMedia:runCommand(fn)
	if self._playerLoaded then
		fn()
	else
		self.commandQueue = self.commandQueue or {}
		self.commandQueue[#self.commandQueue+1] = fn
	end
end

function HTMLMedia:isValid()
	return IsValid(self.panel)
end

end
-- 'service_bass'; CodeLen/MinifiedLen 6686/6686; Dependencies [oop,mediaregistry]
medialib.modulePlaceholder("service_bass")
do
local oop = medialib.load("oop")

local BASSService = oop.class("BASSService", "Service")
function BASSService:load(url, opts)
	local media = oop.class("BASSMedia")()
	self:loadMediaObject(media, url, opts)
	return media
end

local BASSMedia = oop.class("BASSMedia", "Media")

function BASSMedia:initialize()
	self.bassPlayOptions = {"noplay", "noblock"}
	self.commandQueue = {}
end

function BASSMedia:getBaseService()
	return "bass"
end

function BASSMedia:updateFFT()
	local curFrame = FrameNumber()
	if self._lastFFTUpdate and self._lastFFTUpdate == curFrame then return end
	self._lastFFTUpdate = curFrame

	local chan = self.chan
	if not IsValid(chan) then return end

	self.fftValues = self.fftValues or {}
	chan:FFT(self.fftValues, FFT_512)
end

function BASSMedia:getFFT()
	return self.fftValues
end

function BASSMedia:draw(x, y, w, h)
	surface.SetDrawColor(0, 0, 0)
	surface.DrawRect(x, y, w, h)

	self:updateFFT()
	local fftValues = self:getFFT()
	if not fftValues then return end

	local valCount = #fftValues
	local valsPerX = (valCount == 0 and 1 or (w/valCount))

	local barw = w / (valCount)
	for i=1, valCount do
		surface.SetDrawColor(HSVToColor(i, 0.9, 0.5))

		local barh = fftValues[i]*h
		surface.DrawRect(x + i*barw, y + (h-barh), barw, barh)
	end
end

function BASSMedia:openUrl(url)
	self._openingInfo = {"url", url}

	local flags = table.concat(self.bassPlayOptions, " ")

	sound.PlayURL(url, flags, function(chan, errId, errName)
		self:bassCallback(chan, errId, errName)
	end)
end
function BASSMedia:openFile(path)
	self._openingInfo = {"file", path}

	local flags = table.concat(self.bassPlayOptions, " ")

	sound.PlayFile(path, flags, function(chan, errId, errName)
		self:bassCallback(chan, errId, errName)
	end)
end

-- Attempts to reload the stream
function BASSMedia:reload()
	local type, resource = unpack(self._openingInfo or {})
	if not type then
		MsgN("[Medialib] Attempting to reload BASS stream that was never started the first time!")
		return
	end

	-- stop existing channel if it exists
	if IsValid(self.chan) then
		self.chan:Stop()
		self.chan = nil
	end

	-- Remove stop flag, clear cmd queue, stop state checker
	self._stopped = false
	self:stopStateChecker()
	self.commandQueue = {}

	MsgN("[Medialib] Attempting to reload BASS stream ", type, resource)
	if type == "url" then
		self:openUrl(resource)
	elseif type == "file" then
		self:openFile(resource)
	elseif type then
		MsgN("[Medialib] Failed to reload audio resource ", type, resource)
		return
	end

	self:applyVolume(true)

	if self._commandState == "play" then
		self:play()
	end
end

function BASSMedia:bassCallback(chan, errId, errName)
	if not IsValid(chan) then
		ErrorNoHalt("[MediaLib] BassMedia play failed: ", errName)
		self._stopped = true

		self:emit("error", "loading_failed", string.format("BASS error id: %s; name: %s", errId, errName))
		return
	end

	-- Check if media was stopped before loading
	if self._stopped then
		MsgN("[MediaLib] Loading BASS media aborted; stop flag was enabled")
		chan:Stop()
		return
	end

	self.chan = chan

	for _,c in pairs(self.commandQueue) do
		c(chan)
	end

	-- Empty queue
	self.commandQueue = {}

	self:startStateChecker()
end

function BASSMedia:startStateChecker()
	timer.Create("MediaLib_BASS_EndChecker_" .. self:hashCode(), 1, 0, function()
		if IsValid(self.chan) and self.chan:GetState() == GMOD_CHANNEL_STOPPED then
			self:emit("ended")
			self:stopStateChecker()
		end
	end)
end
function BASSMedia:stopStateChecker()
	timer.Remove("MediaLib_BASS_EndChecker_" .. self:hashCode())
end

function BASSMedia:runCommand(fn)
	if IsValid(self.chan) then
		fn(self.chan)
	else
		self.commandQueue[#self.commandQueue+1] = fn
	end
end


-- This applies the volume to the HTML panel
-- There is a undocumented 'internalVolume' variable, that can be used by eg 3d vol
function BASSMedia:applyVolume(force)
	local ivol = self.internalVolume or 1
	local rvol = self.volume or 1

	local vol = ivol * rvol

	if not force and self.lastSetVolume and self.lastSetVolume == vol then
		return
	end
	self.lastSetVolume = vol

	self:runCommand(function(chan) chan:SetVolume(vol) end)
end
function BASSMedia:setVolume(vol)
	self.volume = vol
	self:applyVolume()
end

function BASSMedia:getVolume()
	return self.volume or 1
end

function BASSMedia:seek(time)
	self:runCommand(function(chan)
		if chan:IsBlockStreamed() then return end

		self._seekingTo = time

		local timerId = "MediaLib_BASSMedia_Seeker_" .. self:hashCode()
		local function AttemptSeek()
				-- someone used :seek with other time
			if  self._seekingTo ~= time or
				-- chan not valid
				not IsValid(chan) then

				timer.Destroy(timerId)
				return
			end

			chan:SetTime(time)

			-- seek succeeded
			if math.abs(chan:GetTime() - time) < 0.25 then
				timer.Destroy(timerId)
			end
		end
		timer.Create(timerId, 0.2, 0, AttemptSeek)
		AttemptSeek()
	end)
end
function BASSMedia:getTime()
	if self:isValid() and IsValid(self.chan) then
		return self.chan:GetTime()
	end
	return 0
end

function BASSMedia:getState()
	if not self:isValid() then return "error" end

	if not IsValid(self.chan) then return "loading" end

	local bassState = self.chan:GetState()
	if bassState == GMOD_CHANNEL_PLAYING then return "playing" end
	if bassState == GMOD_CHANNEL_PAUSED then return "paused" end
	if bassState == GMOD_CHANNEL_STALLED then return "buffering" end
	if bassState == GMOD_CHANNEL_STOPPED then return "paused" end -- umm??
	return
end

function BASSMedia:play()
	self:runCommand(function(chan)
		chan:Play()
		self:emit("playing")
		self._commandState = "play"
	end)
end
function BASSMedia:pause()
	self:runCommand(function(chan)
		chan:Pause()
		self:emit("paused")
		self._commandState = "pause"
	end)
end
function BASSMedia:stop()
	self._stopped = true
	self:runCommand(function(chan)
		chan:Stop()
		self:emit("ended", {stopped = true})
		self:emit("destroyed")

		self:stopStateChecker()
	end)
end

function BASSMedia:isValid()
	return not self._stopped
end

local mediaregistry = medialib.load("mediaregistry")

local netmsgid = "ML_MapCleanHack_" .. medialib.INSTANCE
if CLIENT then

	-- Logic for reloading BASS streams after map cleanups
	-- Workaround until gmod issue #2874 gets fixed
	net.Receive(netmsgid, function()
		for _,v in pairs(mediaregistry.get()) do

			-- BASS media that should play, yet does not
			if v:getBaseService() == "bass" and v:isValid() and IsValid(v.chan) and v.chan:GetState() == GMOD_CHANNEL_STOPPED then
				v:reload()
			end
		end
	end)
end
if SERVER then
	util.AddNetworkString(netmsgid)
	hook.Add("PostCleanupMap", "MediaLib_BassReload" .. medialib.INSTANCE, function()
		net.Start(netmsgid)
		net.Broadcast()
	end)
end
end
medialib.FolderItems["services/gdrive.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal GDriveService = oop.class(\"GDriveService\", \"HTMLService\")\nGDriveService.identifier = \"GDrive\"\n\nlocal all_patterns = {\"^https?://drive.google.com/file/d/([^/]*)/edit\"}\n\nfunction GDriveService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction GDriveService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal function urlencode(str)\n   if (str) then\n      str = string.gsub (str, \"\\n\", \"\\r\\n\")\n      str = string.gsub (str, \"([^%w ])\",\n         function (c) return string.format (\"%%%02X\", string.byte(c)) end)\n      str = string.gsub (str, \" \", \"+\")\n   end\n   return str    \nend\n\nlocal player_url = \"https://wyozi.github.io/gmod-medialib/mp4.html?id=%s\"\nlocal gdrive_stream_url = \"https://drive.google.com/uc?export=download&confirm=yTib&id=%s\"\nfunction GDriveService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlencode(string.format(gdrive_stream_url, urlData.id)))\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\nfunction GDriveService:directQuery(url, callback)\n\tcallback(nil, {\n\t\ttitle = url:match(\"([^/]+)$\")\n\t})\nend\n\nfunction GDriveService:hasReliablePlaybackEvents(media)\n\treturn true\nend\n\nreturn GDriveService"
medialib.FolderItems["services/mp4.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal Mp4Service = oop.class(\"Mp4Service\", \"HTMLService\")\nMp4Service.identifier = \"mp4\"\n\nlocal all_patterns = {\"^https?://.*%.mp4\"}\n\nfunction Mp4Service:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction Mp4Service:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"https://wyozi.github.io/gmod-medialib/mp4.html?id=%s\"\nfunction Mp4Service:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\nfunction Mp4Service:directQuery(url, callback)\n\tcallback(nil, {\n\t\ttitle = url:match(\"([^/]+)$\")\n\t})\nend\n\nfunction Mp4Service:hasReliablePlaybackEvents(media)\n\treturn true\nend\n\nreturn Mp4Service"
medialib.FolderItems["services/soundcloud.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal SoundcloudService = oop.class(\"SoundcloudService\", \"BASSService\")\nSoundcloudService.identifier = \"soundcloud\"\n\nlocal all_patterns = {\n\t\"^https?://www.soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?.*$\",\n\t\"^https?://soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?.*$\",\n}\n\n-- Support url that passes track id directly\nlocal id_pattern = \"^https?://api.soundcloud.com/tracks/(%d+)\"\n\nfunction SoundcloudService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal path = string.match(url, pattern)\n\t\tif path then\n\t\t\treturn {path = path}\n\t\tend\n\tend\n\n\tlocal id = string.match(url, id_pattern)\n\tif id then\n\t\treturn {id = id}\n\tend\nend\n\nfunction SoundcloudService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nfunction SoundcloudService:resolveUrl(url, callback)\n\tlocal apiKey = medialib.SOUNDCLOUD_API_KEY\n\tif not apiKey then\n\t\tErrorNoHalt(\"SoundCloud error: Missing SoundCloud API key\")\n\t\treturn\n\tend\n\n\tif type(apiKey) == \"table\" then\n\t\tapiKey = table.Random(apiKey)\n\tend\n\n\tlocal urlData = self:parseUrl(url)\n\n\tif urlData.id then\n\t\t-- id passed directly; nice, we can skip resolve.json\n\t\tcallback(string.format(\"https://api.soundcloud.com/tracks/%s/stream?client_id=%s\", urlData.id, apiKey), {})\n\telse\n\t\thttp.Fetch(\n\t\t\tstring.format(\"https://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=%s\", urlData.path, apiKey),\n\t\t\tfunction(data)\n\t\t\t\tlocal jsonTable = util.JSONToTable(data)\n\t\t\t\tif not jsonTable then\n\t\t\t\t\tErrorNoHalt(\"Failed to retrieve SC track id for \" .. urlData.path .. \": empty JSON\")\n\t\t\t\t\treturn\n\t\t\t\tend\n\n\t\t\t\tlocal id = jsonTable.id\n\t\t\t\tcallback(string.format(\"https://api.soundcloud.com/tracks/%s/stream?client_id=%s\", id, apiKey), {})\n\t\t\tend)\n\tend\nend\n\nfunction SoundcloudService:directQuery(url, callback)\n\tlocal apiKey = medialib.SOUNDCLOUD_API_KEY\n\tif not apiKey then\n\t\tcallback(\"Missing SoundCloud API key\")\n\t\treturn\n\tend\n\n\tif type(apiKey) == \"table\" then\n\t\tapiKey = table.Random(apiKey)\n\tend\n\n\tlocal urlData = self:parseUrl(url)\n\n\tlocal metaurl\n\tif urlData.path then\n\t\tmetaurl = string.format(\"https://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=%s\", urlData.path, apiKey)\n\telse\n\t\tmetaurl = string.format(\"https://api.soundcloud.com/tracks/%s?client_id=%s\", urlData.id, apiKey)\n\tend\n\n\thttp.Fetch(metaurl, function(result, size)\n\t\tif size == 0 then\n\t\t\tcallback(\"http body size = 0\")\n\t\t\treturn\n\t\tend\n\n\t\tlocal entry = util.JSONToTable(result)\n\n\t\tif entry.errors then\n\t\t\tlocal msg = entry.errors[1].error_message or \"error\"\n\n\t\t\tlocal translated = msg\n\t\t\tif string.StartWith(msg, \"404\") then\n\t\t\t\ttranslated = \"Invalid id\"\n\t\t\tend\n\n\t\t\tcallback(translated)\n\t\t\treturn\n\t\tend\n\n\t\tcallback(nil, {\n\t\t\ttitle = entry.title,\n\t\t\tduration = tonumber(entry.duration) / 1000\n\t\t})\n\tend, function(err) callback(\"HTTP: \" .. err) end)\nend\n\nreturn SoundcloudService\n"
medialib.FolderItems["services/twitch.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal TwitchService = oop.class(\"TwitchService\", \"HTMLService\")\nTwitchService.identifier = \"twitch\"\n\nlocal all_patterns = {\n\t\"https?://www.twitch.tv/([A-Za-z0-9_%-]+)\",\n\t\"https?://twitch.tv/([A-Za-z0-9_%-]+)\"\n}\n\nfunction TwitchService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction TwitchService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"https://wyozi.github.io/gmod-medialib/twitch.html?channel=%s\"\nfunction TwitchService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\nlocal CLIENT_ID = \"4cryixome326gh0x0j0fkulahsbdvx\"\n\nlocal function nameToId(name, callback)\n\thttp.Fetch(\"https://api.twitch.tv/kraken/users?login=\" .. name, function(b)\n\t\tlocal obj = util.JSONToTable(b)\n\t\tif not obj then\n\t\t\tcallback(\"malformed response JSON\")\n\t\t\treturn\n\t\tend\n\n\t\tcallback(nil, obj.users[1]._id)\n\tend, function()\n\t\tcallback(\"failed HTTP request\")\n\tend, {\n\t\tAccept = \"application/vnd.twitchtv.v5+json\",\n\t\t[\"Client-ID\"] = CLIENT_ID\n\t})\nend\n\nlocal function metaQuery(id, callback)\n\thttp.Fetch(\"https://api.twitch.tv/kraken/channels/\" .. id, function(b)\n\t\tlocal obj = util.JSONToTable(b)\n\t\tif not obj then\n\t\t\tcallback(\"malformed response JSON\")\n\t\t\treturn\n\t\tend\n\n\t\tcallback(nil, obj)\n\tend, function()\n\t\tcallback(\"failed HTTP request\")\n\tend, {\n\t\tAccept = \"application/vnd.twitchtv.v5+json\",\n\t\t[\"Client-ID\"] = CLIENT_ID\n\t})\nend\n\nfunction TwitchService:directQuery(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\n\tnameToId(urlData.id, function(err, id)\n\t\tif err then\n\t\t\tcallback(err)\n\t\t\treturn\n\t\tend\n\n\t\tmetaQuery(id, function(err, meta)\n\t\t\tif err then\n\t\t\t\tcallback(err)\n\t\t\t\treturn\n\t\t\tend\n\n\t\t\tlocal data = {}\n\t\t\tdata.id = urlData.id\n\n\t\t\tif meta.error then\n\t\t\t\tcallback(meta.message)\n\t\t\t\treturn\n\t\t\telse\n\t\t\t\tdata.title = meta.display_name .. \": \" .. meta.status\n\t\t\tend\n\n\t\t\tcallback(nil, data)\n\t\tend)\n\tend)\nend\n\nreturn TwitchService"
medialib.FolderItems["services/vimeo.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal VimeoService = oop.class(\"VimeoService\", \"HTMLService\")\nVimeoService.identifier = \"vimeo\"\n\nlocal all_patterns = {\n\t\"https?://www.vimeo.com/([0-9]+)\",\n\t\"https?://vimeo.com/([0-9]+)\",\n\t\"https?://www.vimeo.com/channels/staffpicks/([0-9]+)\",\n\t\"https?://vimeo.com/channels/staffpicks/([0-9]+)\",\n}\n\nfunction VimeoService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction VimeoService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"http://wyozi.github.io/gmod-medialib/vimeo.html?id=%s\"\nfunction VimeoService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\nfunction VimeoService:directQuery(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal metaurl = string.format(\"http://vimeo.com/api/v2/video/%s.json\", urlData.id)\n\n\thttp.Fetch(metaurl, function(result, size, headers, httpcode)\n\t\tif size == 0 then\n\t\t\tcallback(\"http body size = 0\")\n\t\t\treturn\n\t\tend\n\n\t\tif httpcode == 404 then\n\t\t\tcallback(\"Invalid id\")\n\t\t\treturn\n\t\tend\n\n\t\tlocal data = {}\n\t\tdata.id = urlData.id\n\n\t\tlocal jsontbl = util.JSONToTable(result)\n\n\t\tif jsontbl then\n\t\t\tdata.title = jsontbl[1].title\n\t\t\tdata.duration = jsontbl[1].duration\n\t\telse\n\t\t\tdata.title = \"ERROR\"\n\t\tend\n\n\t\tcallback(nil, data)\n\tend, function(err) callback(\"HTTP: \" .. err) end)\nend\n\nfunction VimeoService:hasReliablePlaybackEvents(media)\n\treturn true\nend\n\nreturn VimeoService\n"
medialib.FolderItems["services/webaudio.lua"] = "local oop = medialib.load(\"oop\")\nlocal WebAudioService = oop.class(\"WebAudioService\", \"BASSService\")\nWebAudioService.identifier = \"webaudio\"\n\nlocal all_patterns = {\n\t\"^https?://(.*)%.mp3\",\n\t\"^https?://(.*)%.ogg\",\n}\n\nfunction WebAudioService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction WebAudioService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nfunction WebAudioService:resolveUrl(url, callback)\n\tcallback(url, {})\nend\n\nfunction WebAudioService:directQuery(url, callback)\n\tcallback(nil, {\n\t\ttitle = url:match(\"([^/]+)$\")\n\t})\nend\n\nreturn WebAudioService"
medialib.FolderItems["services/webm.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal WebmService = oop.class(\"WebmService\", \"HTMLService\")\nWebmService.identifier = \"webm\"\n\nlocal all_patterns = {\"^https?://.*%.webm\"}\n\nfunction WebmService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction WebmService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"http://wyozi.github.io/gmod-medialib/webm.html?id=%s\"\nfunction WebmService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\nfunction WebmService:directQuery(url, callback)\n\tcallback(nil, {\n\t\ttitle = url:match(\"([^/]+)$\")\n\t})\nend\n\nreturn WebmService"
medialib.FolderItems["services/webradio.lua"] = "local oop = medialib.load(\"oop\")\nlocal WebRadioService = oop.class(\"WebRadioService\", \"BASSService\")\nWebRadioService.identifier = \"webradio\"\n\nlocal all_patterns = {\n\t\"^https?://(.*)%.pls\",\n\t\"^https?://(.*)%.m3u\"\n}\n\nfunction WebRadioService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction WebRadioService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nfunction WebRadioService:resolveUrl(url, callback)\n\tcallback(url, {})\nend\n\nfunction WebRadioService:directQuery(url, callback)\n\tcallback(nil, {\n\t\ttitle = url:match(\"([^/]+)$\") -- the filename is the best we can get (unless we parse pls?)\n\t})\nend\n\nreturn WebRadioService"
medialib.FolderItems["services/youtube.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal YoutubeService = oop.class(\"YoutubeService\", \"HTMLService\")\nYoutubeService.identifier = \"youtube\"\n\nlocal raw_patterns = {\n\t\"^https?://[A-Za-z0-9%.%-]*%.?youtu%.be/([A-Za-z0-9_%-]+)\",\n\t\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/watch%?.*v=([A-Za-z0-9_%-]+)\",\n\t\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/v/([A-Za-z0-9_%-]+)\",\n}\nlocal all_patterns = {}\n\n-- Appends time modifier patterns to each pattern\nfor k,p in pairs(raw_patterns) do\n\tlocal function with_sep(sep)\n\t\ttable.insert(all_patterns, p .. sep .. \"t=(%d+)m(%d+)s\")\n\t\ttable.insert(all_patterns, p .. sep .. \"t=(%d+)s?\")\n\tend\n\n\t-- We probably support more separators than youtube itself, but that does not matter\n\twith_sep(\"#\")\n\twith_sep(\"&\")\n\twith_sep(\"?\")\n\n\ttable.insert(all_patterns, p)\nend\n\nfunction YoutubeService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id, time1, time2 = string.match(url, pattern)\n\t\tif id then\n\t\t\tlocal time_sec = 0\n\t\t\tif time1 and time2 then\n\t\t\t\ttime_sec = tonumber(time1)*60 + tonumber(time2)\n\t\t\telse\n\t\t\t\ttime_sec = tonumber(time1)\n\t\t\tend\n\n\t\t\treturn {\n\t\t\t\tid = id,\n\t\t\t\tstart = time_sec\n\t\t\t}\n\t\tend\n\tend\nend\n\nfunction YoutubeService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"http://wyozi.github.io/gmod-medialib/youtube.html?id=%s\"\nfunction YoutubeService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\n-- http://en.wikipedia.org/wiki/ISO_8601#Durations\n-- Cheers wiox :))\nlocal function PTToSeconds(str)\n\tlocal h = str:match(\"(%d+)H\") or 0\n\tlocal m = str:match(\"(%d+)M\") or 0\n\tlocal s = str:match(\"(%d+)S\") or 0\n\treturn h*(60*60) + m*60 + s\nend\n\nlocal API_KEY = \"AIzaSyBmQHvMSiOTrmBKJ0FFJ2LmNtc4YHyUJaQ\"\nfunction YoutubeService:directQuery(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal metaurl = string.format(\"https://www.googleapis.com/youtube/v3/videos?part=snippet%%2CcontentDetails&id=%s&key=%s\", urlData.id, API_KEY)\n\n\thttp.Fetch(metaurl, function(result, size)\n\t\tif size == 0 then\n\t\t\tcallback(\"http body size = 0\")\n\t\t\treturn\n\t\tend\n\n\t\tlocal data = {}\n\t\tdata.id = urlData.id\n\n\t\tlocal jsontbl = util.JSONToTable(result)\n\n\t\tif jsontbl and jsontbl.items then\n\t\t\tlocal item = jsontbl.items[1]\n\t\t\tif not item then\n\t\t\t\tcallback(\"No video id found\")\n\t\t\t\treturn\n\t\t\tend\n\n\t\t\tdata.title = item.snippet.title\n\t\t\tdata.duration = tonumber(PTToSeconds(item.contentDetails.duration))\n\t\telse\n\t\t\tcallback(result)\n\t\t\treturn\n\t\tend\n\n\t\tcallback(nil, data)\n\tend, function(err) callback(\"HTTP: \" .. err) end)\nend\n\nfunction YoutubeService:hasReliablePlaybackEvents(media)\n\treturn true\nend\n\nreturn YoutubeService\n"
-- 'serviceloader'; CodeLen/MinifiedLen 533/533; Dependencies [servicebase,service_html,service_bass,media,oop]
medialib.modulePlaceholder("serviceloader")
do
medialib.load("servicebase")

medialib.load("service_html")
medialib.load("service_bass")

local media = medialib.load("media")

-- Load the actual service files
for _,file in medialib.folderIterator("services") do
	if medialib.DEBUG then
		print("[MediaLib] Registering service " .. file.name)
	end
	if SERVER then file:addcs() end
	local status, err = pcall(function() return file:load() end)
	if status then
		media.registerService(err.identifier, err)
	else
		print("[MediaLib] Failed to load service ", file, ": ", err)
	end
end
end
-- '__loader'; CodeLen/MinifiedLen 325/325; Dependencies [mediabase,media,serviceloader]
medialib.modulePlaceholder("__loader")
do
-- This file loads required modules in the correct order.
-- For development version: this file is automatically called after autorun/medialib.lua
-- For distributable:       this file is loaded after packed modules have been added to medialib

medialib.load("mediabase")
medialib.load("media")
medialib.load("serviceloader")
end
return medialib