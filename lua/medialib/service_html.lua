local oop = medialib.load("oop")
medialib.load("timekeeper")

local volume3d = medialib.load("volume3d")

local HTMLService = oop.class("HTMLService", "Service")
function HTMLService:load(url, opts)
	local media = oop.class("HTMLMedia")()
	media.unresolvedUrl = url

	self:resolveUrl(url, function(resolvedUrl, resolvedData)
		media:openUrl(resolvedUrl)

		-- TODO move to volume3d and call as a hook
		if opts and opts.use3D then
			volume3d.startThink(media, {pos = opts.pos3D, ent = opts.ent3D, fadeMax = opts.fadeMax3D})
		end

		if resolvedData and resolvedData.start and (not opts or not opts.dontSeek) then media:seek(resolvedData.start) end
	end)

	return media
end
function HTMLService:resolveUrl(url, cb)
	cb(url, self:parseUrl(url))
end

local HTMLMedia = oop.class("HTMLMedia", "Media")

local panel_width, panel_height = 1280, 720
function HTMLMedia:initialize()
	self.timeKeeper = oop.class("TimeKeeper")()

	self.panel = vgui.Create("DHTML")

	local pnl = self.panel
	pnl:SetPos(0, 0)
	pnl:SetSize(panel_width, panel_height)

	local hookid = "MediaLib.HTMLMedia.FakeThink-" .. self:hashCode()
	hook.Add("Think", hookid, function()
		if not IsValid(pnl) then
			hook.Remove("Think", hookid)
			return
		end

		pnl:Think()
	end)

	local oldcm = pnl.ConsoleMessage
	pnl.ConsoleMessage = function(pself, msg)
		-- Filter some things out
		if string.find(msg, "XMLHttpRequest") then return end
		if string.find(msg, "Unsafe JavaScript attempt to access") then return end

		return oldcm(pself, msg)
	end

	pnl:SetPaintedManually(true)
	pnl:SetVisible(false)

	pnl:AddFunction("medialiblua", "Event", function(id, jsonstr)
		self:handleHTMLEvent(id, util.JSONToTable(jsonstr))
	end)
end

function HTMLMedia:getBaseService()
	return "html"
end

function HTMLMedia:openUrl(url)
	self.panel:OpenURL(url)

	self.URLChanged = CurTime()
end
function HTMLMedia:runJS(js, ...)
	local code = string.format(js, ...)
	self.panel:QueueJavascript(code)
end

function HTMLMedia:handleHTMLEvent(id, event)
	if id == "stateChange" then
		local state = event.state
		local setToState

		if event.time then
			self.timeKeeper:seek(event.time)
		end
		if state == "playing" then
			setToState = "playing"
			self.timeKeeper:play()
		elseif state == "ended" or state == "paused" or state == "buffering" then
			setToState = state
			self.timeKeeper:pause()
		end

		if setToState then
			self.state = setToState
			self:emit(setToState)
		end
	end
end
function HTMLMedia:getState()
	return self.state
end

function HTMLMedia:updateTexture()
	-- Only update HTMLTexture once per frame
	if self.lastUpdatedFrame ~= FrameNumber() then
		self.panel:UpdateHTMLTexture()
		self.lastUpdatedFrame = FrameNumber()
	end
end

function HTMLMedia:draw(x, y, w, h)
	self:updateTexture()

	local mat = self.panel:GetHTMLMaterial()

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)

	local w_frac, h_frac = panel_width / mat:Width(), panel_height / mat:Height()
	surface.DrawTexturedRectUV(x or 0, y or 0, w or panel_width, h or panel_height, 0, 0, w_frac, h_frac)
end

function HTMLMedia:getTime()
	return self.timeKeeper:getTime()
end

function HTMLMedia:setQuality(qual)
	if self.lastSetQuality and self.lastSetQuality == qual then
		return
	end
	self.lastSetQuality = qual
	
	self:runJS("medialibDelegate.run('setQuality', {quality: %q})", qual)
end

-- This applies the volume to the HTML panel
-- There is a undocumented 'internalVolume' variable, that can be used by eg 3d vol
function HTMLMedia:applyVolume()
	local ivol = self.internalVolume or 1
	local rvol = self.volume or 1

	local vol = ivol * rvol

	if self.lastSetVolume and self.lastSetVolume == vol then
		return
	end
	self.lastSetVolume = vol

	self:runJS("medialibDelegate.run('setVolume', {vol: %f})", vol)
end

-- This sets a volume variable
function HTMLMedia:setVolume(vol)
	self.volume = vol
	self:applyVolume()
end

function HTMLMedia:seek(time)
	self:runJS("medialibDelegate.run('seek', {time: %d})", time)
end

function HTMLMedia:play()
	self.timeKeeper:play()

	self:runJS("medialibDelegate.run('play')")
end
function HTMLMedia:pause()
	self.timeKeeper:pause()

	self:runJS("medialibDelegate.run('pause')")
end
function HTMLMedia:stop()
	self.timeKeeper:pause()
	self.panel:Remove()

	self:emit("stopped")
end

function HTMLMedia:isValid()
	return IsValid(self.panel)
end
