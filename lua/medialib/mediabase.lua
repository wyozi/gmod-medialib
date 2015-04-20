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
	
	local shouldSync = self:shouldSync()
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

function Media:draw(x, y, w, h) end