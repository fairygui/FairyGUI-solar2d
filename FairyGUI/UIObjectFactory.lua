UIObjectFactory = class('UIObjectFactory')

local _nameToType = {
	[ObjectType.Image] = GImage,
	[ObjectType.MovieClip] = GMovieClip,
	[ObjectType.Graph] = GGraph,
	[ObjectType.Group] = GGroup,
	[ObjectType.Loader] = GLoader,
	[ObjectType.Text] = GTextField,
	[ObjectType.RichText] = GRichTextField,
	[ObjectType.InputText] = GTextInput,
	[ObjectType.Component] = GComponent,
	[ObjectType.List] = GList,
	[ObjectType.Label] = GLabel,
	[ObjectType.Button] = GButton,
	[ObjectType.ComboBox] = GComboBox,
	[ObjectType.ProgressBar] = GProgressBar,
	[ObjectType.Slider] = GSlider,
	[ObjectType.ScrollBar] = GScrollBar
}

local _extensions = {}

function UIObjectFactory.setExtension(url, type)
	assert(url~=nil and string.len(url)>0, "invalid url")

	local pi = UIPackage.getItemByURL(url)
	if pi then pi.extension = type end
	_extensions[url] = type
end

function UIObjectFactory.resolveExtension(item)
	local e = _extensions["ui://"..item.owner.id..item.id]
	if e==nil then
		e =  _extensions["ui://"..item.owner.name..'/'..item.name]
	end
	item.extension = e
end

function UIObjectFactory.newObject(item)
	if item.extension then
		return item.extension.new()
	else
		return UIObjectFactory.newObject2(item.objectType)
	end
end

function UIObjectFactory.newObject2(objectType)
	return _nameToType[objectType].new()
end