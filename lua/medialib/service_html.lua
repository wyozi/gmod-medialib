local oop = medialib.load("oop")

local HTMLService = oop.class("HTMLService", "Service")

local HTMLMedia = oop.class("HTMLMedia", "Media")
local panel_width, panel_height = 1920, 1080
function HTMLMedia:initialize()
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
function HTMLMedia:openUrl(url)
	self.panel:OpenURL(url)

	self.URLChanged = CurTime()
end
function HTMLMedia:runJS(js, ...)
	local code = string.format(js, ...)
	self.panel:QueueJavascript(code)
end

function HTMLMedia:handleHTMLEvent(id, event)
end

function HTMLMedia:draw(x, y, w, h)
	self.panel:UpdateHTMLTexture()

	local mat = self.panel:GetHTMLMaterial()

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)

	local w_frac, h_frac = panel_width / mat:Width(), panel_height / mat:Height()
	surface.DrawTexturedRectUV(x or 0, y or 0, w or panel_width, h or panel_height, 0, 0, w_frac, h_frac)
end

function HTMLMedia:setQuality(qual)
	self:runJS("medialibDelegate.run('setQuality', {quality: %q})", qual)
end

function HTMLMedia:setVolume(vol)
	self:runJS("medialibDelegate.run('setVolume', {vol: %f})", vol)
end

function HTMLMedia:seek(time)
	self:runJS("medialibDelegate.run('seek', {time: %d})", time)
end

function HTMLMedia:play()
	self:runJS("medialibDelegate.run('play')")
end
function HTMLMedia:pause()
	self:runJS("medialibDelegate.run('pause')")
end
function HTMLMedia:stop()
	self.panel:Remove()
end