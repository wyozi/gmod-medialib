do
-- Note: build file expects these exact lines for them to be automatically replaced, so please don't change anything
local VERSION = "git@1f44f84b"
local DISTRIBUTABLE = true

-- Check if medialib has already been defined
if medialib and medialib.VERSION ~= VERSION then
	-- Overwrite only if we're using dev version
	local shouldOverwrite = VERSION == "local"

	print("[MediaLib] Warning: " .. (shouldOverwrite and "overwriting" or "found") .. " existing medialib. (local: " .. VERSION .. ", defined: " .. (medialib.VERSION or "-") .. ")")

	if not shouldOverwrite then return end
end

medialib = {}

medialib.VERSION = VERSION
medialib.DISTRIBUTABLE = DISTRIBUTABLE

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
		RunStringEx(self.source, self.name or "unknown virtual file")
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
-- 'mediabase'; CodeLen/MinifiedLen 3619/3619; Dependencies [oop]
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

end
-- 'servicebase'; CodeLen/MinifiedLen 759/759; Dependencies [oop]
medialib.modulePlaceholder("servicebase")
do
local oop = medialib.load("oop")

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
function Service:isValidUrl(url) end
function Service:query(url, callback) end

function Service:parseUrl(url) end

-- the second argument to cb() function call has some standard keys:
--   `start` the time at which to start media in seconds
function Service:resolveUrl(url, cb)
	cb(url, self:parseUrl(url))
end

end
-- 'mediaregistry'; CodeLen/MinifiedLen 287/287; Dependencies []
medialib.modulePlaceholder("mediaregistry")
do
local mediaregistry = medialib.module("mediaregistry")

local cache = setmetatable({}, {__mode = "v"})

function mediaregistry.add(media)
	table.insert(cache, media)
end

concommand.Add("medialib_stopall", function()
	for _,v in pairs(cache) do
		v:stop()
	end

	table.Empty(cache)
end)

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
-- 'service_html'; CodeLen/MinifiedLen 6139/6139; Dependencies [oop,mediaregistry,timekeeper]
medialib.modulePlaceholder("service_html")
do
local oop = medialib.load("oop")
local mediaregistry = medialib.load("mediaregistry")
medialib.load("timekeeper")

local HTMLService = oop.class("HTMLService", "Service")
function HTMLService:load(url, opts)
	local media = oop.class("HTMLMedia")()
	media._unresolvedUrl = url
	media._service = self

	hook.Run("Medialib_ProcessOpts", media, opts or {})

	mediaregistry.add(media)

	self:resolveUrl(url, function(resolvedUrl, resolvedData)
		media:openUrl(resolvedUrl)

		if resolvedData and resolvedData.start and (not opts or not opts.dontSeek) then media:seek(resolvedData.start) end
	end)

	return media
end

-- Whether or not we can trust that the HTML panel will send 'playing', 'paused'
-- and other playback related events. If this returns true, 'timekeeper' will
-- not be updated in playback related methods (except stop).
function HTMLService:hasReliablePlaybackEvents(media)
	return false
end

