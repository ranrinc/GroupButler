local config = require "groupbutler.config"
local null = require "groupbutler.null"
local Chat = require("groupbutler.chat")
local ChatMember = require("groupbutler.chatmember")

local _M = {}

function _M:new(update_obj)
	local plugin_obj = {}
	setmetatable(plugin_obj, {__index = self})
	for k, v in pairs(update_obj) do
		plugin_obj[k] = v
	end
	return plugin_obj
end

local function toggle_permissions_setting(self, chat_id, key)
	local red = self.red
	local hash = 'chat:'..chat_id..':defpermissions'
	local current = red:hget(hash, key)
	if current == null then current = config.chat_settings['defpermissions'][key] end

	local new = "true"
	if current == 'true' then
		new = 'false'
	end

	local new_perm = {[key] = new}

	if new == 'true' then
		if key == 'can_send_media_messages' then
			new_perm['can_send_messages'] = 'true'
		elseif key == 'can_send_other_messages' then
			new_perm['can_send_messages'] = 'true'
			new_perm['can_send_media_messages'] = 'true'
		elseif key == 'can_add_web_page_previews' then
			new_perm['can_send_messages'] = 'true'
			new_perm['can_send_media_messages'] = 'true'
		end
	elseif new == 'false' then
		if key == 'can_send_messages' then
			new_perm['can_send_other_messages'] = 'false'
			new_perm['can_send_media_messages'] = 'false'
			new_perm['can_add_web_page_previews'] = 'false'
		elseif key == 'can_send_media_messages' then
			new_perm['can_send_other_messages'] = 'false'
			new_perm['can_add_web_page_previews'] = 'false'
		end
	end

	red:hmset(hash, new_perm)

	return '✅'
end

local function set_default(t, d)
	local mt = {__index = function() return d end}
	setmetatable(t, mt)
end

local function get_alert_text(self, key)
	local i18n = self.i18n
	local alert_text = {
		can_send_messages = i18n("Permission to send messages. If disabled, the user won't be able to send any kind of message"), -- luacheck: ignore 631
		can_send_media_messages = i18n("Permission to send media (audios, documents, photos, videos, video notes and voice notes). Implies the permission to send messages"), -- luacheck: ignore 631
		can_send_other_messages = i18n("Permission to send other types of messages (GIFs, games, stickers and use inline bots). Implies the permission to send medias"), -- luacheck: ignore 631
		can_add_web_page_previews = i18n("When disabled, user's messages with a link won't show the web page preview"),
	} set_default(alert_text, i18n("Description not available"))

	return alert_text[key]
end

local function humanizations(self)
	local i18n = self.i18n
	return {
		['can_send_messages'] = i18n('Send messages'),
		['can_send_media_messages'] = i18n('Send media'),
		['can_send_other_messages'] = i18n('Send other types of media'),
		['can_add_web_page_previews'] = i18n('Show web page preview'),
	}
end

local permissions =
{'can_send_messages', 'can_send_media_messages', 'can_send_other_messages', 'can_add_web_page_previews'}

local function doKeyboard_permissions(self, chat_id)
	local red = self.red
	local keyboard = {inline_keyboard = {}}

	local line, status, icon, permission
	--for field, value in pairs(config.chat_settings['defpermissions']) do
	for i=1, #permissions do --pairs() doesn't keep the order of the keys
		permission = permissions[i]
		icon = '✅'
		status = red:hget('chat:'..chat_id..':defpermissions', permission)
		if status == null then status = config.chat_settings['defpermissions'][permission] end

		if status == 'false' then icon = '☑️' end
		line = {
			{
				text = humanizations(self)[permission] or permission,
				callback_data = 'defpermissions:alert:'..permission
			},
			{
				text = icon,
				callback_data = 'defpermissions:toggle:'..permission..':'..chat_id
			}
		}
		table.insert(keyboard.inline_keyboard, line)
	end

	--back button
	table.insert(keyboard.inline_keyboard, {{text = '🔙', callback_data = 'config:back:'..chat_id}})

	return keyboard
end

function _M:onCallbackQuery(blocks)
	local api = self.api
	local msg = self.message
	local i18n = self.i18n

	if blocks[1] == 'alert' then
		local text = get_alert_text(self, blocks[2])
		api:answerCallbackQuery(msg.cb_id, text, true, config.bot_settings.cache_time.alert_help)
		return
	end

	local member = ChatMember:new({
		chat = Chat:new({id=msg.target_id}, self),
		user = msg.from.user,
	}, self)

	if not member:can("can_restrict_members") then
		api:answerCallbackQuery(msg.cb_id, i18n("Sorry, you don't have permission to restrict members"))
		return
	end

	local msg_text = i18n([[*Default permissions*
From this menu you can change the default permissions that will be granted when a new member join.
_Only the administrators with the permission to restrict a member can access this menu._
Tap on the name of a permission for a description of what kind of messages it will influence.
]])

	local reply_markup, popup_text, show_alert

	if blocks[1] == 'toggle' then
		popup_text = toggle_permissions_setting(self, member.chat.id, blocks[2])
	end

	reply_markup = doKeyboard_permissions(self, member.chat.id)
	local ok, err
	if blocks[2] then
		--if the user tapped on a keybord button, just edit the markup and not the whole message
		ok, err = api:editMessageReplyMarkup(msg.from.chat.id, msg.message_id, nil, reply_markup)
	else
		ok, err = api:editMessageText(msg.from.chat.id, msg.message_id, nil, msg_text, "Markdown", nil, reply_markup)
	end

	if not ok and err.retry_after then
		popup_text = i18n("Setting saved, but I can't edit the buttons because you are too fast! Wait other %d seconds")
			:format(err.retry_after)
		show_alert = true
	end
	if popup_text then
		api:answerCallbackQuery(msg.cb_id, popup_text, show_alert)
	end
end

_M.triggers = {
	onCallbackQuery = {
		'^###cb:config:defpermissions:(-%d+)$',
		'^###cb:defpermissions:(toggle):([%w_]+):(-%d+)$',
		'^###cb:defpermissions:(alert):([%w_]+):([%w_]+)$',
	}
}

return _M
