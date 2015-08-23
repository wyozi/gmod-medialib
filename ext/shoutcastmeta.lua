-- Shoutcast metadata fetcher.
-- AFAIK it is currently not possible to fetch metadata from the .pls stream itself without a binary module
-- But what we can do is try to find the Shoutcast webserver, and get current song data etc from there
--
-- This extension is fairly cheap to use. Querying for stream meatadata requires two HTTP requests

local function parseStreamLink(link, body)
	if link:find(".pls") then
		return body:match("File1=([^\n\r]+)"), body:match("Title1=([^\n\r]+)")
	end
	if link:find(".m3u") then
		return body:match("([^#][^\n\r]+)")
	end
end

-- Sends a GET request with following additional properties:
--    - 302 automatically redirects to the url (TODO)
--    - request times out after three seconds
--    - uses a browser imitating user agent
local function safeHTTP(url, successCb, failCb)
	local requestDone = false

	HTTP {
		url = url,
		method = "get",
		headers = {
			["User-Agent"] = "Mozilla/5.0 (Windows NT 6.3; WOW64; rv:39.0) Gecko/20100101 Firefox/39.0"
		},

		success = function(code, body, headers)
			if requestDone then return end -- timed out
			requestDone = true

			successCb(body, headers)
		end,
		failed = function(err)
			if requestDone then return end -- timed out
			requestDone = true

			if failCb then failCb(err) end
		end,
	}

	-- Some links like to never time out, so we add a manual timeout
	timer.Simple(3, function()
		if requestDone then return end -- already done
		requestDone = true

		if failCb then failCb("timeout") end
	end)
end

local function fetchStream(link, cb)
	safeHTTP(link, function(body, headers)
		local streamLink, streamTitle = parseStreamLink(link, body)
		if streamLink then
			cb(nil, streamLink, streamTitle)
		else
			cb("no streamlink found, is link valid?")
		end
	end, function(err)
		if err == "timeout" then
			cb("StreamHTTPReq timed out")
		else
			cb("StreamHTTPReq failed: " .. tostring(err))
		end
	end)
end

-- cheers http://stackoverflow.com/a/13408255
local function stripHTML(s)
	return s and s:gsub("%b<>", "")
end

local function fetch(link, cb)
	-- First fetch the actual stream IP
	fetchStream(link, function(err, stream, streamTitle)
		if err then
			cb(err)
			return
		end

		local data
		if streamTitle then
			data = {title = streamTitle}
		end

		-- If fetching shoutcast stuff errors, but we have streamTitle, we might
		-- as well ignore the error and provide title to the callback rather than
		-- nothing
		local function ShoutcastError(err)
			if not data then
				cb(err)
			else
				print("[MediaLib] Shoutcast errored '" .. tostring(err) .. "', but returning rudimentary metadata")
				cb(nil, data)
			end
		end

		-- The stream link - if fetched using HTTP - returns a HTTP page
		-- with relevant data, such as current song
		safeHTTP(stream, function(body, headers)
			local contentType = headers["Content-Type"]
			if contentType and not contentType:match("text/html") then
				ShoutcastError("Shoutcast link not html, but " .. contentType)
				return
			end

			data = data or {}
			data.title = stripHTML(body:match("Stream Title: .-<b>(.-)</b>") or body:match("Stream Name: .-<b>(.-)</b>") or data.title)
			data.currentSong = stripHTML(body:match("Current Song: .-<b>(.-)</b>"))

			cb(nil, data)
		end, function(err)
			if err == "timeout" then
				ShoutcastError("ShoutcastHTTPReq timed out")
			else
				ShoutcastError("ShoutcastHTTPReq failed: " .. tostring(err))
			end
		end)
	end)
end

hook.Add("Medialib_ExtendQuery", "Medialib_ShoutcastMeta", function(url, cbchain)
	if not (url:match(".pls") or url:match(".m3u")) then return end


	cbchain:addCallback(function(err, data, cb)
		fetch(url, function(sc_err, sc_data)
			-- if shoutcast stuff errored, use the normal stuff
			if sc_err then
				cb(err, data)
				return
			end

			cb(nil, sc_data)
		end)
	end)
end)
