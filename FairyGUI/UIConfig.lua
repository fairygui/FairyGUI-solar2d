UIConfig = {
	defaultFont = 'Arial',

	buttonSound = '',
	buttonSoundVolumeScale = 1,

	modalLayerColor = 0x333333,
	modalLayerAlpha = 0.3,

	defaultScrollStep = 25,
	defaultScrollDecelerationRate = 0.967,
	defaultScrollBarDisplay = ScrollBarDisplayType.Default,
	defaultScrollTouchEffect = true,
	defaultScrollBounceEffect = true,
	defaultComboBoxVisibleItemCount = 10,
	touchScrollSensitivity = 20,
	touchDragSensitivity = 10,
	clickDragSensitivity = 2,
	bringWindowToFrontOnClick = true,
	frameTimeForAsyncUIConstruction = 0.002,
	richTextRowVerticalAlign = VertAlignType.Bottom,

	--globalModalWaiting = nil
	--horizontalScrollBar = nil
	--loaderErrorSign = nil
	--popupMenu = nil
	--popupMenu_seperator = nil
	--tooltipsWin = nil
	--verticalScrollBar = nil
	--windowModalWaiting = nil

	fontRegistry = {}
}

function UIConfig.registerFont(name, ttfFile)
	UIConfig.fontRegistry[name] = ttfFile
end
