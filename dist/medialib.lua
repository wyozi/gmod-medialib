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
	-- vol must be a float between 0 and 1
	function Media:setVolume(vol) end
	function Media:getVolume() end
	-- "Quality" must be one of following strings: "low", "medium", "high", "veryhigh"
	-- Qualities do not map equally between services (ie "low" in youtube might be "medium" in twitch)
	-- Not all qualities are guaranteed to exist on all services, in which case the quality is rounded down
	function Media:setQuality(quality) end
	-- time must be an integer between 0 and duration
	function Media:seek(time) end
	function Media:getTime() end
	function Media:getDuration() end
	function Media:getFraction()
		local time = self:getTime()
		local dur = self:getDuration()
		if not time or not dur then return end
		return time / dur
	end
	function Media:isStream()
		return not self:getDuration()
	end
	-- Must return one of following strings: "error", "loading", "buffering", "playing", "paused"
	function Media:getState() end
	function Media:getLoadedFraction() end
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
	function Service:load(url) end
	function Service:isValidUrl(url) end
	function Service:query(url, callback) end
end
-- Module service_html
medialib.modulePlaceholder("service_html")
do
	local oop = medialib.load("oop")
	local HTMLService = oop.class("HTMLService", "Service")
	local HTMLMedia = oop.class("HTMLMedia", "Media")
	local panel_width, panel_height = 1920, 1080
	function HTMLMedia:initialize()
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
	function HTMLMedia:openUrl(url)
		self.panel:OpenURL(url)
		self.URLChanged = CurTime()
	end
	function HTMLMedia:runJS(js, ...)
		local code = string.format(js, ...)
		self.panel:QueueJavascript(code)
	end
	function HTMLMedia:handleHTMLEvent(id, event)
	end
	function HTMLMedia:draw(x, y, w, h)
		self.panel:UpdateHTMLTexture()
		local mat = self.panel:GetHTMLMaterial()
		surface.SetMaterial(mat)
		surface.SetDrawColor(255, 255, 255)
		local w_frac, h_frac = panel_width / mat:Width(), panel_height / mat:Height()
		surface.DrawTexturedRectUV(0, 0, w or panel_width, h or panel_height, 0, 0, w_frac, h_frac)
	end
	function HTMLMedia:setQuality(qual)
		self:runJS("medialibDelegate.run('setQuality', {quality: %q})", qual)
	end
	function HTMLMedia:setVolume(vol)
		self:runJS("medialibDelegate.run('setVolume', {vol: %f})", vol)
	end
	function HTMLMedia:seek(time)
		self:runJS("medialibDelegate.run('seek', {time: %d})", time)
	end
	function HTMLMedia:play()
		self:runJS("medialibDelegate.run('play')")
	end
	function HTMLMedia:pause()
		self:runJS("medialibDelegate.run('pause')")
	end
	function HTMLMedia:stop()
		self.panel:Remove()
	end
end
-- Module service_bass
medialib.modulePlaceholder("service_bass")
do
	local oop = medialib.load("oop")
	local BASSService = oop.class("BASSService", "Service")
	local BASSMedia = oop.class("BASSMedia", "Media")
	function BASSMedia:initialize()
		self.commandQueue = {}
	end
	function BASSMedia:openUrl(url)
		sound.PlayURL(url, "noplay noblock", function(chan, errId, errName)
			self:bassCallback(chan, errId, errName)
		end)
	end
	function BASSMedia:openFile(path)
		sound.PlayFile(path, "noplay noblock", function(chan, errId, errName)
			self:bassCallback(chan, errId, errName)
		end)
	end
	function BASSMedia:bassCallback(chan, errId, errName)
		if not IsValid(chan) then
			print("BassMedia play failed: ", errName)
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
	function BASSMedia:play()
		self:runCommand(function(chan) chan:Play() end)
	end
	function BASSMedia:pause()
		self:runCommand(function(chan) chan:Pause() end)
	end
	function BASSMedia:stop()
		self:runCommand(function(chan) chan:Stop() end)
	end
