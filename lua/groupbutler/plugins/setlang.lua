local config = require "groupbutler.config"

local _M = {}

function _M:new(update_obj)
	local plugin_obj = {}
	setmetatable(plugin_obj, {__index = self})
	for k, v in pairs(update_obj) do
		plugin_obj[k] = v
	end
	return plugin_obj
end

local function doKeyboard_lang()
	local keyboard = {
		inline_keyboard = {}
	}
	for lang, flag in pairs(config.available_languages) do
		local line = {{text = flag, callback_data = 'langselected:'..lang}}
		table.insert(keyboard.inline_keyboard, line)
	end
	return keyboard
end

function _M:onTextMessage()
	local api = self.api
	local msg = self.message
	local i18n = self.i18n

	if msg.from.chat.type == "private"
	or msg.from:can("can_change_info") then
		local keyboard = doKeyboard_lang()
		api:sendMessage(msg.from.chat.id, i18n("*List of available languages*:"), "Markdown", nil, nil, nil, keyboard)
	end
end

function _M:onCallbackQuery(blocks)
	local api = self.api
	local msg = self.message
	local red = self.red
	local i18n = self.i18n

	if msg.from.chat.type ~= "private"
	and not msg.from:isAdmin() then
		api:answerCallbackQuery(msg.cb_id, i18n("Sorry, you don't have permission to change settings"))
		return
	end

	if blocks[1] == "selectlang" then
		local keyboard = doKeyboard_lang()
		api:editMessageText(msg.from.chat.id, msg.message_id, nil, i18n("*List of available languages*:"), "Markdown", nil,
			keyboard)
		return
	end

	i18n:setLanguage(blocks[1])
	red:set("lang:"..msg.from.chat.id, i18n:getLanguage())
	if msg.from.chat.type ~= "private"
	and (blocks[1] == "ar_SA" or blocks[1] == "fa_IR") then
		red:hset("chat:"..msg.from.chat.id..":char", "Arab", "allowed")
		red:hset("chat:"..msg.from.chat.id..":char", "Rtl", "allowed")
	end
	-- TRANSLATORS: replace 'English' with the name of your language
	api:editMessageText(msg.from.chat.id, msg.message_id, nil, i18n("English language is *set*")..i18n([[.
Please note that translators are volunteers, and this localization _may be incomplete_. You can help improve translations on our [Crowdin Project](https://crowdin.com/project/group-butler).
]]), "Markdown")
end

_M.triggers = {
	onTextMessage = {config.cmd..'(lang)$'},
	onCallbackQuery = {
		'^###cb:(selectlang)',
		'^###cb:langselected:(%l%l)$',
		'^###cb:langselected:(%l%l_%u%u)$'
	}
}

return _M
