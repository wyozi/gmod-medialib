-- Video selector is a VGUI component that consists of a browser and a vertical set of browser controls (ie. basically a minimal browser)
-- It also contains a button to request the url which is only valid for URLs that map to links accepted by medialib services.
--
-- Video selector is meant to be embedded and modified for each application's specific purposes.

local PANEL = {}

AccessorFunc(PANEL, "_callback", "Callback")

function PANEL:GetDefaultHTML()
	return [[
    <!DOCTYPE html>
    <html>
    	<head>
    		<meta charset="utf-8">
    		<style>
    			body {
    				background-color: white;
    			}
    		</style>
    	</head>
    	<body>
            <h1>Medialib video selector</h1>
            <a href="http://youtube.com">Youtube</a>
    	</body>
    </html>
	]]
end

function PANEL:Init()
	self.browser = vgui.Create("DHTML", self)
	self.browser:Dock(FILL)
	self.browser:SetHTML(self:GetDefaultHTML())

	-- GarryHTML has a weird Paint which flashes during loads. This fixes it
	self.browser.Paint = function() end

	-- Get rid of useless console messages
	local oldcm = self.browser.ConsoleMessage
	self.browser.ConsoleMessage = function(pself, msg, ...)
		if msg then
			if string.find(msg, "XMLHttpRequest") then return end
			if string.find(msg, "Unsafe JavaScript attempt to access") then return end
		end

		return oldcm(pself, msg, ...)
	end

	-- Needed because eg. youtube does non-documentreloading updates
	self.browser.UrlChanged = function()end
	self.browser:AddFunction("medialib", "CurrentUrl", function(curl)
		if curl ~= self.browser._lastcurl then
			self.browser:UrlChanged(curl)
			self.browser._lastcurl = curl
		end
	end)
	function self.browser:RequestCurrentUrl()
		self:RunJavascript("medialib.CurrentUrl(window.location.href);")
	end

	self.controls = vgui.Create("Panel", self)
	self.controls:Dock(TOP)

	local back = vgui.Create("DImageButton", self.controls)
	back:Dock(LEFT)
	back:SetSize(24, 24)
	back:SetMaterial("gui/HTML/back")
	back.DoClick = function() self.browser:GoBack() end

	local fwd = vgui.Create("DImageButton", self.controls)
	fwd:Dock(LEFT)
	fwd:SetSize(24, 24)
	fwd:SetMaterial("gui/HTML/forward")
	fwd.DoClick = function() self.browser:GoForward() end

	local refresh = vgui.Create("DImageButton", self.controls)
	refresh:Dock(LEFT)
	refresh:SetSize(24, 24)
	refresh:SetMaterial("gui/HTML/refresh")
	refresh.DoClick = function() self.browser:Refresh() end

	local url = vgui.Create("DTextEntry", self.controls)
	url:Dock(FILL)
	url.OnEnter = function() self.browser:OpenURL(url:GetText()) end

	local currentUrl

	local req = vgui.Create("DButton", self.controls)
	req:Dock(RIGHT)
	req:SetText("Request Url")
	req.DoClick = function()
		self:GetCallback()(currentUrl)
	end
	req:SetEnabled(false)

	local function UrlChanged(u)
		currentUrl = u

		if vgui.GetKeyboardFocus() ~= url then
			url:SetText(u)
		end

		local vid = medialib.load("media").GuessService(u)
		local enabled = vid ~= nil
		req:SetEnabled(enabled)
	end

	self.browser.OnDocumentReady = function(s, u)
		UrlChanged(u:find("^data:text") and "home" or u)
	end
	self.browser.UrlChanged = function(s, u)
		UrlChanged(u)
	end
	self.browser.OnChangeTitle = function(s, u) self.browser:RequestCurrentUrl() end
end

vgui.Register("MedialibVideoSelector", PANEL, "Panel")

concommand.Add("medialib_videoselectortest", function()
	local fr = vgui.Create("DFrame")

	local vidsel = vgui.Create("MedialibVideoSelector", fr)
	vidsel:SetCallback(function(url)
		fr:Close()

		print("playing " .. url)
	end)
	vidsel:Dock(FILL)

	fr:SetSize(800, 600)
	fr:Center()
	fr:MakePopup()
end)
