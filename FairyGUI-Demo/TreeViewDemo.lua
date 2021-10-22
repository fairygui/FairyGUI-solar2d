local TreeView = require( "Tree.TreeView")
local TreeNode = require( "Tree.TreeNode")

local composer = require( "composer" )

local scene = composer.newScene()

local _groot
local _view

local _folderURL1
local _folderURL2
local _fileURL
local _treeView

function scene:create( event )
	_groot = GRoot.create(self)

	UIPackage.addPackage('UI/TreeView')

	composer.addCloseButton()

	_view = UIPackage.createObject("TreeView", "Main")
	_view:makeFullScreen()
	_groot:addChild(_view)

	_folderURL1 = "ui://TreeView/folder_closed"
	_folderURL2 = "ui://TreeView/folder_opened"
	_fileURL = "ui://TreeView/file"

	_treeView = TreeView.new(_view:getChild("tree"))
	_treeView:on("clickNode", scene._clickNode)
	_treeView.treeNodeRender = scene.renderTreeNode
	--_treeView.treeNodeCreateCell = 
	--_treeView.treeNodeWillExpand = 

	local topNode = TreeNode.new(true)
	topNode.data = "I'm a top node"
	_treeView.root:addChild(topNode)

	for i=1,5 do
		local node = TreeNode.new()
		node.data = "Hello "..i
		topNode:addChild(node)
	end

	local aFolderNode = TreeNode.new(true)
	aFolderNode.data = "A folder node"
	topNode:addChild(aFolderNode)
	for i=1,5 do
		local node = TreeNode.new()
		node.data = "Good "..i
		aFolderNode:addChild(node)
	end

	for i=1,3 do
		local node = TreeNode.new()
		node.data = "World "..i
		topNode:addChild(node)
	end

	local anotherTopNode = TreeNode.new()
	anotherTopNode.data = { "I'm a top node too", "ui://TreeView/heart" }
	_treeView.root:addChild(anotherTopNode)
end

function scene.renderTreeNode(node)
	local btn = node.cell
	if node.isFolder then
		if node.expanded then
			btn.icon = _folderURL2
		else
			btn.icon = _folderURL1
		end
		btn.title = node.data
	elseif type(node.data)=='table' then
		btn.icon = node.data[2]
		btn.title = node.data[1]
	else
		btn.icon = _fileURL
		btn.title = node.data
	end
end

function scene._clickNode(context)
	local node = context.data
	if node.isFolder and context.inputEvent.numTaps==2 then
		node.expanded = not node.expanded
	end
end

function scene:destroy( event )
	_groot:dispose()
	UIPackage.removePackage('TreeView')
end

scene:addEventListener( "create", scene )
scene:addEventListener( "destroy", scene )

return scene