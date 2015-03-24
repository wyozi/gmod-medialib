-- Enables parsing ID3 headers of given mp3 files. This means service:query returns a lot more relevant
-- information, such as artist and title instead of just the filename.
--
-- The downside is that parsing the header requires fetching the whole mp3 file, which is expensive and
-- takes a while.
--
-- Orig. Source: https://gist.github.com/mkottman/1162235

local id3 = medialib.module("id3parser")

local function textFrame(name)
	return function (reader, info, frameSize)
		local encoding = reader.readByte()
		info[name] =  reader.readStr(frameSize - 1)
	end
end

-- only decode these ID3v2 frames
local frameDecoders = {
	COMM = function (reader, info, frameSize)
		local encoding = reader.readByte()
		local language = reader.readStr(4)
		info.comment = reader.readStr(frameSize - 5)
	end,
	TALB = textFrame 'album',
	TBPM = textFrame 'bpm',
	TENC = textFrame 'encoder',
	TLEN = textFrame 'length',
	TIT2 = textFrame 'title',
	TPE1 = textFrame 'artist',
	TRCK = textFrame 'track',
	TYER = textFrame 'year',
}

local function unpad(str)
	return (str:gsub('[%s%z]+$', ''))
end

local function isbitset(x, p)
	local b = 2 ^ (p - 1)
	return x % (b + b) >= b       
end

--- Read ID3 tags from MP3 file. First tries ID3v2 tags, then ID3v1 and returns those
-- which are found first. Returns the following tags (if they are contained in the file):
-- <ul><li>title</li><li>artist</li><li>album</li><li>year</li><li>comment</li></ul>
-- @name readtags
-- @param file Either string (filename) or a file object opened by io.open()
-- @return Table containing the metadata from ID3 tag, or nil.
function id3.readtags(file)
	local position = file:seek()
	
	local function decodeID3v2(reader)
		local info = {}
		local rb = reader.readByte
		local version = reader.readInt(2)
		local flags = rb()
		local size = reader.readInt(4, 128)
		
		if isbitset(flags, 7) then
			local mult = version >= 0x0400 and 128 or 256
			local extendedSize = reader.readInt(4, mult)
			local extendedFlags = reader.readInt(2)
			local padding = reader.readInt(4)
			reader.skip(extendedSize - 10)
		end
		while reader.position() < size + 3 do
			local frameID = reader.readStr(4)
			local frameSize = reader.readInt(4)
			local frameFlags = reader.readInt(2)
			if frameDecoders[frameID] then
				frameDecoders[frameID](reader, info, frameSize)
			else
				reader.skip(frameSize)
			end
		end
		file:seek('set', position)
		return info
	end
	
	local function decodeID3v1(reader)
		local info = {}
		info.title = reader.readStr(30)
		info.artist = reader.readStr(30)
		info.album = reader.readStr(30)
		info.year = reader.readStr(4)
		info.comment = reader.readStr(28)
		local zero = reader.readByte()
		local track = reader.readByte()
		local genre = reader.readByte()
		if zero == 0 then
			info.track = track
			info.genre = genre
		else
			info.comment = unpad(info.comment .. string.char(zero, track, genre))
		end
		
		file:seek('end', -128 - 227)
		local hdr = reader.readStr(4)
		if hdr == "TAG+" then
			info.title = unpad(info.title .. reader.readStr(60))
			info.artist = unpad(info.artist .. reader.readStr(60))
			info.album = unpad(info.album .. reader.readStr(60))
			-- some other tags omitted
		end
		
		file:seek('set', position)
		return info
	end
	
	local function readByte()
		local byte = assert(file:read(1), 'Could not read byte.')
		return string.byte(byte)
	end
	local reader = {
		readStr = function(len)
			local str = assert(file:read(len), 'Could not read '..len..'-byte string.')
			return unpad(str)
		end,
		readByte = readByte,
		readInt = function(size, mult)
			mult = mult or 256
			local n = readByte()
			for i=2, size do
				n = n*mult + readByte()
			end
			return n
		end,
		position = function() return file:seek() end,
		skip = function(offset) file:seek('cur', offset) end
	}
	
	-- try ID3v2
	file:seek('set', 0)
	local header = file:read(3)
	if header == "ID3" then
		return decodeID3v2(reader)
	end
	
	-- try ID3v1
	file:seek('end', -128)
	header = file:read(3)
	if header == "TAG" then
		return decodeID3v1(reader)
	end
end

function id3.readtags_data(data)
	-- Simulated file handle
	local sfh = {pos = 0, data = data}
	function sfh:seek(whence, offset)
		offset = offset or 0
		
		if whence == "set" then
			self.pos = offset + 0
		elseif whence == "cur" then
			self.pos = offset + self.pos
		elseif whence == "end" then
			self.pos = offset + #self.data-1
		end
		return self.pos
	end
	function sfh:read(bytes)
		local subData = string.sub(self.data, self.pos+1, self.pos+1+bytes-1)
		self.pos = self.pos + bytes
		return subData
	end
	
	return id3.readtags(sfh)
end