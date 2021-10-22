-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
require 'strict'

package.path = package.path
	..';'..string.gsub(system.pathForFile('FairyGUI', system.ResourceDirectory),'\\', '/')..'/?.lua'
	..';'..string.gsub(system.pathForFile('FairyGUI-Demo', system.ResourceDirectory),'\\', '/')..'/?.lua'

require 'FairyGUI'

display.setStatusBar( display.HiddenStatusBar )

display.setDefault( "background", 0.2, 0.2, 0.2)
display.setDefault( "isAnchorClamped", false )

local composer = require( "composer" )

function composer.addCloseButton()
	local btn = UIPackage.createObject("MainMenu", "CloseButton")
	btn:setPosition(UIRoot.width - btn.width - 10, UIRoot.height - btn.height - 10)
	btn:addRelation(UIRoot, RelationType.Right_Right)
	btn:addRelation(UIRoot, RelationType.Bottom_Bottom)
	btn.sortingOrder = 100000
	btn:onClick(function()
		local sceneName = composer.getSceneName("current")
		composer.removeScene(sceneName)
		composer.gotoScene( "MainMenu" ) 
	end)
	UIRoot:addChild(btn)
end

composer.gotoScene( "MainMenu" )