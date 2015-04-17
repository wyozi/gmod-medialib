medialib = {}
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
}
real_file_meta.__index = real_file_meta

local virt_file_meta = {
	read = function(self)
		return self.source
	end,
	load = function(self)
		RunString(self.source)
	end,
}
virt_file_meta.__index = virt_file_meta

-- Used for medialib packed into a single file
medialib.FolderItems = {}

-- Returns an iterator for files in folder
function medialib.folderIterator(folder)
	local files = {}
	for _,fname in pairs(file.Find("medialib/" .. folder .. "/*", "LUA")) do
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
	concommand.Add("medialib_noflash", function()
		SetClipboardText("http://get.adobe.com/flashplayer/otherversions/")

		MsgN("[ MediaLib no flash guide ]")
		MsgN("1. Open this website in your browser (not the ingame Steam browser): http://get.adobe.com/flashplayer/otherversions/")
		MsgN("   (it has been automatically added to your clipboard)")
		MsgN("2. Download and install the NSAPI (for Firefox) version")
		MsgN("3. Restart your Garry's Mod")
		MsgN("[ ======================= ]")
	end)
end
-- Module oop
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
-- Module mediabase
medialib.modulePlaceholder("mediabase")
do
	local oop = medialib.load("oop")
	local Media = oop.class("Media")
	function Media:on(event, callback)
		self._events = {}
		self._events[event] = self._events[event] or {}
		self._events[event][callback] = true
	end
	function Media:emit(event, ...)
		for k,_ in pairs(self._events[event] or {}) do
			k(...)
		end
	end
	function Media:getServiceBase()
		error("Media:getServiceBase() not implemented!")
	end
	function Media:getUrl()
		return self.unresolvedUrl
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
	-- Must return one of following strings: "error", "loading", "buffering", "playing", "paused"
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
	function Media:draw(x, y, w, h) end
end
-- Module servicebase
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
	end
	function Service:load(url, opts) end
	function Service:isValidUrl(url) end
	function Service:query(url, callback) end
end
-- Module timekeeper
medialib.modulePlaceholder("timekeeper")
do
	-- The purpose of TimeKeeper is to keep time where it is not easily available, ie HTML based services
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
-- Module service_html
medialib.modulePlaceholder("service_html")
do
	local oop = medialib.load("oop")
	medialib.load("timekeeper")
	local volume3d = medialib.load("volume3d")
	local HTMLService = oop.class("HTMLService", "Service")
	function HTMLService:load(url, opts)
		local media = oop.class("HTMLMedia")()
		media.unresolvedUrl = url
		self:resolveUrl(url, function(resolvedUrl, resolvedData)
			media:openUrl(resolvedUrl)
			-- TODO move to volume3d and call as a hook
			if opts and opts.use3D then
				volume3d.startThink(media, {pos = opts.pos3D, ent = opts.ent3D, fadeMax = opts.fadeMax3D})
			end
			if resolvedData and resolvedData.start and (not opts or not opts.dontSeek) then media:seek(resolvedData.start) end
		end)
		return media
	end
	function HTMLService:resolveUrl(url, cb)
		cb(url, self:parseUrl(url))
	end
	local HTMLMedia = oop.class("HTMLMedia", "Media")
	local panel_width, panel_height = 1280, 720
	function HTMLMedia:initialize()
		self.timeKeeper = oop.class("TimeKeeper")()
		self.panel = vgui.Create("DHTML")
		local pnl = self.panel
		pnl:SetPos(0, 0)
		pnl:SetSize(panel_width, panel_height)
		local hookid = "MediaLib.HTMLMedia.FakeThink-" .. self:hashCode()
		hook.Add("Think", hookid, function()
			if not IsValid(pnl) then
				hook.Remove("Think", hookid)
				return
			end
			pnl:Think()
		end)
		local oldcm = pnl.ConsoleMessage
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
			elseif state == "paused" or state == "ended" then
				setToState = "paused"
				self.timeKeeper:pause()
			elseif state == "buffering" then
				setToState = "buffering"
				self.timeKeeper:pause()
			end
			if setToState then
				self.state = setToState
			end
		end
	end
	function HTMLMedia:getState()
		return self.state
	end
	function HTMLMedia:updateTexture()
		
	end
	function HTMLMedia:draw(x, y, w, h)
		-- Only update HTMLTexture once per frame
		if self.lastUpdatedFrame ~= FrameNumber() then
			self.panel:UpdateHTMLTexture()
			self.lastUpdatedFrame = FrameNumber()
		end
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
	function HTMLMedia:play()
		self.timeKeeper:play()
		self:runJS("medialibDelegate.run('play')")
	end
	function HTMLMedia:pause()
		self.timeKeeper:pause()
		self:runJS("medialibDelegate.run('pause')")
	end
	function HTMLMedia:stop()
		self.timeKeeper:pause()
		self.panel:Remove()
	end
	function HTMLMedia:isValid()
		return IsValid(self.panel)
	end
