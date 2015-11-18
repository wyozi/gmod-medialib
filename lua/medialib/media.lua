local media = medialib.module("media")
media.Services = {}

function media.registerService(name, cls)
	media.Services[name] = cls()
end
media.RegisterService = media.registerService -- alias

function media.service(name)
	return media.Services[name]
end
media.Service = media.service -- alias

function media.guessService(url, opts)
	for name,service in pairs(media.Services) do
		local isViable = true

		if opts and opts.whitelist then
			isViable = isViable and table.HasValue(opts.whitelist, name)
		end
		if opts and opts.blacklist then
			isViable = isViable and not table.HasValue(opts.blacklist, name)
		end

		if isViable and service:isValidUrl(url) then
			return service
		end
	end
end
media.GuessService = media.guessService -- alias
