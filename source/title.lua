local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local format <const> = string.format
local floor <const> = math.floor
local ceil <const> = math.ceil

import 'settings'
import 'klondike'
import 'statistics'
import 'credits'

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
		logo = newimage('images/logo'),
		accent_small = newimage('images/accent_small'),
		accent_large = newimage('images/accent_large'),
	}

	vars = {
		remember = args[1] or '',
		fade_in = args[2] or false,
		handler = '',
		selections = {},
		selection = 1,
		hit_edge = false,
	}
	afterdelay('handler_delay', transitiontime, function() vars.handler = 'title' end)

	if save.snapshot ~= nil then
		-- TODO: table.insert(vars.selections, 'continue')
	end
	table.insert(vars.selections, 'klondike')
	if save.seenpickup then
		-- TODO: table.insert(vars.selections, 'pickup')
	end
	table.insert(vars.selections, 'statistics')
	if catalog then
		-- TODO: table.insert(vars.selections, 'highscores')
	end
	table.insert(vars.selections, 'settings')
	table.insert(vars.selections, 'credits')

	if vars.remember ~= nil then
		for i = 1, #vars.selections do
			if vars.selections[i] == vars.remember then
				vars.selection = i
				break
			end
		end
	end

	if vars.fade_in then
		newtimer('fade', 250, 1, 0, 'linear', function()
			gfx.sprite.redrawBackground()
		end)
	else
		newtimer('fade', 0, 0, 0)
	end

	loopingtimer('cards', 120000, 0, -2340)

	-- TODO: rubdubdub on title screen activates 52 pickup mode
	-- NOTE: newmusic()
end

function title:update()
	if pd.buttonJustPressed('up') then self:keypressed('up') end
	if pd.buttonJustPressed('down') then self:keypressed('down') end
	if pd.buttonJustPressed('a') then self:keypressed('a') end

	gfx.sprite.addDirtyRect(0, 150 + (save.control_bar and 0 or 20), 400, 70)

	if value('fade') > 0 then
		gfx.sprite.redrawBackground()
	end

	local ticks = pd.getCrankTicks(4)

	if ticks > 0 then
		vars.selection += 1
		if vars.selection > #vars.selections then
			vars.selection = #vars.selections
			if not vars.hit_edge then
				vars.hit_edge = true
				playsound(doink)
			end
		else
			playsound(move)
			vars.hit_edge = false
		end
		gfx.sprite.redrawBackground()
	elseif ticks < 0 then
		vars.selection -= 1
		if vars.selection < 1 then
			vars.selection = 1
			if not vars.hit_edge then
				vars.hit_edge = true
				playsound(doink)
			end
		else
			playsound(move)
			vars.hit_edge = false
		end
		gfx.sprite.redrawBackground()
	end
end

function title:draw()
	offset = save.control_bar and 0 or 20

	setcolor(0, 0, 0, -(save.backdrop) + 1, 'black')
	fillrect(0, 150 + offset, 400, 70)
	setcolor(255, 255, 255, 1, 'black')

	drawimage(assets.logo, 10, 75 + offset)

	local cards = floor(value('cards') / 2) * 2

	for i = 1, 52 do
		local n = ceil(i / 4)
		if i % 4 == 1 then
			drawimage(card_images['card_clubs' .. n], -40 + (i * 45) + cards, 155 + offset)
		elseif i % 4 == 2 then
			drawimage(card_images['card_diamonds' .. n], -40 + (i * 45) + cards, 155 + offset)
		elseif i % 4 == 3 then
			drawimage(card_images['card_spades' .. n], -40 + (i * 45) + cards, 155 + offset)
		elseif i % 4 == 0 then
			drawimage(card_images['card_hearts' .. n], -40 + (i * 45) + cards, 155 + offset)
		end
	end

	cards += 2340

	for i = 1, 9 do
		local n = ceil(i / 4)
		if i % 4 == 1 then
			drawimage(card_images['card_clubs' .. n], -40 + (i * 45) + cards, 155 + offset)
		elseif i % 4 == 2 then
			drawimage(card_images['card_diamonds' .. n], -40 + (i * 45) + cards, 155 + offset)
		elseif i % 4 == 3 then
			drawimage(card_images['card_spades' .. n], -40 + (i * 45) + cards, 155 + offset)
		elseif i % 4 == 0 then
			drawimage(card_images['card_hearts' .. n], -40 + (i * 45) + cards, 155 + offset)
		end
	end

	if save.control_bar then
		drawimage(assets.accent_small, 276, 0)

		for i = 1, #vars.selections do
			drawtext(vars.selection == i and pixolde_italic or pixolde, text('title_' .. vars.selections[i]), 340, 63 + ((i - (#vars.selections / 2)) * 15), center)
		end

		-- drawing control bar
		setcolor(0, 0, 0, 1, 'black')
		fillrect(0, 220, 400, 20)
		setcolor(255, 255, 255, 1, 'black')

		local controls

		-- parsing controls based on context
		if vars.handler == '' then
			controls = text('control_pleasewait')
		else
			controls = text('control_move_vert')
			if vars.selections[vars.selection] == 'klondike' or vars.selections[vars.seelction] == 'pickup' then
				controls = controls .. text('control_play')
			else
				controls = controls .. text('control_select')
			end
		end
		drawtext(pixolde_inverted, controls, 5, 223)

		local time = gettime()
		local hour = time.hour
		local minute = time.minute
		drawtext(pixolde_inverted, (pd.shouldDisplay24HourTime() and (format("%02d:%02d", hour, minute)) or (format("%01d:%02d", ((hour % 12) == 0 and 12 or (hour % 12)), minute)) .. (hour < 12 and 'a' or 'p')), 395, 223, right)
	else
		drawimage(assets.accent_large, 260, 0)

		for i = 1, #vars.selections do
			drawtext(vars.selection == i and pixolde_italic or pixolde, text('title_' .. vars.selections[i]), 331, 73 + ((i - (#vars.selections / 2)) * 15), center)
		end
	end

	if timeleft('fade') > 0 then
		setcolor(0, 0, 0, value('fade'), 'black')
		fillrect(0, 0, 400, 240)
		setcolor(255, 255, 255, 1, 'black')
	end


end

function title:keypressed(button)
	if vars.handler == 'title' then
		if button == 'up' then
			vars.selection -= 1
			if vars.selection < 1 then
				vars.selection = 1
				playsound(doink)
			else
				playsound(move)
				vars.hit_edge = false
			end
			gfx.sprite.redrawBackground()
		elseif button == 'down' then
			vars.selection += 1
			if vars.selection > #vars.selections then
				vars.selection = #vars.selections
				playsound(doink)
			else
				playsound(move)
				vars.hit_edge = false
			end
			gfx.sprite.redrawBackground()
		elseif button == 'a' then
			if vars.selections[vars.selection] == 'continue' then
				scenemanager:transitionscene(klondike, {}, true)
			elseif vars.selections[vars.selection] == 'klondike' then
				-- TODO: dialog box "are you sure?" if continue point exists
				scenemanager:transitionscene(klondike)
			elseif vars.selections[vars.selection] == 'pickup' then
				scenemanager:transitionscene(pickup)
			elseif vars.selections[vars.selection] == 'statistics' then
				scenemanager:transitionscene(statistics)
			elseif vars.selections[vars.selection] == 'highscores' then
				scenemanager:transitionscene(highscores)
			elseif vars.selections[vars.selection] == 'settings' then
				scenemanager:transitionscene(settings)
			elseif vars.selections[vars.selection] == 'credits' then
				scenemanager:transitionscene(credits)
			end
			playsound(accept)
		end
	end
end