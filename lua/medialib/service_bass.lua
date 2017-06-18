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