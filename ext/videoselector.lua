-- Video selector is a VGUI component that consists of a browser and a vertical set of browser controls (ie. basically a minimal browser)
-- It also contains a button to request the url which is only valid for URLs that map to links accepted by medialib services.
--
-- Video selector is meant to be embedded and modified for each application's specific purposes.

local PANEL = {}

function PANEL:GetDefaultHTML()
	return [[
	<!DOCTYPE html>
	<html>
		<head>
			<meta charset="utf-8">
			<style>
				body {
					background-color: #1d1f21;
					color: white;

					max-width: 900px;
					margin-left: auto;
					margin-right: auto;
					text-align: center;
				}
				#servicelinks a {
					display: block;
					width: 80%;
					margin: 10px 0 auto;
					height: 50px;
					line-height: 50px;
					text-align: center;

					font-size: 24px;
					background-color: #505458;
					color: rgb(240, 240, 240);
				}
				#servicelinks a:hover {
					background-color: #777b80;
				}
			</style>
		</head>
		<body>
			<h2>Media Selector</h2>
			<div id="servicelinks">
				<a href="http://youtube.com">Youtube</a>
				<a href="https://wyozi.github.io/gmod-medialib/browsers/soundcloud.html">SoundCloud</a>
			</div>
		</body>
	</html>
	]]
end

function PANEL:InitCustomControls(ctrl)
	local qbtn = ctrl:Add("DButton")
	qbtn:Dock(RIGHT)
	qbtn:SetWide(100)
	qbtn:SetText("Add to Queue")
	qbtn.DoClick = function()
		self:OnURLSelected(ctrl.AddressBar:GetText())
	end

	self.addToQueueButton = qbtn
end

function PANEL:Init()
	self.browser = self:Add("DHTML")
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
	self.browser:AddFunction("medialib", "CurrentURL", function(curl)
		if curl ~= self.browser._lastcurl then
			self.browser:UrlChanged(curl)
			self.browser._lastcurl = curl
		end
	end)
	self.browser:AddFunction("medialib", "QueueURL", function(url)
		self:OnURLSelected(url)
	end)

	function self.browser:RequestCurrentURL()
		self:RunJavascript("medialib.CurrentURL(window.location.href);")
	end

	self.controls = self:Add("DHTMLControls")
	self.controls:Dock(TOP)
	self.controls:SetHTML(self.browser)

	self.controls.AddressBar.OnChange = function(teself)
		local u = teself:GetText()

		local vid = medialib.load("media").GuessService(u)
		local enabled = vid ~= nil
		self:OnURLValidityChanged(enabled)
	end

	self:InitCustomControls(self.controls)

	local function UrlChanged(u)
		local addressBar = self.controls.AddressBar
		if vgui.GetKeyboardFocus() ~= addressBar then
			addressBar:SetText(u)

			-- this doesnt trigger on SetText
			addressBar:OnChange()
		end
	end

	self.browser.OnDocumentReady = function(s, u)
		UrlChanged(u:find("^data:text") and "home" or u)
	end
	self.browser.UrlChanged = function(s, u)
		UrlChanged(u)
	end
	self.browser.OnChangeTitle = function(s, u) self.browser:RequestCurrentURL() end
end

function PANEL:OnURLValidityChanged(b)
	self.addToQueueButton:SetEnabled(b)
end

function PANEL:OnURLSelected(url)
end

vgui.Register("MedialibVideoSelector", PANEL, "Panel")

concommand.Add("medialib_videoselectortest", function()
	local fr = vgui.Create("DFrame")

	local vidsel = vgui.Create("MedialibVideoSelector", fr)
	vidsel.OnURLSelected = function(_, url)
		fr:Close()

		print("playing " .. url)
	end
	vidsel:Dock(FILL)

	fr:SetSize(800, 600)
	fr:Center()
	fr:MakePopup()
end)