end
-- Module media
medialib.modulePlaceholder("media")
do
	local media = medialib.module("media")
	media.Services = {}
	function media.RegisterService(name, cls)
		media.Services[name] = cls()
	end
	function media.Service(name)
		return media.Services[name]
	end
	function media.GuessService(url)
		for _,service in pairs(media.Services) do
			if service:isValidUrl(url) then
				return service
			end
		end
	end
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
function DailyMotionService:load(url)\
\9local media = oop.class(\"HTMLMedia\")()\
\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = string.format(player_url, urlData.id)\
\
\9media:openUrl(playerUrl)\
\
\9return media\
end\
-- https://api.dailymotion.com/video/x2isgrj_if-frank-underwood-was-your-coworker_fun\
function DailyMotionService:query(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local metaurl = string.format(\"http://api.dailymotion.com/video/%s\", urlData.id)\
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
\9\9else\
\9\9\9data.title = \"ERROR\"\
\9\9end\
\
\9\9callback(nil, data)\
\9end)\
end\
\
medialib.load(\"media\").RegisterService(\"dailymotion\", DailyMotionService)"
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
function TwitchService:load(url)\
\9local media = oop.class(\"HTMLMedia\")()\
\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = string.format(player_url, urlData.id)\
\
\9media:openUrl(playerUrl)\
\
\9return media\
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
\9\9\9data.title = jsontbl.display_name .. \": \" .. jsontbl.status\
\9\9else\
\9\9\9data.title = \"ERROR\"\
\9\9end\
\
\9\9callback(nil, data)\
\9end)\
end\
\
medialib.load(\"media\").RegisterService(\"twitch\", TwitchService)"
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
function UstreamService:load(url)\
\9local media = oop.class(\"HTMLMedia\")()\
\
\9-- For ustream we need to query metadata to get the embed id\
\9self:query(url, function(err, data)\
\9\9media:openUrl(string.format(player_url, data.embed_id))\
\9end)\
\
\9return media\
end\
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
\9\9\9data.embed_id = jsontbl.results.id\
\9\9\9data.title = jsontbl.results.title\
\9\9else\
\9\9\9data.title = \"ERROR\"\
\9\9end\
\
\9\9callback(nil, data)\
\9end)\
end\
\
medialib.load(\"media\").RegisterService(\"ustream\", UstreamService)"
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
function VimeoService:load(url)\
\9local media = oop.class(\"HTMLMedia\")()\
\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = string.format(player_url, urlData.id)\
\
\9media:openUrl(playerUrl)\
\
\9return media\
end\
\
function VimeoService:query(url, callback)\
\9local urlData = self:parseUrl(url)\
\9local metaurl = string.format(\"http://vimeo.com/api/v2/video/%s.json\", urlData.id)\
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
\9\9\9data.title = jsontbl[1].title\
\9\9\9data.duration = jsontbl[1].duration\
\9\9else\
\9\9\9data.title = \"ERROR\"\
\9\9end\
\
\9\9callback(nil, data)\
\9end)\
end\
\
medialib.load(\"media\").RegisterService(\"vimeo\", VimeoService)"
medialib.FolderItems["services/webradio.lua"] = "local oop = medialib.load(\"oop\")\
local WebRadioService = oop.class(\"WebRadioService\", \"BASSService\")\
\
local all_patterns = {\
\9\"^https?://(.*)%.pls\"\
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
function WebRadioService:load(url)\
\9local media = oop.class(\"BASSMedia\")()\
\
\9media:openUrl(url)\
\
\9return media\
end\
\
function WebRadioService:query(url, callback)\
\9callback(nil, {\
\9\9title = url:match(\"([^/]+)$\") -- the filename is the best we can get (unless we parse pls?)\
\9})\
end\
\
medialib.load(\"media\").RegisterService(\"webradio\", WebRadioService)"
medialib.FolderItems["services/youtube.lua"] = "local oop = medialib.load(\"oop\")\
\
local YoutubeService = oop.class(\"YoutubeService\", \"HTMLService\")\
\
local raw_patterns = {\
\9\"^https?://[A-Za-z0-9%.%-]*%.?youtu%.be/([A-Za-z0-9_%-]+)\",\
\9\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/watch%?.*v=([A-Za-z0-9_%-]+)\",\
\9\"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/v/([A-Za-z0-9_%-]+)\",\
}\
\
local all_patterns = {}\
\
-- Appends time modifier patterns to each pattern\
for k,p in pairs(raw_patterns) do\
\9local hash_letter = \"#\"\
\9if k == 1 then\
\9\9hash_letter = \"?\"\
\9end\
\9table.insert(all_patterns, p .. hash_letter .. \"t=(%d+)m(%d+)s\")\
\9table.insert(all_patterns, p .. hash_letter .. \"t=(%d+)s?\")\
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
--player_url = \"http://localhost:8080/youtube.html?rand=\" .. math.random() .. \"&id=%s\"\
\
function YoutubeService:load(url)\
\9local media = oop.class(\"HTMLMedia\")()\
\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = string.format(player_url, urlData.id)\
\
\9media:openUrl(playerUrl)\
\
\9if urlData.start then media:seek(urlData.start) end\
\
\9return media\
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
\9\9\9data.title = \"ERROR\"\
\9\9\9data.duration = 60 -- this seems fine\
\9\9end\
\
\9\9callback(nil, data)\
\9end)\
end\
\
medialib.load(\"media\").RegisterService(\"youtube\", YoutubeService)"
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