end
-- Module service_bass
medialib.modulePlaceholder("service_bass")
do
	local oop = medialib.load("oop")
	local volume3d = medialib.load("volume3d")
	local BASSService = oop.class("BASSService", "Service")
	function BASSService:load(url, opts)
		local media = oop.class("BASSMedia")()
		media.unresolvedUrl = url
		self:resolveUrl(url, function(resolvedUrl, resolvedData)
			if opts and opts.use3D then
				media.is3D = true
				media:runCommand(function(chan)
					-- TODO move to volume3d and call as a hook
					volume3d.startThink(media, {pos = opts.pos3D, ent = opts.ent3D, fadeMax = opts.fadeMax3D})
				end)
			end
			media:openUrl(resolvedUrl)
			if resolvedData and resolvedData.start and (not opts or not opts.dontSeek) then media:seek(resolvedData.start) end
		end)
		return media
	end
	function BASSService:resolveUrl(url, cb)
		cb(url, self:parseUrl(url))
	end
	local BASSMedia = oop.class("BASSMedia", "Media")
	function BASSMedia:initialize()
		self.commandQueue = {}
	end
	function BASSMedia:getBaseService()
		return "bass"
	end
	function BASSMedia:draw(x, y, w, h)
		surface.SetDrawColor(0, 0, 0)
		surface.DrawRect(x, y, w, h)
		local chan = self.chan
		if not IsValid(chan) then return end
		self.fftValues = self.fftValues or {}
		local valCount = chan:FFT(self.fftValues, FFT_1024)
		local valsPerX = (valCount == 0 and 1 or (w/valCount))
		local barw = w / (valCount)
		for i=1, valCount do
			surface.SetDrawColor(HSVToColor(i, 0.95, 0.5))
			local barh = self.fftValues[i]*h
			surface.DrawRect(x + i*barw, y + (h-barh), barw, barh)
		end	
	end
	function BASSMedia:openUrl(url)
		local flags = "noplay noblock"
		if self.is3D then flags = flags .. " 3d" end
		sound.PlayURL(url, flags, function(chan, errId, errName)
			self:bassCallback(chan, errId, errName)
		end)
	end
	function BASSMedia:openFile(path)
		local flags = "noplay noblock"
		if self.is3D then flags = flags .. " 3d" end
		sound.PlayFile(path, flags, function(chan, errId, errName)
			self:bassCallback(chan, errId, errName)
		end)
	end
	function BASSMedia:bassCallback(chan, errId, errName)
		if not IsValid(chan) then
			ErrorNoHalt("[MediaLib] BassMedia play failed: ", errName)
			return
		end
		self.chan = chan
		for _,c in pairs(self.commandQueue) do
			c(chan)
		end
		-- Empty queue
		self.commandQueue = {}
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
		self:runCommand(function(chan) chan:SetTime(time) end)
	end
	function BASSMedia:getTime()
		if self:isValid() then
			return self.chan:GetTime()
		end
		return 0
	end
	function BASSMedia:getState()
		if not self:isValid() then return "error" end
		local bassState = self.chan:GetState()
		if bassState == GMOD_CHANNEL_PLAYING then return "playing" end
		if bassState == GMOD_CHANNEL_PAUSED then return "paused" end
		if bassState == GMOD_CHANNEL_STALLED then return "buffering" end
		if bassState == GMOD_CHANNEL_STOPPED then return "paused" end -- umm??
		return
	end
	function BASSMedia:play()
		self:runCommand(function(chan) chan:Play() end)
	end
	function BASSMedia:pause()
		self:runCommand(function(chan) chan:Pause() end)
	end
	function BASSMedia:stop()
		self:runCommand(function(chan) chan:Stop() end)
	end
	function BASSMedia:isValid()
		return IsValid(self.chan)
	end
