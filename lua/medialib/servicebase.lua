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
