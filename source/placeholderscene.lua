local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local format <const> = string.format

class('title').extends(gfx.sprite)
function title:init(...)
	title.super.init(self)
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

function title:initialize(args)
	assets = {
	}

	vars = {
		handler = ''
	}
	afterdelay('handler_delay', transitiontime, function() vars.handler = 'title' end)

	-- TODO: newmusic()
end

function title:update()
	if pd.buttonJustPressed('up') then self:keypressed('up') end
	if pd.buttonJustPressed('down') then self:keypressed('down') end
	if pd.buttonJustPressed('left') then self:keypressed('left') end
	if pd.buttonJustPressed('right') then self:keypressed('right') end
	if pd.buttonJustPressed('a') then self:keypressed('a') end
	if pd.buttonJustPressed('b') then self:keypressed('b') end
end

function title:draw()

end

function title:keypressed(button)
	if vars.handler == 'title' then
		if button == 'up' then
		elseif button == 'down' then
		elseif button == 'left' then
		elseif button == 'right' then
		elseif button == 'a' then
		elseif button == 'b' then
		end
	end
end