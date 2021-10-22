local EventDispatcher = require('Event.EventDispatcher')
local TreeNode = require( "Tree.TreeNode")
local TreeView = class("TreeView", EventDispatcher)

local getters = TreeView.getters
local setters = TreeView.setters

function TreeView:ctor(list)
	EventDispatcher.ctor(self)

	self.list = list
	self.list:on("clickItem", self._clickItem, self)
	self.list:removeChildrenToPool()

	self.root = TreeNode.new(true)
	self.root:setTree(self)
	self.root.cell = list
	self.root.expanded = true

	self.indent = 30
end

function TreeView:getSelectedNode()
	if self.list.selectedIndex ~= -1 then
		return self.list:getChildAt(list.selectedIndex).data
	end
end

function TreeView:getSelection()
	local sels = self.list.getSelection()
	local cnt = #sels
	local ret = {}
	for i=1,cnt do
		local node = self.list:getChildAt(sels[i]).data
		table.insert(ret, node)
	end
	return ret
end

function TreeView:addSelection(node, scrollItToView)
	local parentNode = node.parent
	while parentNode and parentNode ~= self.root do
		parentNode.expanded = true
		parentNode = parentNode.parent
	end
	self.list:addSelection(self.list:getChildIndex(node.cell), scrollItToView)
end

function TreeView:removeSelection(node)
	self.list:removeSelection(self.list:getChildIndex(node.cell))
end

function TreeView:clearSelection()
	self.list:clearSelection()
end

function TreeView:getNodeIndex(node)
	return self.list:getChildIndex(node.cell)
end

function TreeView:updateNode(node)
	if not node.cell then
		return
	end

	if self.treeNodeRender then
		self.treeNodeRender(node)
	end
end

function TreeView:updateNodes(nodes)
	local cnt = #nodes
	for i=1,cnt do
		local node = nodes[i]
		if node.cell then
			if self.treeNodeRender then
				self.treeNodeRender(node)
			end
		end
	end
end

function TreeView:expandAll(folderNode)
	folderNode.expanded = true
	local cnt = folderNode.numChildren
	for i=0,cnt-1 do
		local node = folderNode:getChildAt(i)
		if node.isFolder then
			self:expandAll(node)
		end
	end
end

function TreeView:collapseAll(folderNode)
	if folderNode ~= self.root then
		folderNode.expanded = false
	end
	local cnt = folderNode.numChildren
	for i=0,cnt-1 do
		local node = folderNode:getChildAt(i)
		if node.isFolder then
			node:collapseAll(node)
		end
	end
end

function TreeView:createCell(node)
	if self.treeNodeCreateCell then
		node.cell = self.treeNodeCreateCell(node)
	else
		node.cell = self.list.itemPool:getObject(self.list.defaultItem)
	end
	assert(node.cell, "Unable to create tree cell")
	node.cell.data = node

	local indentObj = node.cell:getChild("indent")
	if indentObj then
		indentObj.width = (node.level - 1) * self.indent
	end

	local expandButton = node.cell:getChild("expandButton")
	if expandButton then
		if node.isFolder then
			expandButton.visible = true
			expandButton:onClick(self._clickExpandButton, self)
			expandButton.data = node
			expandButton.selected = node.expanded
		else
			expandButton.visible = false
		end
	end

	if self.treeNodeRender then
		self.treeNodeRender(node)
	end
end

function TreeView:afterInserted(node)
	self:createCell(node)

	local index = self:getInsertIndexForNode(node)
	self.list:addChildAt(node.cell, index)
	if self.treeNodeRender then
		self.treeNodeRender(node)
	end

	if node.isFolder and node.expanded then
		self:checkChildren(node, index)
	end
end

