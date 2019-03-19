local oop = medialib.load("oop")
medialib.load("timekeeper")

local HTMLService = oop.class("HTMLService", "Service")
function HTMLService:load(url, opts)
	local media = oop.class("HTMLMedia")()
	self:loadMediaObject(media, url, opts)
	return media
end

-- Whether or not we can trust that the HTML panel will send 'playing', 'paused'
-- and other playback related events. If this returns true, 'timekeeper' will
-- not be updated in playback related methods (except stop).
function HTMLService:hasReliablePlaybackEvents(_media)
	return false
end

local HTMLPool = {instances = {}}
local function GetMaxPoolInstances()
	return medialib.MAX_HTMLPOOL_INSTANCES or 0
end

hook.Add("MediaLib_HTMLPoolInfo", medialib.INSTANCE, function()
	print(medialib.INSTANCE .. "> Free HTMLPool instance count: " .. #HTMLPool.instances .. "/" .. GetMaxPoolInstances())
end)
concommand.Add("medialib_htmlpoolinfo", function()
	hook.Run("MediaLib_HTMLPoolInfo")
end)

-- Automatic periodic cleanup of html pool objects
timer.Create("MediaLib." .. medialib.INSTANCE .. ".HTMLPoolCleaner", 60, 0, function()
	if #HTMLPool.instances == 0 then return end

	local inst = table.remove(HTMLPool.instances, 1)
	if IsValid(inst) then inst:Remove() end
end)
function HTMLPool.newInstance()
	return vgui.Create("DHTML")
end
function HTMLPool.get()
	if #HTMLPool.instances == 0 then
		if medialib.DEBUG then
			MsgN("[MediaLib] Returning new instance; htmlpool empty")
		end
		return HTMLPool.newInstance()
	end

	local inst = table.remove(HTMLPool.instances, 1)
	if not IsValid(inst) then
		if medialib.DEBUG then
			MsgN("[MediaLib] Returning new instance; instance was invalid")
		end
		return HTMLPool.newInstance()
	end
	if medialib.DEBUG then
		MsgN("[MediaLib] Returning an instance from the HTML pool")
	end
	return inst
end
function HTMLPool.free(inst)
	if not IsValid(inst) then return end

	if #HTMLPool.instances >= GetMaxPoolInstances() then
		if medialib.DEBUG then
			MsgN("[MediaLib] HTMLPool full; removing the freed instance")
		end
		inst:Remove()
	else
		if medialib.DEBUG then
			MsgN("[MediaLib] Freeing an instance to the HTMLPool")
		end
		inst:SetHTML("")
		table.insert(HTMLPool.instances, inst)
	end
end

local cvar_showAllMessages = CreateConVar("medialib_showallmessages", "0")

local HTMLMedia = oop.class("HTMLMedia", "Media")

local panel_width, panel_height = 1280, 720
function HTMLMedia:initialize()
	self.timeKeeper = oop.class("TimeKeeper")()

	self.panel = HTMLPool.get()

	local pnl = self.panel
	pnl:SetPos(0, 0)
	pnl:SetSize(panel_width, panel_height)

	local hookid = "MediaLib.HTMLMedia.FakeThink-" .. self:hashCode()
	hook.Add("Think", hookid, function()
		if not IsValid(self.panel) then
			hook.Remove("Think", hookid)
			return
		end

		self.panel:Think()
	end)

	local oldcm = pnl._OldCM or pnl.ConsoleMessage
	pnl._OldCM = oldcm
	pnl.ConsoleMessage = function(pself, msg)
		if msg and not cvar_showAllMessages:GetBool() then
			-- Filter some things out
			if string.find(msg, "XMLHttpRequest", nil, true) then return end
			if string.find(msg, "Unsafe JavaScript attempt to access", nil, true) then return end
			if string.find(msg, "Unable to post message to", nil, true) then return end
			if string.find(msg, "ran insecure content from", nil, true) then return end
			if string.find(msg, "Mixed Content:", nil, true) then return end
		end

		return oldcm(pself, msg)
	end

	pnl:AddFunction("console", "warn", function(param)
		-- Youtube seems to spam lots of useless stuff here (that requires this function still?), so block by default
		if not cvar_showAllMessages:GetBool() then return end

		pnl:ConsoleMessage(param)
	end)

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
	if medialib.DEBUG then
		MsgN("[MediaLib] HTML Event: " .. id .. " (" .. table.ToString(event) .. ")")
	end
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
	elseif id == "playerLoaded" then
		for _,fn in pairs(self.commandQueue or {}) do
			fn()
		end
	elseif id == "error" then
		self:emit("error", {errorId = "service_error", errorName = "Error from service: " .. tostring(event.message)})
	else
		MsgN("[MediaLib] Unhandled HTML event " .. tostring(id))
	end
end
function HTMLMedia:getState()
	return self.state
end

local cvar_updatestride = CreateConVar("medialib_html_updatestride", "1", FCVAR_ARCHIVE)

function HTMLMedia:setUpdateStrideOverride(override)
	self._updateStrideOverride = override
end

function HTMLMedia:updateTexture()
	local framenumber = FrameNumber()

	local nextTextureUpdateFrame = self._nextTextureUpdateFrame or 0

	local stride = self._updateStrideOverride or cvar_updatestride:GetInt()
	if nextTextureUpdateFrame <= framenumber then
		self.panel:UpdateHTMLTexture()
		self._nextTextureUpdateFrame = framenumber + stride
	end
end

function HTMLMedia:getHTMLMaterial()
	if self._htmlMat then
		return self._htmlMat
	end
	local mat = self.panel:GetHTMLMaterial()
	self._htmlMat = mat
	return mat
end

function HTMLMedia:draw(x, y, w, h)
	self:updateTexture()

	local mat = self:getHTMLMaterial()

	-- [June 2017] CEF GetHTMLMaterial returns nil for some time after panel creation
	if not mat then
		return
	end

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

function HTMLMedia:getVolume()
	-- could cookies potentially set the volume to something other than 1?
	return self.volume or 1
end

-- if we dont rely on callbacks from JS, this will be the 'buffer' time for seeks
local SEEK_BUFFER = 0.2

function HTMLMedia:seek(time)
	-- Youtube does not seem to properly callback with a 'seek' event (works in Chrome)
	-- Workaround by setting timeseeker time instantly here with a small buffer
	-- Using workaround is ok because if we somehow get event later, it'll correct
	-- the time that was set wrongly here
	self.timeKeeper:seek(time - SEEK_BUFFER)

	self:runJS("medialibDelegate.run('seek', {time: %.1f})", time)
end

-- See HTMLService:hasReliablePlaybackEvents()
function HTMLMedia:hasReliablePlaybackEvents()
	local service = self:getService()
	return service and service:hasReliablePlaybackEvents(self)
end

function HTMLMedia:play()
	if not self:hasReliablePlaybackEvents() then
		self.timeKeeper:play()
	end

	self:runJS("medialibDelegate.run('play')")
end
function HTMLMedia:pause()
	if not self:hasReliablePlaybackEvents() then
		self.timeKeeper:pause()
	end

	self:runJS("medialibDelegate.run('pause')")
end
function HTMLMedia:stop()
	HTMLPool.free(self.panel)
	self.panel = nil

	self.timeKeeper:pause()
	self:emit("ended", {stopped = true})
	self:emit("destroyed")
end

function HTMLMedia:runCommand(fn)
	if self._playerLoaded then
		fn()
	else
		self.commandQueue = self.commandQueue or {}
		self.commandQueue[#self.commandQueue+1] = fn
	end
end

function HTMLMedia:isValid()
	return IsValid(self.panel)
end
