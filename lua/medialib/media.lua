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

function media.guessService(url)
	for _,service in pairs(media.Services) do
		if service:isValidUrl(url) then
			return service
		end
	end
end
media.GuessService = media.guessService -- alias