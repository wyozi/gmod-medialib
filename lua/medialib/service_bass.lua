local oop = medialib.load("oop")

local BASSService = oop.class("BASSService", "Service")

local BASSMedia = oop.class("BASSMedia", "Media")

function BASSMedia:initialize()
	self.commandQueue = {}
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