local AwesomiumPool = {instances = {}}
concommand.Add("medialib_awepoolinfo", function()
	print("AwesomiumPool> Free instance count: " .. #AwesomiumPool.instances)
end)
-- If there's bunch of awesomium instances in pool, we clean one up every 30 seconds
timer.Create("MediaLib.AwesomiumPoolCleaner", 30, 0, function()
	if #AwesomiumPool.instances < 3 then return end

	local inst = table.remove(AwesomiumPool.instances, 1)
	if IsValid(inst) then inst:Remove() end
end)
function AwesomiumPool.get()
	local inst = table.remove(AwesomiumPool.instances, 1)
	if not IsValid(inst) then
		local pnl = vgui.Create("DHTML")
		return pnl
	end
	return inst
end
function AwesomiumPool.free(inst)
	if not IsValid(inst) then return end
	inst:SetHTML("")

	table.insert(AwesomiumPool.instances, inst)
end

local HTMLMedia = oop.class("HTMLMedia", "Media")

local panel_width, panel_height = 1280, 720
function HTMLMedia:initialize()
	self.timeKeeper = oop.class("TimeKeeper")()

	self.panel = AwesomiumPool.get()

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
		-- Filter some things out
		if string.find(msg, "XMLHttpRequest") then return end
		if string.find(msg, "Unsafe JavaScript attempt to access") then return end

		return oldcm(pself, msg)
	end

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

function HTMLMedia:updateTexture()
	-- Only update HTMLTexture once per frame
	if self.lastUpdatedFrame ~= FrameNumber() then
		self.panel:UpdateHTMLTexture()
		self.lastUpdatedFrame = FrameNumber()
	end
end

function HTMLMedia:draw(x, y, w, h)
	self:updateTexture()

	local mat = self.panel:GetHTMLMaterial()

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

function HTMLMedia:seek(time)
	self:runJS("medialibDelegate.run('seek', {time: %d})", time)
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
	AwesomiumPool.free(self.panel)
	self.panel = nil

	self.timeKeeper:pause()
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
-- 'service_bass'; CodeLen/MinifiedLen 4683/4683; Dependencies [oop,mediaregistry]
medialib.modulePlaceholder("service_bass")
do
local oop = medialib.load("oop")
local mediaregistry = medialib.load("mediaregistry")

local BASSService = oop.class("BASSService", "Service")
function BASSService:load(url, opts)
	local media = oop.class("BASSMedia")()
	media._unresolvedUrl = url
	media._service = self

	hook.Run("Medialib_ProcessOpts", media, opts or {})

	mediaregistry.add(media)

	self:resolveUrl(url, function(resolvedUrl, resolvedData)
		media:openUrl(resolvedUrl)

		if resolvedData and resolvedData.start and (not opts or not opts.dontSeek) then media:seek(resolvedData.start) end
	end)

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
	local flags = table.concat(self.bassPlayOptions, " ")

	sound.PlayURL(url, flags, function(chan, errId, errName)
		self:bassCallback(chan, errId, errName)
	end)
end
function BASSMedia:openFile(path)
	local flags = table.concat(self.bassPlayOptions, " ")

	sound.PlayFile(path, flags, function(chan, errId, errName)
		self:bassCallback(chan, errId, errName)
	end)
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
	local timerId = "MediaLib_BASS_EndChecker_" .. self:hashCode()
	timer.Create(timerId, 1, 0, function()
		if IsValid(self.chan) and self.chan:GetState() == GMOD_CHANNEL_STOPPED then
			self:emit("ended")
			timer.Destroy(timerId)
		end
	end)
end

function BASSMedia:runCommand(fn)
	if IsValid(self.chan) then
		fn(self.chan)
	else
		self.commandQueue[#self.commandQueue+1] = fn
	end
end

function BASSMedia:setVolume(vol)
	self:runCommand(function(chan) chan:SetVolume(vol) end)
end

function BASSMedia:seek(time)
	self:runCommand(function(chan)
		if chan:IsBlockStreamed() then return end

		self._seekingTo = time

		local timerId = "MediaLib_BASSMedia_Seeker_" .. time .. "_" .. self:hashCode()
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
			if math.abs(chan:GetTime() - time) < 1 then
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
	self:runCommand(function(chan) chan:Play() self:emit("playing") end)
end
function BASSMedia:pause()
	self:runCommand(function(chan) chan:Pause() self:emit("paused") end)
end
function BASSMedia:stop()
	self._stopped = true
	self:runCommand(function(chan) chan:Stop() self:emit("ended") self:emit("destroyed") end)
end

function BASSMedia:isValid()
	return not self._stopped
end

end
-- 'media'; CodeLen/MinifiedLen 485/485; Dependencies []
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

function media.guessService(url)
	for _,service in pairs(media.Services) do
		if service:isValidUrl(url) then
			return service
		end
	end
end
media.GuessService = media.guessService -- alias
end
medialib.FolderItems["services/mp4.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal Mp4Service = oop.class(\"Mp4Service\", \"HTMLService\")\n\nlocal all_patterns = {\"^https?://.*%.mp4\"}\n\nfunction Mp4Service:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction Mp4Service:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"http://wyozi.github.io/gmod-medialib/mp4.html?id=%s\"\nfunction Mp4Service:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\nfunction Mp4Service:query(url, callback)\n\tcallback(nil, {\n\t\ttitle = url:match(\"([^/]+)$\")\n\t})\nend\n\nmedialib.load(\"media\").registerService(\"mp4\", Mp4Service)"
medialib.FolderItems["services/soundcloud.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal SoundcloudService = oop.class(\"SoundcloudService\", \"BASSService\")\n\nlocal all_patterns = {\n\t\"^https?://www.soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?$\",\n\t\"^https?://soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?$\",\n}\n\nfunction SoundcloudService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction SoundcloudService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nfunction SoundcloudService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\n\thttp.Fetch(\n\t\tstring.format(\"https://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=YOUR_CLIENT_ID\", urlData.id),\n\t\tfunction(data)\n\t\t\tlocal sound_id = util.JSONToTable(data).id\n\t\t\tcallback(string.format(\"https://api.soundcloud.com/tracks/%s/stream?client_id=YOUR_CLIENT_ID\", sound_id), {})\n\t\tend)\nend\n\nfunction SoundcloudService:query(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal metaurl = string.format(\"http://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=YOUR_CLIENT_ID\", urlData.id)\n\n\thttp.Fetch(metaurl, function(result, size)\n\t\tif size == 0 then\n\t\t\tcallback(\"http body size = 0\")\n\t\t\treturn\n\t\tend\n\n\t\tlocal entry = util.JSONToTable(result)\n\n\t\tif entry.errors then\n\t\t\tlocal msg = entry.errors[1].error_message or \"error\"\n\t\t\t\n\t\t\tlocal translated = msg\n\t\t\tif string.StartWith(msg, \"404\") then\n\t\t\t\ttranslated = \"Invalid id\"\n\t\t\tend\n\n\t\t\tcallback(translated)\n\t\t\treturn\n\t\tend\n\n\t\tcallback(nil, {\n\t\t\ttitle = entry.title,\n\t\t\tduration = tonumber(entry.duration) / 1000\n\t\t})\n\tend, function(err) callback(\"HTTP: \" .. err) end)\nend\n\nmedialib.load(\"media\").registerService(\"soundcloud\", SoundcloudService)"
medialib.FolderItems["services/twitch.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal TwitchService = oop.class(\"TwitchService\", \"HTMLService\")\n\nlocal all_patterns = {\n\t\"https?://www.twitch.tv/([A-Za-z0-9_%-]+)\",\n\t\"https?://twitch.tv/([A-Za-z0-9_%-]+)\"\n}\n\nfunction TwitchService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction TwitchService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"http://wyozi.github.io/gmod-medialib/twitch.html?channel=%s\"\nfunction TwitchService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\nfunction TwitchService:query(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal metaurl = string.format(\"https://api.twitch.tv/kraken/channels/%s\", urlData.id)\n\n\thttp.Fetch(metaurl, function(result, size)\n\t\tif size == 0 then\n\t\t\tcallback(\"http body size = 0\")\n\t\t\treturn\n\t\tend\n\n\t\tlocal data = {}\n\t\tdata.id = urlData.id\n\n\t\tlocal jsontbl = util.JSONToTable(result)\n\n\t\tif jsontbl then\n\t\t\tif jsontbl.error then\n\t\t\t\tcallback(jsontbl.message)\n\t\t\t\treturn\n\t\t\telse\n\t\t\t\tdata.title = jsontbl.display_name .. \": \" .. jsontbl.status\n\t\t\tend\n\t\telse\n\t\t\tdata.title = \"ERROR\"\n\t\tend\n\n\t\tcallback(nil, data)\n\tend, function(err) callback(\"HTTP: \" .. err) end)\nend\n\nmedialib.load(\"media\").registerService(\"twitch\", TwitchService)"
medialib.FolderItems["services/vimeo.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal VimeoService = oop.class(\"VimeoService\", \"HTMLService\")\n\nlocal all_patterns = {\n\t\"https?://www.vimeo.com/([0-9]+)\",\n\t\"https?://vimeo.com/([0-9]+)\",\n\t\"https?://www.vimeo.com/channels/staffpicks/([0-9]+)\",\n\t\"https?://vimeo.com/channels/staffpicks/([0-9]+)\",\n}\n\nfunction VimeoService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction VimeoService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"http://wyozi.github.io/gmod-medialib/vimeo.html?id=%s\"\nfunction VimeoService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\nfunction VimeoService:query(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal metaurl = string.format(\"http://vimeo.com/api/v2/video/%s.json\", urlData.id)\n\n\thttp.Fetch(metaurl, function(result, size, headers, httpcode)\n\t\tif size == 0 then\n\t\t\tcallback(\"http body size = 0\")\n\t\t\treturn\n\t\tend\n\n\t\tif httpcode == 404 then\n\t\t\tcallback(\"Invalid id\")\n\t\t\treturn\n\t\tend\n\n\t\tlocal data = {}\n\t\tdata.id = urlData.id\n\n\t\tlocal jsontbl = util.JSONToTable(result)\n\n\t\tif jsontbl then\n\t\t\tdata.title = jsontbl[1].title\n\t\t\tdata.duration = jsontbl[1].duration\n\t\telse\n\t\t\tdata.title = \"ERROR\"\n\t\tend\n\n\t\tcallback(nil, data)\n\tend, function(err) callback(\"HTTP: \" .. err) end)\nend\n\nfunction VimeoService:hasReliablePlaybackEvents(media)\n\treturn true\nend\n\nmedialib.load(\"media\").registerService(\"vimeo\", VimeoService)"
medialib.FolderItems["services/webaudio.lua"] = "local oop = medialib.load(\"oop\")\nlocal WebAudioService = oop.class(\"WebAudioService\", \"BASSService\")\n\nlocal all_patterns = {\n\t\"^https?://(.*)%.mp3\",\n\t\"^https?://(.*)%.ogg\",\n}\n\nfunction WebAudioService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction WebAudioService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nfunction WebAudioService:resolveUrl(url, callback)\n\tcallback(url, {})\nend\n\nlocal id3parser = medialib.load(\"id3parser\")\nlocal mp3duration = medialib.load(\"mp3duration\")\nfunction WebAudioService:query(url, callback)\n\t-- If it's an mp3 we can use the included ID3/MP3-duration parser to try and parse some data\n\tif string.EndsWith(url, \".mp3\") and (id3parser or mp3duration) then\n\t\thttp.Fetch(url, function(data)\n\t\t\tlocal title, duration\n\n\t\t\tif id3parser then\n\t\t\t\tlocal parsed = id3parser.readtags_data(data)\n\t\t\t\tif parsed and parsed.title then\n\t\t\t\t\ttitle = parsed.title\n\t\t\t\t\tif parsed.artist then title = parsed.artist .. \" - \" .. title end\n\n\t\t\t\t\t-- Some soundfiles have duration as a string containing milliseconds\n\t\t\t\t\tif parsed.length then\n\t\t\t\t\t\tlocal length = tonumber(parsed.length)\n\t\t\t\t\t\tif length then duration = length / 1000 end\n\t\t\t\t\tend\n\t\t\t\tend\n\t\t\tend\n\n\t\t\tif mp3duration then\n\t\t\t\tduration = mp3duration.estimate_data(data) or duration\n\t\t\tend\n\n\t\t\tcallback(nil, {\n\t\t\t\ttitle = title or url:match(\"([^/]+)$\"),\n\t\t\t\tduration = duration\n\t\t\t})\n\t\tend, function(err)\n\t\t\tcallback(\"Metadata fetch error: \" .. tostring(err))\n\t\tend)\n\t\treturn\n\tend\n\n\tcallback(nil, {\n\t\ttitle = url:match(\"([^/]+)$\")\n\t})\nend\n\nmedialib.load(\"media\").registerService(\"webaudio\", WebAudioService)\n"
medialib.FolderItems["services/webm.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal WebmService = oop.class(\"WebmService\", \"HTMLService\")\n\nlocal all_patterns = {\"^https?://.*%.webm\"}\n\nfunction WebmService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction WebmService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"http://wyozi.github.io/gmod-medialib/webm.html?id=%s\"\nfunction WebmService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\nfunction WebmService:query(url, callback)\n\tcallback(nil, {\n\t\ttitle = url:match(\"([^/]+)$\")\n\t})\nend\n\nmedialib.load(\"media\").registerService(\"webm\", WebmService)"
medialib.FolderItems["services/webradio.lua"] = "local oop = medialib.load(\"oop\")\nlocal WebRadioService = oop.class(\"WebRadioService\", \"BASSService\")\n\nlocal all_patterns = {\n\t\"^https?://(.*)%.pls\",\n\t\"^https?://(.*)%.m3u\"\n}\n\nfunction WebRadioService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id = string.match(url, pattern)\n\t\tif id then\n\t\t\treturn {id = id}\n\t\tend\n\tend\nend\n\nfunction WebRadioService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nfunction WebRadioService:resolveUrl(url, callback)\n\tcallback(url, {})\nend\n\nlocal shoutcastmeta = medialib.load(\"shoutcastmeta\")\nfunction WebRadioService:query(url, callback)\n\tlocal function EmitBasicMeta()\n\t\tcallback(nil, {\n\t\t\ttitle = url:match(\"([^/]+)$\") -- the filename is the best we can get (unless we parse pls?)\n\t\t})\n\tend\n\n\t-- Use shoutcastmeta extension if available\n\tif shoutcastmeta then\n\t\tshoutcastmeta.fetch(url, function(err, data)\n\t\t\tif err then\n\t\t\t\tEmitBasicMeta()\n\t\t\t\treturn\n\t\t\tend\n\n\t\t\tcallback(nil, data)\n\t\tend)\n\t\treturn\n\tend\n\n\tEmitBasicMeta()\t\nend\n\nmedialib.load(\"media\").registerService(\"webradio\", WebRadioService)"
medialib.FolderItems["services/youtube.lua"] = "local oop = medialib.load(\"oop\")\n\nlocal YoutubeService = oop.class(\"YoutubeService\", \"HTMLService\")\n\nlocal raw_patterns = {\n\t\"^https?://[A-Za-z0-9%.%-]*%.?youtu%.be/([A-Za-z0-9_%-]+)\",\n\t\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/watch%?.*v=([A-Za-z0-9_%-]+)\",\n\t\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/v/([A-Za-z0-9_%-]+)\",\n}\nlocal all_patterns = {}\n\n-- Appends time modifier patterns to each pattern\nfor k,p in pairs(raw_patterns) do\n\tlocal function with_sep(sep)\n\t\ttable.insert(all_patterns, p .. sep .. \"t=(%d+)m(%d+)s\")\n\t\ttable.insert(all_patterns, p .. sep .. \"t=(%d+)s?\")\n\tend\n\n\t-- We probably support more separators than youtube itself, but that does not matter\n\twith_sep(\"#\")\n\twith_sep(\"&\")\n\twith_sep(\"?\")\n\n\ttable.insert(all_patterns, p)\nend\n\nfunction YoutubeService:parseUrl(url)\n\tfor _,pattern in pairs(all_patterns) do\n\t\tlocal id, time1, time2 = string.match(url, pattern)\n\t\tif id then\n\t\t\tlocal time_sec = 0\n\t\t\tif time1 and time2 then\n\t\t\t\ttime_sec = tonumber(time1)*60 + tonumber(time2)\n\t\t\telse\n\t\t\t\ttime_sec = tonumber(time1)\n\t\t\tend\n\n\t\t\treturn {\n\t\t\t\tid = id,\n\t\t\t\tstart = time_sec\n\t\t\t}\n\t\tend\n\tend\nend\n\nfunction YoutubeService:isValidUrl(url)\n\treturn self:parseUrl(url) ~= nil\nend\n\nlocal player_url = \"http://wyozi.github.io/gmod-medialib/youtube.html?id=%s\"\nfunction YoutubeService:resolveUrl(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal playerUrl = string.format(player_url, urlData.id)\n\n\tcallback(playerUrl, {start = urlData.start})\nend\n\n-- http://en.wikipedia.org/wiki/ISO_8601#Durations\n-- Cheers wiox :))\nlocal function PTToSeconds(str)\n\tlocal h = str:match(\"(%d+)H\") or 0\n\tlocal m = str:match(\"(%d+)M\") or 0\n\tlocal s = str:match(\"(%d+)S\") or 0\n\treturn h*(60*60) + m*60 + s\nend\n\nlocal API_KEY = \"AIzaSyBmQHvMSiOTrmBKJ0FFJ2LmNtc4YHyUJaQ\"\nfunction YoutubeService:query(url, callback)\n\tlocal urlData = self:parseUrl(url)\n\tlocal metaurl = string.format(\"https://www.googleapis.com/youtube/v3/videos?part=snippet%%2CcontentDetails&id=%s&key=%s\", urlData.id, API_KEY)\n\n\thttp.Fetch(metaurl, function(result, size)\n\t\tif size == 0 then\n\t\t\tcallback(\"http body size = 0\")\n\t\t\treturn\n\t\tend\n\n\t\tlocal data = {}\n\t\tdata.id = urlData.id\n\n\t\tlocal jsontbl = util.JSONToTable(result)\n\n\t\tif jsontbl and jsontbl.items then\n\t\t\tlocal item = jsontbl.items[1]\n\t\t\tif not item then\n\t\t\t\tcallback(\"No video id found\")\n\t\t\t\treturn\n\t\t\tend\n\n\t\t\tdata.title = item.snippet.title\n\t\t\tdata.duration = tonumber(PTToSeconds(item.contentDetails.duration))\n\t\telse\n\t\t\tcallback(result)\n\t\t\treturn\n\t\tend\n\n\t\tcallback(nil, data)\n\tend, function(err) callback(\"HTTP: \" .. err) end)\nend\n\nfunction YoutubeService:hasReliablePlaybackEvents(media)\n\treturn true\nend\n\nmedialib.load(\"media\").registerService(\"youtube\", YoutubeService)"
-- 'serviceloader'; CodeLen/MinifiedLen 311/311; Dependencies [servicebase,service_html,service_bass,oop,media,id3parser,mp3duration,shoutcastmeta]
medialib.modulePlaceholder("serviceloader")
do
medialib.load("servicebase")

medialib.load("service_html")
medialib.load("service_bass")

-- Load the actual service files
for _,file in medialib.folderIterator("services") do
	if medialib.DEBUG then
		print("[MediaLib] Registering service " .. file.name)
	end
	if SERVER then file:addcs() end
	file:load()
end
end
-- '__loader'; CodeLen/MinifiedLen 326/326; Dependencies [mediabase,serviceloader,media]
medialib.modulePlaceholder("__loader")
do
-- This file loads required modules in the correct order.
-- For development version: this file is automatically called after autorun/medialib.lua
-- For distributable:       this file is loaded after packed modules have been added to medialib

medialib.load("mediabase")
medialib.load("serviceloader")

medialib.load("media")
end