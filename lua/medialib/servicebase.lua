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