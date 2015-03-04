local oop = medialib.load("oop")

local panel_width, panel_height = 1280, 720

local HTMLMedia = oop.class("HTMLMedia", "Media")
function HTMLMedia:initialize()
	self.panel = vgui.Create("DHTML")

	local pnl = self.panel
	pnl:SetPos(0, 0)
	pnl:SetSize(panel_width, panel_height)

	pnl:SetPaintedManually(true)
	pnl:SetVisible(false)

	pnl:AddFunction("medialiblua", "Event", function(id, jsonstr)
		self:handleHTMLEvent(id, util.JSONToTable(jsonstr))
	end)
end
function HTMLMedia:stop()
	self.panel:Remove()
end

function HTMLMedia:handleHTMLEvent(id, event)
end

function HTMLMedia:draw(x, y, w, h)
	self.panel:UpdateHTMLTexture()

	local mat = self.panel:GetHTMLMaterial()

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)

	local w_frac, h_frac = panel_width / mat:Width(), panel_height / mat:Height()
	surface.DrawTexturedRectUV(0, 0, w or panel_width, h or panel_height, 0, 0, w_frac, h_frac)
end

function HTMLMedia:openUrl(url)
	self.panel:OpenURL(url)
end

function HTMLMedia:runJS(js)
	self.panel:QueueJavascript(js)
end

function HTMLMedia:setVolume(vol)
	self:runJS(string.format("medialibjs.setVolume(%f)", vol))
end

function HTMLMedia:play()
	self:runJS("medialibjs.play()")
end
function HTMLMedia:pause()
	self:runJS("medialibjs.pause()")
end
function HTMLMedia:stop()
	self.panel:Remove()
end

local HTMLService = oop.class("HTMLService", "Service")
