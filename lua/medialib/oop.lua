local oop = medialib.module("oop")
oop.Classes = oop.Classes or {}

function oop.class(name, parent)
	local cls = oop.Classes[name]
	if not cls then
		cls = oop.createClass(name, parent)
		oop.Classes[name] = cls

		if medialib.DEBUG then
			print("[MediaLib] Registering oopclass " .. name)
		end
	end

	return cls
end

function oop.resolveClass(obj)
	if obj == nil then
		return oop.Object
	end

	local t = type(obj)
	if t == "string" then
		local clsobj = oop.Classes[obj]
		if clsobj then return clsobj end

		error("Resolving class from inexistent class string '" .. tostring(obj) .. "'")
	end
	if t == "table" then
		return obj
	end

	error("Resolving class from invalid object '" .. tostring(obj) .. "'")
end

-- This is a special parent used to prevent oop.Object being parent of itself
local NIL_PARENT = {}

-- Credits to Middleclass
local metamethods = {'__add', '__call', '__concat', '__div', '__ipairs', '__le',
					 '__len', '__lt', '__mod', '__mul', '__pairs', '__pow', '__sub',
					 '__tostring', '__unm'}

function oop.createClass(name, parent)
	local cls = {}

	-- Get parent class
	local par_cls
	if parent ~= NIL_PARENT then
		par_cls = oop.resolveClass(parent)
	end

	-- Add metadata
	cls.name = name
	cls.super = par_cls

	-- Add a subtable for class members ie methods and class/super handles
	cls.members = setmetatable({}, {__index = cls.super})

	-- Add built-in "keywords" that Instances can access
	cls.members.class = cls
	cls.members.super = cls.super

	-- Instance metatable
	local cls_instance_meta = {}
	do
		cls_instance_meta.__index = cls.members

		-- Add metamethods. The class does not have members yet, so we need to use runtime lookup
		for _,metaName in pairs(metamethods) do
			cls_instance_meta[metaName] = function(...)
				local method = cls.members[metaName]
				if method then
					return method(...)
				end
			end
		end
	end

	-- Class metatable
	local class_meta = {}
	do
		class_meta.__index = cls.members
		class_meta.__newindex = cls.members

		class_meta.__tostring = function(self)
			return "class " .. self.name
		end

		-- Make the Class object a constructor.
		-- ie calling Class() creates a new instance
		function class_meta:__call(...)
			local instance = {}
			setmetatable(instance, cls_instance_meta)

			-- Call constructor if exists
			local ctor = instance.initialize
			if ctor then ctor(instance, ...) end

			return instance
		end
	end

	-- Set meta functions
	setmetatable(cls, class_meta)

	return cls
end

oop.Object = oop.createClass("Object", NIL_PARENT)

-- Get the hash code ie the value Lua prints when you call __tostring()
function oop.Object:hashCode()
	local meta = getmetatable(self)

	local old_tostring = meta.__tostring
	meta.__tostring = nil

	local hash = tostring(self):match("table: 0x(.*)")

	meta.__tostring = old_tostring

	return hash
end

function oop.Object:__tostring()
	return string.format("%s@%s", self.class.name, self:hashCode())
end