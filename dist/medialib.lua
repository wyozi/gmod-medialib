medialib = {}
medialib.Modules = {}

function medialib.modulePlaceholder(name)
	medialib.Modules[name] = {}
end
function medialib.module(name, opts)
	local mod = {
		name = name,
		dependencies = {},
		options = opts,
	}

	medialib.Modules[name] = mod

	return mod
end

function medialib.load(name)
	local mod = medialib.Modules[name]
	if mod then return mod end

	local file = "medialib/" .. name .. ".lua"
	if SERVER then AddCSLuaFile(file) end
	include(file)

	return medialib.Modules[name]
end

local real_file_meta = {
	read = function(self)
		return file.Read(self.lua_path, "LUA")
	end,
	load = function(self)
		if SERVER then AddCSLuaFile(self.lua_path) end
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
	oop.Classes = {}
	function oop.class(name, parent)
		local cls = oop.Classes[name]
		if not cls then
			cls = oop.createClass(name, parent)
			oop.Classes[name] = cls
		end
		return cls
	end
	function oop.resolveClass(obj)
		if obj == nil then
			return oop.Object
		end
		local t = type(obj)
		if t == "string" then
			return oop.Classes[obj]
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
-- Module service_html
medialib.modulePlaceholder("service_html")
do
	local oop = medialib.load("oop")
	local panel_width, panel_height = 1280, 720
	local HTMLMedia = oop.class("HTMLMedia", "Media")
	function HTMLMedia:initialize()
		self.panel = vgui.Create("DHTML")
		local pnl = self.panel
		pnl:SetPos(0, 0)
		pnl:SetSize(panel_width, panel_height)
		pnl:SetPaintedManually(true)
		pnl:SetVisible(false)
		pnl:AddFunction("medialiblua", "Event", function(id, jsonstr)
			local json = util.JSONToTable(jsonstr)
			print("Received event ", id, ": ", table.ToString(json))
		end)
	end
	function HTMLMedia:stop()
		self.panel:Remove()
	end
	function HTMLMedia:draw(x, y, w, h)
		self.panel:UpdateHTMLTexture()
		local mat = self.panel:GetHTMLMaterial()
		surface.SetMaterial(mat)
		surface.SetDrawColor(255, 255, 255)
		local w_frac, h_frac = panel_width / mat:Width(), panel_height / mat:Height()
		surface.DrawTexturedRectUV(0, 0, w or panel_width, h or panel_height, 0, 0, w_frac, h_frac)
	end
	function HTMLMedia:openUrl(url)
		self.panel:OpenURL(url)
	end
	function HTMLMedia:runJS(js)
		self.panel:QueueJavascript(js)
	end
	function HTMLMedia:setVolume(vol)
		self:runJS(string.format("medialibjs.setVolume(%f)", vol))
	end
	function HTMLMedia:play()
		self:runJS("medialibjs.play()")
	end
	function HTMLMedia:pause()
		self:runJS("medialibjs.pause()")
	end
	function HTMLMedia:stop()
		self.panel:Remove()
	end
	local HTMLService = oop.class("HTMLService", "Service")
end
-- Module service_bass
medialib.modulePlaceholder("service_bass")
do
	local oop = medialib.load("oop")
	local HTMLService = oop.class("BASSService", "Service")
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
			if service:validateUrl(url) then
				return service
			end
		end
	end
end
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
function YoutubeService:load(url)\
\9local media = oop.class(\"HTMLMedia\")()\
\
\9local urlData = self:parseUrl(url)\
\9local playerUrl = \"http://wyozi.github.io/gmod-medialib/youtube.html?id=\" .. urlData.id\
\
\9media:openUrl(playerUrl)\
\
\9return media\
end\
\
medialib.load(\"media\").RegisterService(\"youtube\", YoutubeService)"
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
	-- Load service types
	medialib.load("service_html")
	medialib.load("service_bass")
	-- Load the actual service files
	for _,file in medialib.folderIterator("services") do
		file:load()
	end
end
-- Module __loader
medialib.modulePlaceholder("__loader")
do
	-- This file loads all the requires modules.
	-- It is in different file than medialib.lua for medialib build purposes
	medialib.load("servicebase")
	medialib.load("media")
end