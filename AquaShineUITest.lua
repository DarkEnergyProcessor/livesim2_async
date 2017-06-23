-- Test AquaShine.UI
local TestUI = {}
local AquaShine = AquaShine

-- All UI collections must be in "World"
local UIWorld = AquaShine.UI.NewWorld()

-- "UIObject" is base class of all AquaShine UIs
local EmptyObject = AquaShine.UI.NewObject(10, 10, 300, 300)
-- "UIImage" allows dynamic and static image
-- Custom base position (gravity) is supported with these suffix: ([t]op, [l]eft, [b]ottom, [r]ight, [c]enter)
local ImageObject = AquaShine.UI.NewImage(AquaShine.LoadImage("assets/image/background/liveback_1.png"), "960r", "640b")
-- "UIText" allows text to be rendered to screen. UIText is ignored from all callbacks
-- "relative" positioning is also allowed with these prefix: ([T]op, [L]eft, [B]ottom, [R]ight, [C]enter)
local TextObject = AquaShine.UI.NewText(AquaShine.LoadFont("MTLmr3m.ttf", 24), "Hello World!", "L25l", "T10", 1)
local TextObject2 = AquaShine.UI.NewText(AquaShine.LoadFont("MTLmr3m.ttf", 24), "Below Hello World! and without outline", "L0", "B0")
local TextObject3 = AquaShine.UI.NewText(AquaShine.LoadFont("MTLmr3m.ttf", 24), "X pos of above text and this text is relative to \"Hello World\" text", "L0", "B0", 1)

-- Insert to our new UIWorld. Order of the insertion is important!
UIWorld:Insert(EmptyObject)
	   :Insert(ImageObject)
	   :Insert(TextObject)	-- Notice what will happend if we change this order?
	   :Insert(TextObject2)
	   :Insert(TextObject3)

function TestUI.Start()
end

function TestUI.Update(deltaT)
	-- Update UI world. Necessary for animations
	-- UIWorld:Update(deltaT)
end

function TestUI.Draw()
	UIWorld:Draw()
end

function TestUI.Exit()
end

return TestUI
