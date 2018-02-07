local splashlib = {
  _VERSION     = "v1.2.0",
  _DESCRIPTION = "a 0.10.1 splash",
  _URL         = "https://github.com/love2d-community/splashes",
  _LICENSE     = [[Copyright (c) 2016 love-community members (as per git commits in repository above)

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgement in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

The font used in this splash is "Handy Andy" by www.andrzejgdula.com]]
}

local current_module = (...):gsub("%.init$", "")
local current_folder = current_module:gsub("%.", "/")

local timer = require(current_module .. ".timer")

local colors = {
  bg =     {108 / 255, 190 / 255, 228 / 255},
  white =  {1, 1, 1},
  blue =   { 39 / 255, 170 / 255, 225 / 255},
  pink =   {231 / 255,  74 / 255, 153 / 255},
  shadow = {0, 0, 0, 1/3}
}

-- patch shader:send if 'lighten' gets optimized away
local function safesend(shader, name, ...)
  if shader:hasUniform(name) then
    shader:send(name, ...)
  end
end

function splashlib.new(init)
  init = init or {}
  local self = {}
  local width, height = love.graphics.getDimensions()

  self.background = init.background == nil and colors.bg or init.background
  self.delay_before = init.delay_before or 0.3
  self.delay_after = init.delay_after or 0.7

  if init.fill == "rain" then
    local rain = {}
    rain.spacing_x = 110
    rain.spacing_y = 80
    rain.image = love.graphics.newImage("assets/image/splash/baby.png")
    rain.img_w = rain.image:getWidth()
    rain.img_h = rain.image:getHeight()
    rain.ox = -rain.img_w / 2
    rain.oy = -rain.img_h / 2
    rain.batch = love.graphics.newSpriteBatch(rain.image, 512)
    rain.t = 0

    local gradient = love.graphics.newMesh({
      {    0, height/4, 0, 0,  0, 0, 0,   0},
      {width, height/4, 0, 0,  0, 0, 0,   0},
      {width, height,   0, 0,  0, 0, 0, 200},
      {    0, height,   0, 0,  0, 0, 0, 200},
    }, "fan", "static")
    do
      local batch = rain.batch

      local sx = rain.spacing_x
      local sy = rain.spacing_y
      local ox = rain.ox
      local oy = rain.oy

      local batch_w = 2 * math.ceil(960 / sx) + 2
      local batch_h = 2 * math.ceil(640 / sy) + 2

      batch:clear()

      if batch:getBufferSize() < batch_w * batch_h then
        batch:setBufferSize(batch_w * batch_h)
      end

      for i = 0, batch_h - 1 do
        for j = 0, batch_w - 1 do
          local is_even = (j % 2) == 0
          local offset_y = is_even and 0 or sy / 2
          local x = ox + j * sx
          local y = oy + i * sy + offset_y
          batch:add(x, y)
        end
      end

      batch:flush()
    end

    function self.fill()
      local y = rain.spacing_y * select(2, math.modf(self.elapsed))

      local small_y = -rain.spacing_y + y / 2
      local big_y = -rain.spacing_y + y

      love.graphics.setBlendMode("subtract")
      love.graphics.setColor(255, 255, 255, 128)
      love.graphics.draw(rain.batch, -rain.spacing_x, small_y, 0, 0.5, 0.5)

      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(208, 208, 208, 255)
      love.graphics.draw(rain.batch, -rain.spacing_x, big_y)

      love.graphics.draw(gradient)
    end
  end

  -- radial mask shader
  self.maskshader = love.graphics.newShader((init.fill == "lighten" and "#define LIGHTEN" or "") .. [[

  extern number radius;
  extern number blur;
  extern number shadow;
  extern number lighten;

  vec4 desat(vec4 color) {
    number g = dot(vec3(.299, .587, .114), color.rgb);
    return vec4(g, g, g, 1.0) * lighten;
  }

  vec4 effect(vec4 global_color, Image canvas, vec2 tc, vec2 _)
  {
    // radial mask
    vec4 color = Texel(canvas, tc);
    number r = length((tc - vec2(.5)) * love_ScreenSize.xy);
    number s = smoothstep(radius+blur, radius-blur, r);
    #ifdef LIGHTEN
    color = color + desat(color) * (1.0-s);
    #else
    color.a *= s;
    #endif
    color.a *= global_color.a;

    // add shadow on lower diagonal along the circle
    number sr = 7. * (1. - smoothstep(-.1,.04,(1.-tc.x)-tc.y));
    s = (1. - pow(exp(-pow(radius-r, 2.) / sr),3.) * shadow);

    return color - vec4(1, 1, 1, 0) * (1.0-s);
  }
  ]])

  -- this shader makes the text appear from left to right
  self.textshader = love.graphics.newShader[[
  extern number alpha;

  vec4 effect(vec4 color, Image logo, vec2 tc, vec2 sc)
  {
    //Probably would be better to just use the texture's dimensions instead; faster reaction.
    vec2 sd = sc / love_ScreenSize.xy;

    if (sd.x <= alpha) {
      return color * Texel(logo, tc);
    }
    return vec4(0);
  }
  ]]

  -- this shader applies a stroke effect on the logo using a gradient mask
  self.logoshader = love.graphics.newShader[[
  //Using the pen extern, only draw out pixels that have their color below a certain treshold.
  //Since pen will eventually equal 1.0, the full logo will be drawn out.

  extern number pen;
  extern Image mask;

  vec4 effect(vec4 color, Image logo, vec2 tc, vec2 sc)
  {
    number value = max(Texel(mask, tc).r, max(Texel(mask, tc).g, Texel(mask, tc).b));
    number alpha = Texel(mask, tc).a;

    //probably could be optimzied...
    if (alpha > 0.0) {
      if (pen >= value) {
        return color * Texel(logo, tc);
      }
    }
    return vec4(0);
  }
  ]]

  self.canvas = love.graphics.newCanvas()

  self.elapsed = 0
  self.alpha = 1
  self.heart = {
    sprite = love.graphics.newImage("assets/image/splash/heart.png"),
    scale = 0,
    rot   = 0
  }

  self.stripes = {
    rot     = 0,
    height  = 100,
    offset  = -2 * width,
    radius  = math.max(width, height),
    lighten = 0,
    shadow  = 0,
  }

  self.text = {
    obj   = love.graphics.newText(love.graphics.newFont(current_folder .. "/handy-andy.otf", 22), "made with"),
    alpha = 0
  }
  self.text.width, self.text.height = self.text.obj:getDimensions()

  self.logo = {
    sprite = love.graphics.newImage("assets/image/splash/logo.png"),
    mask   = love.graphics.newImage("assets/image/splash/logo-mask.png"),
    pen    = 0
  }
  self.logo.width, self.logo.height = self.logo.sprite:getDimensions()

  safesend(self.maskshader, "radius",  width*height)
  safesend(self.maskshader, "lighten", 0)
  safesend(self.maskshader, "shadow",  0)
  safesend(self.maskshader, "blur",    1)

  safesend(self.textshader, "alpha", 0)

  safesend(self.logoshader, "pen", 0)
  safesend(self.logoshader, "mask", self.logo.mask)

  timer.clear()
  timer.script(function(wait)

    wait(self.delay_before)

    -- roll in stripes
    timer.tween(0.5, self.stripes, {offset = 0})
    wait(0.3)

    timer.tween(0.3, self.stripes, {rot = -5 * math.pi / 18, height=height})
    wait(0.2)

    -- hackety hack: execute timer to update shader every frame
    timer.every(0, function()
      safesend(self.maskshader, "radius",  self.stripes.radius)
      safesend(self.maskshader, "lighten", self.stripes.lighten)
      safesend(self.maskshader, "shadow",  self.stripes.shadow)
      safesend(self.textshader, "alpha",   self.text.alpha)
      safesend(self.logoshader, "pen",     self.logo.pen)
    end)

    -- focus the heart, desaturate the rest
    timer.tween(0.2, self.stripes, {radius  = 170})
    timer.tween(0.4, self.stripes, {lighten = .06}, "quad")
    wait(0.2)

    timer.tween(0.2, self.stripes,  {radius = 70}, "out-back")
    timer.tween(0.7, self.stripes,  {shadow = .3}, "back")
    timer.tween(0.8, self.heart,    {scale  =  1}, "out-elastic", nil, 1, 0.3)

    -- write out the text
    timer.tween(.75, self.text, {alpha = 1}, "linear")

    -- draw out the logo, in parts
    local mult = 0.65
    local function tween_and_wait(dur, pen, easing)
      timer.tween(mult * dur, self.logo, {pen = pen/255}, easing)
      wait(mult * dur)
    end
    tween_and_wait(0.175,  50, "in-quad")     -- L
    tween_and_wait(0.300, 100, "in-out-quad") -- O
    tween_and_wait(0.075, 115, "out-sine")    -- first dot on O
    tween_and_wait(0.075, 129, "out-sine")    -- second dot on O
    tween_and_wait(0.125, 153, "in-out-quad") -- \
    tween_and_wait(0.075, 179, "in-quad")     -- /
    tween_and_wait(0.250, 205, "in-quart")    -- e->break
    tween_and_wait(0.150, 230, "out-cubic")   -- e finish
    tween_and_wait(0.150, 244, "linear")      -- ()
    tween_and_wait(0.100, 255, "linear")      -- R
    wait(0.4)

    -- no more skipping
    wait(self.delay_after)
    self.done = true

    timer.tween(0.3, self, {alpha = 0})
    wait(0.3)

    timer.clear()

    if self.onDone then self.onDone() end
  end)

  self.draw = splashlib.draw
  self.update = splashlib.update
  self.skip = splashlib.skip

  return self
