---@class Gamestate.ConstructorInfo
---@field public fonts table<string,{[1]:string,[2]:integer}>
---@field public images table<string,{[1]:string,[2]:table?}>
local ConstructorInfo = {}

---@class IUpdateable
local IUpdateable = {}

---@param dt number
function IUpdateable:update(dt)
end

---@class IDrawable
local IDrawable = {}

function IDrawable:draw()
end

---@class Livesim2.SummaryInfo
---@field public audio string?
---@field public comboA integer
---@field public comboB integer
---@field public comboC integer
---@field public comboS integer?
---@field public coverArt {image:love.ImageData,title:string,info:string?}?
---@field public liveClear string?
---@field public lyrics love.Data?
---@field public name string
---@field public randomStar integer?
---@field public scoreA integer
---@field public scoreB integer
---@field public scoreC integer
---@field public scoreS integer?
---@field public scorePerTap number?
---@field public stamina integer?
---@field public star integer
local SummaryInfo = {}

---@class Livesim2.SrtParseData
---@field public start number
---@field public stop number
---@field public text1 string
---@field public text2 string?
local SrtParseData = {}
