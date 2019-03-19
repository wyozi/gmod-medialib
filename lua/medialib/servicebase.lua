local oop = medialib.load("oop")
local mediaregistry = medialib.load("mediaregistry")

local Service = oop.class("Service")

function Service:on(event, callback)
	self._events = {}
	self._events[event] = self._events[event] or {}
	self._events[event][callback] = true
end
function Service:emit(event, ...)
	for k,_ in pairs(self._events[event] or {}) do
		k(...)
	end

	if event == "error" then
		MsgN("[MediaLib] Video error: " .. table.ToString{...})
	end
end

function Service:load() end
function Service:loadMediaObject(media, url, opts)
	media._unresolvedUrl = url
	media._service = self

	media:setDefaultTag()

	hook.Run("Medialib_ProcessOpts", media, opts or {})

	mediaregistry.add(media)

	self:resolveUrl(url, function(resolvedUrl, resolvedData)
		media:openUrl(resolvedUrl)

		if resolvedData and resolvedData.start and (not opts or not opts.dontSeek) then media:seek(resolvedData.start) end
	end)
end

function Service:isValidUrl() end

-- Sub-services should override this
function Service:directQuery() end

-- A metatable for the callback chain
local _service_cbchain_meta = {}
_service_cbchain_meta.__index = _service_cbchain_meta
function _service_cbchain_meta:addCallback(cb)
	table.insert(self._callbacks, cb)
end
function _service_cbchain_meta:run(err, data)
	local first = table.remove(self._callbacks, 1)
	if not first then return end

	first(err, data, function(chainedErr, chainedData)
		self:run(chainedErr, chainedData)
	end)
end

-- Query calls direct query and then passes the data through a medialib hook
function Service:query(url, callback)
	local cbchain = setmetatable({_callbacks = {}}, _service_cbchain_meta)

	-- First add the data gotten from the service itself
	cbchain:addCallback(function(_, _, cb) return self:directQuery(url, cb) end)

	-- Then add custom callbacks
	hook.Run("Medialib_ExtendQuery", url, cbchain)

	-- Then add the user callback
	cbchain:addCallback(function(err, data) callback(err, data) end)

	-- Finally run the chain
	cbchain:run(url)
end

function Service:parseUrl() end

-- the second argument to cb() function call has some standard keys:
--   `start` the time at which to start media in seconds
function Service:resolveUrl(url, cb)
	cb(url, self:parseUrl(url))
end
