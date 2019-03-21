local log = require("groupbutler.logging")

local User = {}

local function p(self)
	return getmetatable(self).__private
end

function User:new(obj, private)
	assert(obj.id or obj.username, "User: Missing obj.id or obj.username")
	assert(private.api, "User: Missing private.api")
	assert(private.db, "User: Missing private.db")
	setmetatable(obj, {
		__index = function(s, index)
			if self[index] then
				return self[index]
			end
			return s:getProperty(index)
		end,
		__private = private,
		__tostring = self.__tostring,
	})
	if not obj:checkId() then
		return nil, "Username not found"
	end
	return obj
end

function User:checkId()
	local username = rawget(self, "username")
	if  username
	and username:byte(1) == string.byte("@") then
		self.username = username:sub(2)
	end
	local id = rawget(self, "id")
	if not id then
		id = p(self).db:getUserId(self.username)
		self.id = id
		if not id then
			return false -- No cached id for this username
		end
		local user = p(self).api:getChat(id)
		if not user -- Api call failed
		or not user.username then -- User removed their username
			return true -- Assuming it's the same user
		end
		if self.username ~= user.username then -- Got a different user than expected
			User:new(user, p(self)):cache() -- Update cache with the different user so this doesn't happen again
			return false
		end
	end
	return true
end

function User:getProperty(index)
	local property = rawget(self, index)
	if property == nil then
		property = p(self).db:getUserProperty(self, index)
		if property == nil then
			local ok = p(self).api:getChat(self.id)
			if not ok then
				log.warn("User: Failed to get {property} for {id}", {
					property = index,
					id = self.id,
				})
				return nil
			end
			for k,v in pairs(ok) do
				self[k] = v
			end
			self:cache()
			property = rawget(self, index)
		end
		self[index] = property
	end
	return property
end

function User:__tostring()
	if self.first_name then
		if self.last_name then
			return self.first_name.." "..self.last_name
		end
		return self.first_name
	end
	if self.username then
		return self.username
	end
	return self.id
end

function User:cache()
	p(self).db:cacheUser(self)
end

function User:getLink()
	return ('<a href="tg://user?id=%s">%s</a>'):format(self.id, tostring(self):escape_html())
end

return User
