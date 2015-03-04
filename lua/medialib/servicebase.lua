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