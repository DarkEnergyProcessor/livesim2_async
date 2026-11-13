function love.conf(t)
	t.identity = "DEPLS"
	t.console = true
	t.window = nil -- no window: this is a command-line tool
	t.modules.audio = false
	t.modules.graphics = false
	t.modules.window = false
	t.modules.joystick = false
	t.modules.physics = false
	t.modules.video = false
	t.modules.font = false
	t.modules.image = false
	t.modules.keyboard = false
	t.modules.mouse = false
	t.modules.touch = false
	t.modules.sound = false
end
