local TreeNode = class("TreeNode")
local tools = require('Utils.ToolSet')

local getters = TreeNode.getters
local setters = TreeNode.setters

function TreeNode:ctor(hasChild)
	if hasChild then
		self._children = {}
		self._expanded = false
	end

	self.level = 0
end

function getters:expanded()
	return self._expanded
end

function setters:expanded(value)
	if not self._children then return end

	if self._expanded ~= value then
		self._expanded = value
		if self.tree then
			if self._expanded then
				self.tree:afterExpanded(self)
			else
				self.tree:afterCollapsed(self)
			end
		end
	end
end

function getters:isFolder()
	return self._children~=nil
end

function getters:text()
	if self.cell then
		return self.cell.text
	end
end

function TreeNode:addChild(child)
	self:addChildAt(child, #self._children)
	return child
end

function TreeNode:addChildAt(child, index)
	assert(child, "child is null")
	assert(index >= 0 and index <= self.numChildren, "Invalid child index: "..index..">"..self.numChildren)

	if child.parent == self then	
		self:setChildIndex(child, index)
	else
		if child.parent then
			child.parent:removeChild(child)
		end

		child.parent = self
		table.insert(self._children, index+1, child)
		child.level = self.level + 1
		child:setTree(self.tree)
		if self.cell and self.cell.parent and self._expanded then
			self.tree:afterInserted(child)
		end
	end
	return child
end

function TreeNode:removeChild(child)
	local childIndex = tools.indexOf(self._children, child)
	if childIndex ~= 0 then	
		self:removeChildAt(childIndex-1, dispose)
	end
	return child
end

function TreeNode:removeChildAt(index)
	assert(index >= 0 and index < self.numChildren, "Invalid child index: "..index..">"..self.numChildren)

	local child = self._children[index+1]
	child.parent = nil
	table.remove(self._children, index+1)

	if self.tree then
		child:setTree(nil)
		self.tree:AfterRemoved(child)
	end

	return child
end

function TreeNode:removeChildren(beginIndex, endIndex)
	beginIndex = beginIndex or 0
	endIndex = beginIndex or -1

	if endIndex < 0 or endIndex >= self.numChildren then
		endIndex = self.numChildren - 1
	end

	for i = beginIndex,endIndex do
		self:removeChildAt(beginIndex, dispose)
	end
end

function TreeNode:getChildAt(index)
	assert(index >= 0 and index < self.numChildren, "Invalid child index: "..index..">"..self.numChildren)
	return self._children[index+1]
end

function TreeNode:getChildIndex(child)
	local cnt = #self._children
	for i=1,cnt do	
		if self._children[i] == child then
			return i-1
		end
	end

	return -1
end

function TreeNode:getPrevSibling()
	if not self.parent then
		return
	end

	local i = self.parent:getChildIndex(self)
	if i <= 0 then
		return
	end

	return self.parent:getChildAt(i-1)
end

function TreeNode:getNextSibling()
	if not self.parent then
		return
	end

	local i = self.parent:getChildIndex(self)
	if i < 0 or i>=self.parent.numChildren then
		return
	end

	return self.parent:getChildAt(i+1)
end

function TreeNode:setChildIndex(child, index)
	local oldIndex = self:getChildIndex(child)
	assert(oldIndex ~= -1,  "Not a child of this container")

	local cnt = #self._children
	if index > cnt then index = cnt end

	if oldIndex == index then return oldIndex end

	table.remove(self._children, oldIndex+1)
	if index==cnt then
		table.insert(self._children, index, child)
	else
		table.insert(self._children, index+1, child)
	end

	if self.cell and self.cell.parent and self._expanded then
		self.tree:afterMoved(child)
	end
end

function TreeNode:swapChildren(child1, child2)
	local index1 = self:getChildIndex(child1)
	local index2 = self:getChildIndex(child2)
	assert(index1 ~= -1 and index2 ~= -1, "Not a child of this container")
	self:swapChildrenAt(index1, index2)
end

function TreeNode:swapChildrenAt(index1, index2)
	local child1 = self._children[index1+1]
	local child2 = self._children[index2+1]

	self:setChildIndex(child1, index2)
	self:setChildIndex(child2, index1)
end

function getters:numChildren()
	return self._children and #self._children or 0
end

function TreeNode:setTree(value)
	self.tree = value
	if value and value.treeNodeWillExpand and self._expanded then
		value.treeNodeWillExpand(self, true)
	end

	if self._children then
		local cnt = #self._children
		for i=1,cnt do
			local node = self._children[i]
			node.level = self.level + 1
			node:setTree(value)
		end
	end
end

return TreeNode