local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local format <const> = string.format

class('credits').extends(gfx.sprite)
function credits:init(...)
	credits.super.init(self)
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

function credits:initialize(args)
	assets = {
	}

	vars = {
		handler = '',
	}
	afterdelay('handler_delay', transitiontime, function() vars.handler = 'credits' end)

	newmusic('audio/music/level1')
end

function credits:update()
	if pd.buttonJustPressed('b') then self:keypressed('b') end
end

function credits:draw()
	if save.control_bar then
		-- drawing control bar
		setcolor(0, 0, 0, 1, 'black')
		fillrect(0, 220, 400, 20)
		setcolor(255, 255, 255, 1, 'black')

		drawtext(pixolde, text('credits_begin'), 10, 10)
		drawtext(pixolde, text('credits_main'), 390, 20, right)
		drawtext(pixolde, text('credits_guest_decks'), 10, 60)
		drawtext(pixolde, text('credits_thanks'), 390, 138, right)

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
		drawtext(pixolde_inverted, (pd.shouldDisplay24HourTime() and (format("%02d:%02d", hour, minute)) or (format("%01d:%02d", ((hour % 12) == 0 and 12 or (hour % 12)), minute)) .. (hour < 12 and 'a' or 'p')), 395, 223, right)
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