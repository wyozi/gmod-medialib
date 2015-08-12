-- A beat detector for BASS based services (ie. webradio and webaudio). Uses onset detection as described at
-- http://www.badlogicgames.com/wordpress/?cat=18&paged=3
--
-- Usage:
-- 		local beatdetector = medialib.load("beatdetector").beatDetect(media)
-- where media is a media object created from a BASS service
--
-- Adding peak listeners:
--		beatdetector:addPeakListener("id", function(peakStrength) print("peak happened at ", peakStrength) end)

local bdetector = medialib.module("beatdetector")

bdetector.HookId = bdetector.HookId or 0

local analyzer = {}
analyzer.__index = analyzer

function bdetector.beatDetect(media)
	if not IsValid(media.chan) then
		ErrorNoHalt("[MediaLib BeatDetector] beatDetect must be called with a media object with a valid channel. See BASSMedia:runCommand")
		return
	end

	local analyzer = setmetatable({media=media, chan=media.chan}, analyzer)
	analyzer:start()

	return analyzer
end

function analyzer:hook(name, cb)
	self.hooks = self.hooks or {}
	local id = "MediaLib.BeatDetector." .. bdetector.HookId
	bdetector.HookId = bdetector.HookId + 1

	hook.Add(name, id, cb)

	table.insert(self.hooks, {name=name, id=id})
end

function analyzer:debug()
	local spectrum = {}
	local lastspectrum = {}

	local _flux = {}

	local thresholdplot = {}
	local prunnedfluxplot = {}
	local peaksplot = {}

	local function copytbl(x, y)
		for k,v in pairs(x) do
			y[k] = v
		end
	end
	local function plot(name, t, x, y, w, h)
		draw.SimpleText(name, "DermaDefault", x+5, y+5)

		local s_w = 2

		for i=1,#t do
			surface.SetDrawColor(255, 255, 255)
			local h = t[i]
			local hh = h*100
			surface.DrawRect(x+(s_w*i), y+100-hh, s_w, hh)
		end
		surface.DrawOutlinedRect(x, y, #t*s_w, 100)
	end

	self:hook("HUDPaint", function()
		draw.SimpleText("BeatDetect: ", "DermaDefaultBold", 50, 50)

		local iSamplingRate = self.chan:GetSamplingRate()
		local iNyquist = iSamplingRate / 2
		local iAudioDuration = self.chan:GetLength()

		local iFrequencyDelta = 1 / iAudioDuration

		self.media:updateFFT()
		spectrum = self.media:getFFT()
		local vals = #spectrum

		plot("fft", spectrum, 50, 75, 250, 100)

		if true then return end

		local flux = 0
		for i=1, vals do
			if not lastspectrum[i] then break end
			local val = spectrum[i] - lastspectrum[i]
			flux = flux + math.max(val, 0)
		end
		table.insert(_flux, flux)
		if #_flux > 512 then table.remove(_flux, 1) end

		plot("flux", _flux, 50, 175, 250, 100)
		copytbl(spectrum, lastspectrum)

		do -- threshold
			for k,v in pairs(_flux) do
				local s = math.max(1, k-10)
				local e = math.min(#_flux, k+10)

				local mean = 0
				for i=s, e do
					mean = mean + _flux[i]
				end
				mean = mean / (e-s)

				thresholdplot[k] = mean*1.5
			end

			plot("threshold", thresholdplot, 50, 330)
		end

		do -- prunned spectral flux
			for k,v in pairs(_flux) do
				prunnedfluxplot[k] = (thresholdplot[k] <= v) and (v - thresholdplot[k]) or 0
			end
			plot("prunned flux", prunnedfluxplot, 50, 435)
		end

		do -- peaks
			local lastPeaked = 0
			for k=1,#prunnedfluxplot-1 do
				peaksplot[k] = (prunnedfluxplot[k] > prunnedfluxplot[k+1]) and (prunnedfluxplot[k]) or 0
				lastPeaked = peaksplot[k]
			end
			plot("peaks", peaksplot, 50, 540)

			if lastPeaked > 0 then
				print("peak " .. lastPeaked)
			end
		end


	end)
end

function analyzer:start()
	local spectrum = {}
	local lastspectrum = {}

	local _flux = {}

	local thresholdplot = {}
	local prunnedfluxplot = {}
	local peaksplot = {}

	local function copytbl(x, y)
		for k,v in pairs(x) do
			y[k] = v
		end
	end

	self:hook("Think", function()
		if not IsValid(self.chan) then
			self:stop()
			return
		end
		local iSamplingRate = self.chan:GetSamplingRate()
		local iNyquist = iSamplingRate / 2
		local iAudioDuration = self.chan:GetLength()

		local iFrequencyDelta = 1 / iAudioDuration

		self.media:updateFFT()
		spectrum = self.media:getFFT()
		local vals = #spectrum

		local flux = 0
		for i=1, vals do
			if not lastspectrum[i] then break end
			local val = spectrum[i] - lastspectrum[i]
			flux = flux + math.max(val, 0)
		end
		table.insert(_flux, flux)
		if #_flux > 64 then table.remove(_flux, 1) end

		copytbl(spectrum, lastspectrum)

		do -- threshold
			for k,v in pairs(_flux) do
				local s = math.max(1, k-10)
				local e = math.min(#_flux, k+10)

				local mean = 0
				for i=s, e do
					mean = mean + _flux[i]
				end
				mean = mean / (e-s)

				thresholdplot[k] = mean*1.5
			end

		end

		do -- prunned spectral flux
			for k,v in pairs(_flux) do
				prunnedfluxplot[k] = (thresholdplot[k] <= v) and (v - thresholdplot[k]) or 0
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
	end)
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
