local oop = medialib.load("oop")

local HTMLMedia = oop.class("HTMLMedia", "Media")
function HTMLMedia:initialize()
	self.panel = vgui.Create("DHTML")

	local pnl = self.panel
	pnl:SetPos(0, 0)

	pnl:SetPaintedManually(true)
	pnl:SetVisible(false)
end
function HTMLMedia:stop()
	self.panel:Remove()
end

function HTMLMedia:draw(x, y, w, h)
	self.panel:SetSize(w, h)
	self.panel:UpdateHTMLTexture()

	local mat = self.panel:GetHTMLMaterial()

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRect(x, y, w, h)
end

function HTMLMedia:openUrl(url)
	self.panel:OpenURL(url)
end

local HTMLService = oop.class("HTMLService", "Service")
