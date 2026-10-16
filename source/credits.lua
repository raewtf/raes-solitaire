local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local format <const> = string.format
local ceil <const> = math.ceil

class('credits').extends(gfx.sprite)
function credits:init(...)
	credits.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here

	function pd.gameWillPause()
		local menu = pd.getSystemMenu()
		menu:removeAllMenuItems()
		if not transitioning then
			menu:addMenuItem(text('slide_back'), function()
				scenemanager:transitionsceneback(title, 'credits')
			end)
		end
	end

	self:initialize(args)
	gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
		self:draw()
	end)

	self:add()
end

function credits:initialize(args)
	assets = {
		battery = newimagetable('images/battery'),
	}

	vars = {
		handler = '',
	}
	afterdelay('handler_delay', transitiontime, function() vars.handler = 'credits' end)

	set_music_level(1)
end

function credits:update()
	if pd.buttonJustPressed('b') then self:keypressed('b') end
end

function credits:draw()
	drawtext(pixolde, text('credits_begin'), 10, 9)
	drawtext(pixolde, text('credits_main'), 390, 20 + (save.control_bar and 0 or 6), right)
	drawtext(pixolde, text('credits_guest_decks'), 10, 60 + (save.control_bar and 0 or 12))
	drawtext(pixolde, text('credits_thanks'), 390, 124 + (save.control_bar and 0 or 18), right)

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
			controls = text('control_back')
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

function credits:keypressed(button)
	if vars.handler == 'credits' then
		if button == 'b' then
			playsound(bump)
			scenemanager:transitionsceneback(title, 'credits')
		end
	end
end