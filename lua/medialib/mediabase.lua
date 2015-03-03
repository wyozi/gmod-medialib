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