local media = medialib.module("media")
media.Services = {}

function media.RegisterService(name, cls)
	media.Services[name] = cls()
end

function media.Service(name)
	return media.Services[name]
end

function media.GuessService(url)
	for _,service in pairs(media.Services) do
		if service:validateUrl(url) then
			return service
		end
	end
end