
local bdetector = {}

bdetector.HookId = bdetector.HookId or 0

local analyzer = MEDIALIB_BD_ANALYZER or {}
MEDIALIB_BD_ANALYZER = analyzer -- lua refresh support

analyzer.__index = analyzer

function bdetector.beatDetect(media)
	local analyzer = setmetatable({media=media, chan=media.chan}, analyzer)
	analyzer:init()
	media:runCommand(function() analyzer:start() end)

	return analyzer
end

hook.Add("Medialib_ProcessOpts", "Medialib_BeatDetector", function(media, opts)
	function media:canBeatDetect()
		return self:getBaseService() == "bass"
	end

	if not media:canBeatDetect() then return end

	function media:getBeatDetector()
		local bd = self._bdetector
		if bd then return bd end

		self._bdetector = bdetector.beatDetect(self)
		return self._bdetector
	end
end)

function analyzer:hook(name, cb)
	self.hooks = self.hooks or {}
	local id = "MediaLib.BeatDetector." .. bdetector.HookId
	bdetector.HookId = bdetector.HookId + 1

	hook.Add(name, id, cb)

	table.insert(self.hooks, {name=name, id=id})
end

function analyzer:init()
	self._spectrum = {}
	self._lastspectrum = {}
	self._flux = {}
	self._thresholdplot = {}
	self._prunnedfluxplot = {}
	self._peaksplot = {}
end

local function copytbl(x, y)
	for k,v in pairs(x) do
		y[k] = v
	end
end

function analyzer:_process()
	local iSamplingRate = self.chan:GetSamplingRate()
	local iNyquist = iSamplingRate / 2
	local iAudioDuration = self.chan:GetLength()

	local iFrequencyDelta = 1 / iAudioDuration

	self.media:updateFFT()
	local spectrum = self.media:getFFT()
	self._spectrum = spectrum
	local vals = #spectrum
	
	-- localize fields
	local lastspectrum, flux, thresholdplot, prunnedfluxplot, peaksplot =
		self._lastspectrum, self._flux, self._thresholdplot, self._prunnedfluxplot, self._peaksplot

	local frameflux = 0
	for i=1, vals do
		if not lastspectrum[i] then break end
		local val = spectrum[i] - lastspectrum[i]
		frameflux = frameflux + math.max(val, 0)
	end
	table.insert(flux, frameflux)
	if #flux > 128 then table.remove(flux, 1) end

	copytbl(spectrum, lastspectrum)

	do -- threshold
		for k,v in pairs(flux) do
			local s = math.max(1, k-10)
			local e = math.min(#flux, k+10)

			local mean = 0
			for i=s, e do
				mean = mean + flux[i]
			end
			mean = mean / (e-s)

			thresholdplot[k] = mean
		end

		-- used for avg threshold calculation in full energy estimation
		local curThreshold = thresholdplot[#thresholdplot]
		self._thresholdCount = (self._thresholdCount or 0) + 1
		self._thresholdSum = (self._thresholdSum or 0) + curThreshold
	end

	do -- prunned spectral flux
		for k,v in pairs(flux) do
			-- 1.5 = magic value, threshold change over 1.5x old triggers a peak
			local threshold = thresholdplot[k] * 1.5
			prunnedfluxplot[k] = (threshold <= v) and (v - threshold) or 0
		end
	end

	do -- peaks
		local lastPeaked = 0
		for k=1,#prunnedfluxplot-1 do
			peaksplot[k] = (prunnedfluxplot[k] > prunnedfluxplot[k+1]) and (prunnedfluxplot[k]) or 0
			lastPeaked = peaksplot[k]
		end

		if lastPeaked > 0 then
			self:onPeak(lastPeaked)
		end
	end
end

local function plot(name, t, x, y, w, h)
	draw.SimpleText(name, "DermaDefault", x+5, y+5)

	local s_w = 2
	
	local val_1_height = 100 -- height at val=1

	for i=1,#t do
		surface.SetDrawColor(255, 255, 255)
		local val = t[i]
		local hh = val*val_1_height
		surface.DrawRect(x+(s_w*i), y+h-hh, s_w, hh)
	end
	surface.DrawOutlinedRect(x, y, #t*s_w, h)
end

function analyzer:_drawDebug()
	draw.SimpleText("BeatDetect: ", "DermaDefaultBold", 50, 50)

	local y = 75
	plot("fft", self._spectrum, 50, y, 250, 150); y=y+150
	plot("flux", self._flux, 50, y, 250, 150); y=y+150
	plot("threshold", self._thresholdplot, 50, y, 250, 150); y=y+150
	plot("prunned flux", self._prunnedfluxplot, 50, y, 250, 150); y=y+150
	plot("peaks", self._peaksplot, 50, y, 250, 150); y=y+150

	draw.SimpleText("Current energy: " .. self:getCurrentEnergy(), "DermaDefaultBold", 325, 250)
	draw.SimpleText("RecentContext energy: " .. self:getCurrentRecentContextEnergy(), "DermaDefaultBold", 325, 270)
	draw.SimpleText("FullContext energy: " .. self:getCurrentFullContextEnergy(), "DermaDefaultBold", 325, 290)
end

local cvar_debugBD = CreateConVar("medialib_debugbd", "0")	
function analyzer:start()
	self:hook("Think", function()
		if not IsValid(self.chan) then
			self:stop()
			return
		end
		
		self:_process()
	end)
	
	self:hook("HUDPaint", function()
		if not cvar_debugBD:GetBool() then return end
		self:_drawDebug()
	end)
end

-- Gets energy related to the immediate context within the playing audio
-- In practice this means how energetic the song is at this very moment
-- compared to around 2 seconds worth of audio data before.
-- That means this will shoot high during drops but normalizes quickly.
-- Expected value range on both sides of 1. Basically a multiplier (2x the average energy = 2.0f)
function analyzer:getCurrentRecentContextEnergy()
	local ts = self._thresholdplot
	local curThreshold = ts[#ts]
	if not curThreshold then return 1 end
	
	local avgThreshold = 0
	for _,t in pairs(ts) do avgThreshold = avgThreshold + t end
	avgThreshold = avgThreshold / #ts
	
	return curThreshold / avgThreshold
end

-- Same as above but for the whole so far played audio
function analyzer:getCurrentFullContextEnergy()
	local curEnergy = self:getCurrentEnergy()
	local avgThreshold = (self._thresholdSum or 0) / (self._thresholdCount or 1)
	return curEnergy / avgThreshold
end

-- Get current energy level of the song
function analyzer:getCurrentEnergy()
	local ts = self._thresholdplot
	return ts[#ts] or 0
end

function analyzer:stop()
	if self.hooks then
		table.foreach(self.hooks, function(k, v)
			hook.Remove(v.name, v.id)
		end)
	end
end

function analyzer:onPeak(str)
	if not self.listeners then return end

	for k,v in pairs(self.listeners) do
		v(str)
	end
end

function analyzer:addPeakListener(id, listener)
	self.listeners = self.listeners or {}
	self.listeners[id] = listener
end

function analyzer:hasPeakListener(id)
	return self.listeners and self.listeners[id]
end
