local oop = medialib.load("oop")

local volume3d = medialib.load("volume3d")

local BASSService = oop.class("BASSService", "Service")
function BASSService:load(url, opts)
	local media = oop.class("BASSMedia")()
	media._unresolvedUrl = url
	media._service = self

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

	-- Check if media stopped before loading properly
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
	self:runCommand(function(chan) chan:Play() self:emit("playing") end)
end
function BASSMedia:pause()
	self:runCommand(function(chan) chan:Pause() self:emit("paused") end)
end
function BASSMedia:stop()
	self._stopped = true
	self:runCommand(function(chan) chan:Stop() self:emit("destroyed") end)
end

function BASSMedia:isValid()
	return IsValid(self.chan)
end