end

function splashlib:draw()
  local width, height = love.graphics.getDimensions()

  if self.background then
    love.graphics.clear(self.background)
  end

  if self.fill and self.elapsed > self.delay_before + 0.6 then
    self:fill()
  end

  self.canvas:renderTo(function()
    love.graphics.push()
    love.graphics.translate(width / 2, height / 2)

    love.graphics.push()
    love.graphics.rotate(self.stripes.rot)
    love.graphics.setColor(colors.pink)
    love.graphics.rectangle(
      "fill",
      self.stripes.offset - width, -self.stripes.height,
      width * 2, self.stripes.height
    )

    love.graphics.setColor(colors.blue)
    love.graphics.rectangle(
      "line", -- draw line for anti aliasing
      -width - self.stripes.offset, 0,
      width * 2, self.stripes.height
    )
    love.graphics.rectangle(
      "fill",
      -width - self.stripes.offset, 0,
      width * 2, self.stripes.height
    )
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, self.heart.scale)
    love.graphics.draw(self.heart.sprite, 0, 5, self.heart.rot, self.heart.scale, self.heart.scale, 43, 39)
    love.graphics.pop()
  end)

  love.graphics.setColor(1, 1, 1, self.alpha)
  love.graphics.setShader(self.maskshader)
  love.graphics.draw(self.canvas, 0,0)
  love.graphics.setShader()

  love.graphics.push()
  love.graphics.setShader(self.textshader)
  love.graphics.draw(
    self.text.obj,
    (width  / 2) - (self.text.width   / 2),
    (height / 2) - (self.text.height  / 2) + (height / 10) + 62
  )
  love.graphics.pop()

  love.graphics.push()
  love.graphics.setShader(self.logoshader)
  love.graphics.draw(
    self.logo.sprite,
    (width  / 2) - (self.logo.width   / 4),
    (height / 2) + (self.logo.height  / 4) + (height / 10),
    0, 0.5, 0.5
  )
  love.graphics.setShader()
  love.graphics.pop()
end

function splashlib:update(dt)
  timer.update(dt)
  self.elapsed = self.elapsed + dt
end

function splashlib:skip()
  if not self.done then
    self.done = true

    timer.tween(0.3, self, {alpha = 0})
    timer.after(0.3, function ()
      timer.clear() -- to be safe
      if self.onDone then self.onDone() end
    end)
  end
end

setmetatable(splashlib, { __call = function(self, ...) return self.new(...) end })

return splashlib
