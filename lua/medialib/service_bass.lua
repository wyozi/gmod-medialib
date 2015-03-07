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