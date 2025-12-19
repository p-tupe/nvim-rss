-- Copyright 2009 Leo Ponomarev. Distributed under the BSD Licence.
-- updated for module-free world of lua 5.3 on April 2 2015
-- Not documented at all, but not interesting enough to warrant documentation anyway.
local setmetatable, pairs, ipairs, type, getmetatable, tostring, error =
	setmetatable, pairs, ipairs, type, getmetatable, tostring, error
local table, string = table, string

local XMLElement = {}

local mt

XMLElement.new = function(lom)
	return setmetatable({ lom = lom or {} }, mt)
end

local function filter(filtery_thing, lom)
	filtery_thing = filtery_thing or "*"
	for i, thing in ipairs(type(filtery_thing) == "table" and filtery_thing or { filtery_thing }) do
		if thing == "text()" then
			if type(lom) == "string" then
				return true
			end
		elseif thing == "*" then
			if type(lom) == "table" then
				return true
			end
		else
			if type(lom) == "table" and lom.type == "element" and string.lower(lom.name) == string.lower(thing) then
				return true
			end
		end
	end
	return nil
end

mt = {
	__index = {
		getAttr = function(self, attribute)
			if type(attribute) ~= "string" then
				return nil, "attribute name must be a string."
			end
			if not self.lom.attr then
				return nil
			end
			return self.lom.attr[attribute]
		end,

		setAttr = function(self, attribute, value)
			if type(attribute) ~= "string" then
				return nil, "attribute name must be a string."
			end
			if value == nil then
				return self:removeAttr(attribute)
			end
			self.lom.attr[attribute] = tostring(value)
			return self
		end,

		removeAttr = function(self, attribute)
			local lom = self.lom
			if type(attribute) ~= "string" then
				return nil, "attribute name must be a string."
			end
			if not lom.attr[attribute] then
				return self
			end
			for i, v in ipairs(lom.attr) do
				if v == attribute then
					table.remove(lom.attr, i)
					break
				end
			end
			lom.attr[attribute] = nil
		end,

		removeAllAttributes = function(self)
			local attr = self.lom.attr
			for i, v in pairs(self.lom.attr) do
				attr[i] = nil
			end
			return self
		end,

		getAttributes = function(self)
			local attr = {}
			for i, v in ipairs(self.lom.attr) do
				table.insert(attr, v)
			end
			return attr
		end,

		getXML = function(self)
			local function getXML(lom)
				local attr, inner = {}, {}
				for i, attribute in ipairs(lom.attr) do
					table.insert(attr, string.format("%s=%q", attribute, lom.attr[attribute]))
				end
				for i, v in ipairs(lom.kids or {}) do
					if type(v) == "table" then
						if v.type == "text" then
							table.insert(inner, v.value)
						elseif v.type == "element" then
							table.insert(inner, getXML(v))
						end
					end
				end
				local tagcontents = table.concat(inner)
				local attrstring = #attr > 0 and (" " .. table.concat(attr, " ")) or ""
				if #tagcontents > 0 then
					return string.format("<%s%s>%s</%s>", lom.name, attrstring, tagcontents, lom.name)
				else
					return string.format("<%s%s />", lom.name, attrstring)
				end
			end
			return getXML(self.lom)
		end,

		getText = function(self)
			local function getText(lom)
				local inner = {}
				for i, v in ipairs(lom.kids or {}) do
					if type(v) == "table" then
						if v.type == "text" then
							table.insert(inner, v.value)
						elseif v.type == "element" then
							table.insert(inner, getText(v))
						end
					end
				end
				return table.concat(inner)
			end
			return getText(self.lom)
		end,

		getChildren = function(self, filter_thing)
			local res = {}
			for i, node in ipairs(self.lom.kids or {}) do
				if filter(filter_thing, node) then
					if type(node) == "table" and node.type == "text" then
						if filter_thing == "text()" then
							table.insert(res, node.value)
						end
					else
						table.insert(res, type(node) == "table" and XMLElement.new(node) or node)
					end
				end
			end
			return res
		end,

		getDescendants = function(self, filter_thing)
			local res = {}
			local function descendants(lom)
				for i, child in ipairs(lom.kids or {}) do
					if filter(filter_thing, child) then
						if type(child) == "table" and child.type == "text" then
							if filter_thing == "text()" then
								table.insert(res, child.value)
							end
						else
							table.insert(res, type(child) == "table" and XMLElement.new(child) or child)
							if type(child) == "table" and child.type == "element" then
								descendants(child)
							end
						end
					end
				end
			end
			descendants(self.lom)
			return res
		end,

		getChild = function(self, filter_thing)
			for i, node in ipairs(self.lom.kids or {}) do
				if filter(filter_thing, node) then
					if type(node) == "table" and node.type == "text" then
						return filter_thing == "text()" and node.value or nil
					end
					return type(node) == "table" and XMLElement.new(node) or node
				end
			end
		end,

		getTag = function(self)
			return self.lom.name
		end,
	},
}

return XMLElement