function TreeView:getInsertIndexForNode(node)
	local prevNode = node:getPrevSibling()
	if not prevNode then
		prevNode = node.parent
	end
	local insertIndex = self.list:getChildIndex(prevNode.cell) + 1
	local myLevel = node.level
	local cnt = self.list.numChildren
	for i=insertIndex,cnt-1 do
		local testNode = self.list:getChildAt(i).data
		if testNode.level <= myLevel then
			break
		end

		insertIndex = insertIndex + 1
	end

	return insertIndex
end

function TreeView:afterRemoved(node)
	self:removeNode(node)
end

function TreeView:afterExpanded(node)
	if node ~= self.root and self.treeNodeWillExpand then
		self.treeNodeWillExpand(node, true)
	end

	if not node.cell then
		return
	end

	if node ~= self.root then
		if self.treeNodeRender then
			self.treeNodeRender(node)
		end

		local expandButton = node.cell:getChild("expandButton")
		if expandButton then
			expandButton.selected = true
		end
	end

	if node.cell.parent then
		self:checkChildren(node, self.list:getChildIndex(node.cell))
	end
end

function TreeView:afterCollapsed(node)
	if node ~= self.root and self.treeNodeWillExpand then
		self.treeNodeWillExpand(node, false)
	end

	if not node.cell then
		return
	end

	if node ~= self.root then
		if self.treeNodeRender then
			self.treeNodeRender(node)
		end

		local expandButton = node.cell:getChild("expandButton")
		if expandButton then
			expandButton.selected = false
		end
	end

	if node.cell.parent then
		self:hideFolderNode(node)
	end
end

function TreeView:afterMoved(node)
	if not node.isFolder then
		self.list:removeChild(node.cell)
	else
		self:hideFolderNode(node)
	end

	local index = self:getInsertIndexForNode(node)
	self.list:addChildAt(node.cell, index)

	if node.isFolder and node.expanded then
		self:checkChildren(node, index)
	end
end

function TreeView:checkChildren(folderNode, index)
	local cnt = folderNode.numChildren
	for i=0,cnt-1 do
		index = index+1
		local node = folderNode:getChildAt(i)
		if not node.cell then
			self:createCell(node)
		end

		if not node.cell.parent then
			self.list:addChildAt(node.cell, index)
		end

		if node.isFolder and node.expanded then
			index = self:checkChildren(node, index)
		end
	end

	return index
end

function TreeView:hideFolderNode(folderNode)
	local cnt = folderNode.numChildren
	for i=0,cnt-1 do
		local node = folderNode:getChildAt(i)
		if node.cell then
			if node.cell.parent then
				self.list:removeChild(node.cell)
			end
			self.list.itemPool:returnObject(node.cell)
			node.cell.data = nil
			node.cell = nil
		end
		if node.isFolder and node.expanded then
			self:hideFolderNode(node)
		end
	end
end

function TreeView:removeNode(node)
	if node.cell then
		if node.cell.parent then
			self.list:removeChild(node.cell)
		end
		list.itemPool:returnObject(node.cell)
		node.cell.data = nil
		node.cell = nil
	end

	if node.isFolder then
		local cnt = node.numChildren
		for i = 0,cnt-1 do
			local node2 = node:getChildAt(i)
			self:removeNode(node2)
		end
	end
end

function TreeView:_clickExpandButton(context)
	context:stopPropagation()

	local expandButton = context.sender
	local node = expandButton.parent.data
	if self.list.scrollPane then
		local posY = self.list.scrollPane.posY
		if expandButton.selected then
			node.expanded = true
		else
			node.expanded = false
		end
		self.list.scrollPane.posY = posY
		self.list.scrollPane:scrollToView(node.cell)
	else
		if expandButton.selected then
			node.expanded = true
		else
			node.expanded = false
		end
	end
end

function TreeView:_clickItem(context)
	local posY = 0
	if self.list.scrollPane then
		posY = self.list.scrollPane.posY
	end

	local node = context.data.data
	self:emit("clickNode", node)

	if self.list.scrollPane then
		self.list.scrollPane.posY = posY
		self.list.scrollPane:scrollToView(node.cell)
	end
end

return TreeView