end
-- Module media
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
medialib.FolderItems["services/dailymotion.lua"] = "local oop = medialib.load(\"oop\")\
\
local DailyMotionService = oop.class(\"DailyMotionService\", \"HTMLService\")\
\
local all_patterns = {\
\9\"https?://www.dailymotion.com/video/([A-Za-z0-9_%-]+)\",\
\9\"https?://dailymotion.com/video/([A-Za-z0-9_%-]+)\"\
}\
\
function DailyMotionService:parseUrl(url)\
\9for _,pattern in pairs(all_patterns) do\
\9\9local id = string.match(url, pattern)\
\9\9if id then\
\9\9\9return {id = id}\
\9\9end\
\9end\
end\
\
function DailyMotionService:isValidUrl(url)\
\9return self:parseUrl(url) ~= nil\
end\
\
local player_url = \"http://wyozi.github.io/gmod-medialib/dailymotion.html?id=%s\"\
function DailyMotionService:resolveUrl(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = string.format(player_url, urlData.id)\
\
\9callback(playerUrl, {start = urlData.start})\
end\
\
-- https://api.dailymotion.com/video/x2isgrj_if-frank-underwood-was-your-coworker_fun\
function DailyMotionService:query(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local metaurl = string.format(\"https://api.dailymotion.com/video/%s?fields=duration,title\", urlData.id)\
\
\9http.Fetch(metaurl, function(result, size)\
\9\9if size == 0 then\
\9\9\9callback(\"http body size = 0\")\
\9\9\9return\
\9\9end\
\
\9\9local data = {}\
\9\9data.id = urlData.id\
\
\9\9local jsontbl = util.JSONToTable(result)\
\
\9\9if jsontbl then\
\9\9\9data.title = jsontbl.title\
\9\9\9data.duration = jsontbl.duration\
\9\9else\
\9\9\9data.title = \"ERROR\"\
\9\9end\
\
\9\9callback(nil, data)\
\9end, function(err) callback(\"HTTP: \" .. err) end)\
end\
\
medialib.load(\"media\").registerService(\"dailymotion\", DailyMotionService)"
medialib.FolderItems["services/soundcloud.lua"] = "local oop = medialib.load(\"oop\")\
\
local SoundcloudService = oop.class(\"SoundcloudService\", \"BASSService\")\
\
local all_patterns = {\
\9\"^https?://www.soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?$\",\
\9\"^https?://soundcloud.com/([A-Za-z0-9_%-]+/[A-Za-z0-9_%-]+)/?$\",\
}\
\
function SoundcloudService:parseUrl(url)\
\9for _,pattern in pairs(all_patterns) do\
\9\9local id = string.match(url, pattern)\
\9\9if id then\
\9\9\9return {id = id}\
\9\9end\
\9end\
end\
\
function SoundcloudService:isValidUrl(url)\
\9return self:parseUrl(url) ~= nil\
end\
\
function SoundcloudService:resolveUrl(url, callback)\
\9local urlData = self:parseUrl(url)\
\
\9http.Fetch(\
\9\9string.format(\"https://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=YOUR_CLIENT_ID\", urlData.id),\
\9\9function(data)\
\9\9\9local sound_id = util.JSONToTable(data).id\
\9\9\9callback(string.format(\"https://api.soundcloud.com/tracks/%s/stream?client_id=YOUR_CLIENT_ID\", sound_id), {})\
\9\9end)\
end\
\
function SoundcloudService:query(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local metaurl = string.format(\"http://api.soundcloud.com/resolve.json?url=http://soundcloud.com/%s&client_id=YOUR_CLIENT_ID\", urlData.id)\
\
\9http.Fetch(metaurl, function(result, size)\
\9\9if size == 0 then\
\9\9\9callback(\"http body size = 0\")\
\9\9\9return\
\9\9end\
\
\9\9local entry = util.JSONToTable(result)\
\
\9\9if entry.errors then\
\9\9\9local msg = entry.errors[1].error_message or \"error\"\
\9\9\9\
\9\9\9local translated = msg\
\9\9\9if string.StartWith(msg, \"404\") then\
\9\9\9\9translated = \"Invalid id\"\
\9\9\9end\
\
\9\9\9callback(translated)\
\9\9\9return\
\9\9end\
\
\9\9callback(nil, {\
\9\9\9title = entry.title,\
\9\9\9duration = tonumber(entry.duration) / 1000\
\9\9})\
\9end, function(err) callback(\"HTTP: \" .. err) end)\
end\
\
medialib.load(\"media\").registerService(\"soundcloud\", SoundcloudService)"
medialib.FolderItems["services/twitch.lua"] = "local oop = medialib.load(\"oop\")\
\
local TwitchService = oop.class(\"TwitchService\", \"HTMLService\")\
\
local all_patterns = {\
\9\"https?://www.twitch.tv/([A-Za-z0-9_%-]+)\",\
\9\"https?://twitch.tv/([A-Za-z0-9_%-]+)\"\
}\
\
function TwitchService:parseUrl(url)\
\9for _,pattern in pairs(all_patterns) do\
\9\9local id = string.match(url, pattern)\
\9\9if id then\
\9\9\9return {id = id}\
\9\9end\
\9end\
end\
\
function TwitchService:isValidUrl(url)\
\9return self:parseUrl(url) ~= nil\
end\
\
local player_url = \"http://wyozi.github.io/gmod-medialib/twitch.html?channel=%s\"\
function TwitchService:resolveUrl(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = string.format(player_url, urlData.id)\
\
\9callback(playerUrl, {start = urlData.start})\
end\
\
function TwitchService:query(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local metaurl = string.format(\"https://api.twitch.tv/kraken/channels/%s\", urlData.id)\
\
\9http.Fetch(metaurl, function(result, size)\
\9\9if size == 0 then\
\9\9\9callback(\"http body size = 0\")\
\9\9\9return\
\9\9end\
\
\9\9local data = {}\
\9\9data.id = urlData.id\
\
\9\9local jsontbl = util.JSONToTable(result)\
\
\9\9if jsontbl then\
\9\9\9if jsontbl.error then\
\9\9\9\9callback(jsontbl.message)\
\9\9\9\9return\
\9\9\9else\
\9\9\9\9data.title = jsontbl.display_name .. \": \" .. jsontbl.status\
\9\9\9end\
\9\9else\
\9\9\9data.title = \"ERROR\"\
\9\9end\
\
\9\9callback(nil, data)\
\9end, function(err) callback(\"HTTP: \" .. err) end)\
end\
\
medialib.load(\"media\").registerService(\"twitch\", TwitchService)"
medialib.FolderItems["services/ustream.lua"] = "local oop = medialib.load(\"oop\")\
\
local UstreamService = oop.class(\"UstreamService\", \"HTMLService\")\
\
local all_patterns = {\
\9\"https?://www.ustream.tv/channel/([A-Za-z0-9_%-]+)\",\
\9\"https?://ustream.tv/channel/([A-Za-z0-9_%-]+)\"\
}\
\
function UstreamService:parseUrl(url)\
\9for _,pattern in pairs(all_patterns) do\
\9\9local id = string.match(url, pattern)\
\9\9if id then\
\9\9\9return {id = id}\
\9\9end\
\9end\
end\
\
function UstreamService:isValidUrl(url)\
\9return self:parseUrl(url) ~= nil\
end\
\
local player_url = \"http://wyozi.github.io/gmod-medialib/ustream.html?id=%s\"\
function UstreamService:resolveUrl(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = string.format(player_url, urlData.id)\
\
\9-- For ustream we need to query metadata to get the embed id\
\9self:query(url, function(err, data)\
\9\9callback(string.format(player_url, data.embed_id), {start = urlData.start})\
\9end)\
end\
\
function UstreamService:query(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local metaurl = string.format(\"http://api.ustream.tv/json/channel/%s/getInfo\", urlData.id)\
\
\9http.Fetch(metaurl, function(result, size)\
\9\9if size == 0 then\
\9\9\9callback(\"http body size = 0\")\
\9\9\9return\
\9\9end\
\
\9\9local data = {}\
\9\9data.id = urlData.id\
\
\9\9local jsontbl = util.JSONToTable(result)\
\
\9\9if jsontbl then\
\9\9\9if jsontbl.error then\
\9\9\9\9callback(jsontbl.msg)\
\9\9\9\9return\
\9\9\9end\
\9\9\9data.embed_id = jsontbl.results.id\
\9\9\9data.title = jsontbl.results.title\
\9\9else\
\9\9\9data.title = \"ERROR\"\
\9\9end\
\
\9\9callback(nil, data)\
\9end, function(err) callback(\"HTTP: \" .. err) end)\
end\
\
medialib.load(\"media\").registerService(\"ustream\", UstreamService)"
medialib.FolderItems["services/vimeo.lua"] = "local oop = medialib.load(\"oop\")\
\
local VimeoService = oop.class(\"VimeoService\", \"HTMLService\")\
\
local all_patterns = {\
\9\"https?://www.vimeo.com/([0-9]+)\",\
\9\"https?://vimeo.com/([0-9]+)\"\
}\
\
function VimeoService:parseUrl(url)\
\9for _,pattern in pairs(all_patterns) do\
\9\9local id = string.match(url, pattern)\
\9\9if id then\
\9\9\9return {id = id}\
\9\9end\
\9end\
end\
\
function VimeoService:isValidUrl(url)\
\9return self:parseUrl(url) ~= nil\
end\
\
local player_url = \"http://wyozi.github.io/gmod-medialib/vimeo.html?id=%s\"\
function VimeoService:resolveUrl(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = string.format(player_url, urlData.id)\
\
\9callback(playerUrl, {start = urlData.start})\
end\
\
function VimeoService:query(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local metaurl = string.format(\"http://vimeo.com/api/v2/video/%s.json\", urlData.id)\
\
\9http.Fetch(metaurl, function(result, size, headers, httpcode)\
\9\9if size == 0 then\
\9\9\9callback(\"http body size = 0\")\
\9\9\9return\
\9\9end\
\
\9\9if httpcode == 404 then\
\9\9\9callback(\"Invalid id\")\
\9\9\9return\
\9\9end\
\
\9\9local data = {}\
\9\9data.id = urlData.id\
\
\9\9local jsontbl = util.JSONToTable(result)\
\
\9\9if jsontbl then\
\9\9\9data.title = jsontbl[1].title\
\9\9\9data.duration = jsontbl[1].duration\
\9\9else\
\9\9\9data.title = \"ERROR\"\
\9\9end\
\
\9\9callback(nil, data)\
\9end, function(err) callback(\"HTTP: \" .. err) end)\
end\
\
medialib.load(\"media\").registerService(\"vimeo\", VimeoService)"
medialib.FolderItems["services/webaudio.lua"] = "local oop = medialib.load(\"oop\")\
local WebAudioService = oop.class(\"WebAudioService\", \"BASSService\")\
\
local all_patterns = {\
\9\"^https?://(.*)%.mp3\",\
\9\"^https?://(.*)%.ogg\",\
}\
\
function WebAudioService:parseUrl(url)\
\9for _,pattern in pairs(all_patterns) do\
\9\9local id = string.match(url, pattern)\
\9\9if id then\
\9\9\9return {id = id}\
\9\9end\
\9end\
end\
\
function WebAudioService:isValidUrl(url)\
\9return self:parseUrl(url) ~= nil\
end\
\
function WebAudioService:resolveUrl(url, callback)\
\9callback(url, {})\
end\
\
local id3parser = medialib.load(\"id3parser\")\
local mp3duration = medialib.load(\"mp3duration\")\
function WebAudioService:query(url, callback)\
\9-- If it's an mp3 we can use the included ID3/MP3-duration parser to try and parse some data\
\9if string.EndsWith(url, \".mp3\") and (id3parser or mp3duration) then\
\9\9http.Fetch(url, function(data)\
\9\9\9local title, duration\
\
\9\9\9if id3parser then\
\9\9\9\9local parsed = id3parser.readtags_data(data)\
\9\9\9\9if parsed and parsed.title then\
\9\9\9\9\9title = parsed.title\
\9\9\9\9\9if parsed.artist then title = parsed.artist .. \" - \" .. title end\
\
\9\9\9\9\9-- Some soundfiles have duration as a string containing milliseconds\
\9\9\9\9\9if parsed.length then\
\9\9\9\9\9\9local length = tonumber(parsed.length)\
\9\9\9\9\9\9if length then duration = length / 1000 end\
\9\9\9\9\9end\
\9\9\9\9end\
\9\9\9end\
\
\9\9\9if mp3duration then\
\9\9\9\9duration = mp3duration.estimate_data(data) or duration\
\9\9\9end\
\
\9\9\9callback(nil, {\
\9\9\9\9title = title or url:match(\"([^/]+)$\"),\
\9\9\9\9duration = duration\
\9\9\9})\
\9\9end)\
\9\9return\
\9end\
\
\9callback(nil, {\
\9\9title = url:match(\"([^/]+)$\")\
\9})\
end\
\
medialib.load(\"media\").registerService(\"webaudio\", WebAudioService)"
medialib.FolderItems["services/webradio.lua"] = "local oop = medialib.load(\"oop\")\
local WebRadioService = oop.class(\"WebRadioService\", \"BASSService\")\
\
local all_patterns = {\
\9\"^https?://(.*)%.pls\",\
\9\"^https?://(.*)%.m3u\"\
}\
\
function WebRadioService:parseUrl(url)\
\9for _,pattern in pairs(all_patterns) do\
\9\9local id = string.match(url, pattern)\
\9\9if id then\
\9\9\9return {id = id}\
\9\9end\
\9end\
end\
\
function WebRadioService:isValidUrl(url)\
\9return self:parseUrl(url) ~= nil\
end\
\
function WebRadioService:resolveUrl(url, callback)\
\9callback(url, {})\
end\
\
function WebRadioService:query(url, callback)\
\9callback(nil, {\
\9\9title = url:match(\"([^/]+)$\") -- the filename is the best we can get (unless we parse pls?)\
\9})\
end\
\
medialib.load(\"media\").registerService(\"webradio\", WebRadioService)"
medialib.FolderItems["services/youtube.lua"] = "local oop = medialib.load(\"oop\")\
\
local YoutubeService = oop.class(\"YoutubeService\", \"HTMLService\")\
\
local raw_patterns = {\
\9\"^https?://[A-Za-z0-9%.%-]*%.?youtu%.be/([A-Za-z0-9_%-]+)\",\
\9\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/watch%?.*v=([A-Za-z0-9_%-]+)\",\
\9\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/v/([A-Za-z0-9_%-]+)\",\
}\
local all_patterns = {}\
\
-- Appends time modifier patterns to each pattern\
for k,p in pairs(raw_patterns) do\
\9local function with_sep(sep)\
\9\9table.insert(all_patterns, p .. sep .. \"t=(%d+)m(%d+)s\")\
\9\9table.insert(all_patterns, p .. sep .. \"t=(%d+)s?\")\
\9end\
\
\9-- We probably support more separators than youtube itself, but that does not matter\
\9with_sep(\"#\")\
\9with_sep(\"&\")\
\9with_sep(\"?\")\
\
\9table.insert(all_patterns, p)\
end\
\
function YoutubeService:parseUrl(url)\
\9for _,pattern in pairs(all_patterns) do\
\9\9local id, time1, time2 = string.match(url, pattern)\
\9\9if id then\
\9\9\9local time_sec = 0\
\9\9\9if time1 and time2 then\
\9\9\9\9time_sec = tonumber(time1)*60 + tonumber(time2)\
\9\9\9else\
\9\9\9\9time_sec = tonumber(time1)\
\9\9\9end\
\
\9\9\9return {\
\9\9\9\9id = id,\
\9\9\9\9start = time_sec\
\9\9\9}\
\9\9end\
\9end\
end\
\
function YoutubeService:isValidUrl(url)\
\9return self:parseUrl(url) ~= nil\
end\
\
local player_url = \"http://wyozi.github.io/gmod-medialib/youtube.html?id=%s\"\
function YoutubeService:resolveUrl(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = string.format(player_url, urlData.id)\
\
\9callback(playerUrl, {start = urlData.start})\
end\
\
function YoutubeService:query(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local metaurl = string.format(\"http://gdata.youtube.com/feeds/api/videos/%s?alt=json\", urlData.id)\
\
\9http.Fetch(metaurl, function(result, size)\
\9\9if size == 0 then\
\9\9\9callback(\"http body size = 0\")\
\9\9\9return\
\9\9end\
\
\9\9local data = {}\
\9\9data.id = urlData.id\
\
\9\9local jsontbl = util.JSONToTable(result)\
\
\9\9if jsontbl and jsontbl.entry then\
\9\9\9local entry = jsontbl.entry\
\9\9\9data.title = entry[\"title\"][\"$t\"]\
\9\9\9data.duration = tonumber(entry[\"media$group\"][\"yt$duration\"][\"seconds\"])\
\9\9else\
\9\9\9callback(result)\
\9\9\9return\
\9\9end\
\
\9\9callback(nil, data)\
\9end, function(err) callback(\"HTTP: \" .. err) end)\
end\
\
medialib.load(\"media\").registerService(\"youtube\", YoutubeService)"
-- Module serviceloader
medialib.modulePlaceholder("serviceloader")
do
	medialib.load("servicebase")
	medialib.load("service_html")
	medialib.load("service_bass")
	-- AddCSLuaFile all services
	if SERVER then
		for _,fname in pairs(file.Find("medialib/services/*", "LUA")) do
			AddCSLuaFile("medialib/services/" .. fname)
		end
	end
	-- Load the actual service files
	for _,file in medialib.folderIterator("services") do
		if medialib.DEBUG then
			print("[MediaLib] Registering service " .. file.name)
		end
		file:load()
	end
end
-- Module __loader
medialib.modulePlaceholder("__loader")
do
	-- This file loads all the requires modules.
	-- It is in different file than medialib.lua for medialib build purposes
	medialib.load("mediabase")
	medialib.load("serviceloader")
	medialib.load("media")
end