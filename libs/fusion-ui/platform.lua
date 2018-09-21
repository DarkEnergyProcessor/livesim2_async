-- Platform-agnostic functions
-- Functions in here can be modified by user
-- when needed (example: porting to newer version of LOVE)

local love = require("love")
local platform = {}

-- fusion-ui expects all these functions to have 0.10.0 behavior
platform.newImage = love.graphics.newImage
platform.getFont = love.graphics.getFont
platform.rectangle = love.graphics.rectangle
platform.stencil = love.graphics.stencil
platform.setStencilTest = love.graphics.setStencilTest
platform.setColor = love.graphics.setColor
platform.draw = love.graphics.draw
platform.line = love.graphics.line
platform.setCanvas = love.graphics.setCanvas
platform.clear = love.graphics.clear
platform.newCanvas = love.graphics.newCanvas
platform.newText = love.graphics.newText
platform.setFont = love.graphics.setFont
platform.print = love.graphics.print
platform.setBlendMode = love.graphics.setBlendMode
platform.getBlendMode = love.graphics.getBlendMode

return platform
