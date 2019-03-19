-- The purpose of TimeKeeper is to keep time where it is not easily available synchronously (ie. HTML based services)
local oop = medialib.load("oop")

local TimeKeeper = oop.class("TimeKeeper")

function TimeKeeper:initialize()
	self:reset()
end

function TimeKeeper:reset()
	self.cachedTime = 0

	self.running = false
	self.runningTimeStart = 0
end

function TimeKeeper:getTime()
	local time = self.cachedTime

	if self.running then
		time = time + (RealTime() - self.runningTimeStart)
	end

	return time
end

function TimeKeeper:isRunning()
	return self.running
end

function TimeKeeper:play()
	if self.running then return end

	self.runningTimeStart = RealTime()
	self.running = true
end

function TimeKeeper:pause()
	if not self.running then return end

	local runningTime = RealTime() - self.runningTimeStart
	self.cachedTime = self.cachedTime + runningTime

	self.running = false
end

function TimeKeeper:seek(time)
	self.cachedTime = time

	if self.running then
		self.runningTimeStart = RealTime()
	end
end