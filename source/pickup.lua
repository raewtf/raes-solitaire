local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local format <const> = string.format
local floor <const> = math.floor
local ceil <const> = math.ceil

class('pickup').extends(gfx.sprite)
function pickup:init(...)
	pickup.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here

	function pd.gameWillPause()
		local menu = pd.getSystemMenu()
		menu:removeAllMenuItems()
	end

	self:initialize(args)
	gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
		self:draw()
	end)

	self:add()
end

function pickup:initialize(args)
	assets = {
		battery = newimagetable('images/battery'),
	}

	vars = {
	}

	-- TODO: generate random order of cards
	-- TODO: generate random X/Y positions (within screen bounds)
	-- TODO: generate random rotational positions
	-- TODO: bake rotations per
	-- TODO: generate random face up/down values for each one
end

function pickup:update()
	if pd.buttonJustPressed('up') then self:keypressed('up') end
	if pd.buttonJustPressed('down') then self:keypressed('down') end
	if pd.buttonJustPressed('left') then self:keypressed('left') end
	if pd.buttonJustPressed('right') then self:keypressed('right') end
	if pd.buttonJustPressed('b') then self:keypressed('b') end
	if pd.buttonJustPressed('a') then self:keypressed('a') end
end

function pickup:draw()
	-- TODO: draw background (using save variable)

	if save.control_bar then
		-- drawing control bar
		setcolor(0, 0, 0, 1, 'black')
		fillrect(0, 220, 400, 20)
		setcolor(255, 255, 255, 1, 'black')

		local controls

		-- parsing controls based on context
		if vars.handler == '' then
			controls = text('control_pleasewait')
		else
			controls = text('control_pleasewait')
		end
		drawtext(pixolde_inverted, controls, 5, 223)

		local time = gettime()
		local hour = time.hour
		local minute = time.minute
		drawtext(pixolde_inverted, (is24hour() and (format("%02d:%02d", hour, minute)) or (format("%01d:%02d", ((hour % 12) == 0 and 12 or (hour % 12)), minute)) .. (hour < 12 and 'a' or 'p')), 373, 223, right)

		local bat_stat = pd.getPowerStatus()
		if bat_stat.charging then
			if bat_stat.screws then
				drawimagetable(assets.battery, 7, 380, 225)
			else
				drawimagetable(assets.battery, 6, 380, 225)
			end
		else
			local battery = pd.getBatteryPercentage()
			drawimagetable(assets.battery, ceil(battery / 20), 380, 225)
		end
	else
		setcolor(255, 255, 255, 1, 'black')
	end
end

function pickup:keypressed(button)
	if vars.handler == 'playing' then
		-- TODO: move cursor around on two axes
		-- TODO: if loop selection is on, loop at the edges (two sets of cursors at a modulo?)
		if button == 'up' then
		elseif button == 'down' then
		elseif button == 'left' then
		elseif button == 'right' then
		elseif button == 'b' then
			-- TODO: undo if undos are available
		elseif button == 'a' then
			-- TODO: if card is hovered, pick it up
			-- TODO: if no card is hovered, bonk
		end
	end
end