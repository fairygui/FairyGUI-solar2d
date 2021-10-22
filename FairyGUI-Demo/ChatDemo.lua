local composer = require( "composer" )
local UBBParser = require( "Utils.UBBParser" )

local scene = composer.newScene()

local _groot
local _view

local _messages
local _emojiParser
local _list
local _input
local _emojiSelectUI

local EmojiParser = class('EmojiParser', UBBParser)

function EmojiParser:ctor()
	UBBParser.ctor(self)

	local TAGS = {"88", "am", "bs", "bz", "ch", "cool", "dhq", "dn", "fd", "gz", "han", "hx", "hxiao", "hxiu"}
	for i, v in ipairs(TAGS) do
		self.handlers[':'..v] = self.onTag_Emoji
	end
end

function EmojiParser:onTag_Emoji(tagName, ends, attr)
	return "<img src='"..UIPackage.getItemURL("Chat", string.lower(string.sub(tagName,2))).."'/>"
end

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/Chat')

	composer.addCloseButton()

	_view = UIPackage.createObject("Chat", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_messages = {}
	_emojiParser = EmojiParser.new()

	_list = _view:getChild("list")
	_list:setVirtual()
	_list.itemProvider = scene.getListItemResource
	_list.itemRenderer = scene.renderListItem

	_input = _view:getChild("input1")
	_input:on("submit", self.onSubmit, self)

	_view:getChild("btnSend1"):onClick(scene.onClickSendBtn)
	_view:getChild("btnEmoji1"):onClick(scene.onClickEmojiBtn)

	_emojiSelectUI = UIPackage.createObject("Chat", "EmojiSelectUI")
	_emojiSelectUI:getChild("list"):on("clickItem", scene.onClickEmoji)
end

function scene.addMsg(sender, senderIcon, msg, fromMe)
	local isScrollBottom = _list.scrollPane.isBottomMost

	local newMessage = {}
	newMessage.sender = sender
	newMessage.senderIcon = senderIcon
	newMessage.msg = msg
	newMessage.fromMe = fromMe
	table.insert(_messages, newMessage)

	if newMessage.fromMe then
		if #_messages == 1 or math.random() < 0.5 then
			local replyMessage = {}
			replyMessage.sender = "FairyGUI"
			replyMessage.senderIcon = "r1"
			replyMessage.msg = "Today is a good day. [:gz]"
			replyMessage.fromMe = false
			table.insert(_messages, replyMessage)
		end
	end

	if #_messages > 100 then
		while #_messages>100 do
			table.remove(_messages, 1)
		end
	end

	_list.numItems = #_messages

	if isScrollBottom then
		_list.scrollPane:scrollBottom()
	end
end

function scene.getListItemResource(index)
	local msg = _messages[index+1]
	if msg.fromMe then
		return "ui://Chat/chatRight"
	else
		return "ui://Chat/chatLeft"
	end
end

function scene.renderListItem(index, item)
	local msg = _messages[index+1]
	if not msg.fromMe then
		item:getChild("name").text = msg.sender
	end
	item.icon = UIPackage.getItemURL("Chat", msg.senderIcon)
	item:getChild("msg").text = _emojiParser:parse(msg.msg)
end

function scene.onClickSendBtn()
	local msg = _input.text
	if #msg==0 then
		return
	end

	scene.addMsg("Creator", "r0", msg, true)
	_input.text = ""
end

function scene.onClickEmojiBtn(context)
	_groot:showPopup(_emojiSelectUI, context.sender, false)
end

function scene.onClickEmoji(context)
	local item  = context.data
	_input.text = _input.text .. "[:"..item.text.."]"
	_input:requestFocus()
end

function scene.onSubmit()
	scene.onClickSendBtn()
end

function scene:destroy( event )
	_emojiSelectUI:dispose()
	_groot:dispose()
	UIPackage.removePackage('Chat')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene