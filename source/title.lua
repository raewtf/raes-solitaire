local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local find <const> = string.find
local format <const> = string.format
local floor <const> = math.floor
local ceil <const> = math.ceil

import 'klondike'
import 'pickup'
import 'statistics'
import 'highscores'
import 'settings'
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

-- TODO: 52-pickup how-to-play slides

function title:initialize(args)
	assets = {
		logo = newimage('images/logo'),
		accent_small = newimage('images/accent_small'),
		accent_large = newimage('images/accent_large'),
		battery = newimagetable('images/battery'),
	}

	vars = {
		remember = args[1] or '',
		fade_in = args[2] or false,
		handler = '',
		selections = {},
		selection = 1,
		hit_edge = false,
		cards_offset = 0,
		sequence = {'right', 'up', 'b', 'down', 'up', 'b', 'down', 'up', 'b'},
		sequenceindex = 1,
		howtoplay_step = 1,
		howtoplay_klondike_max = 6,
		howtoplay_pickup_max = 2,
	}
	afterdelay('handler_delay', transitiontime, function() vars.handler = 'title' end)

	if save.snapshot ~= nil then
		table.insert(vars.selections, 'continue')
	end

	-- prepping box for potential pop-up
	assets.box = newimage('images/box')
	vars.box_selection = 1
	vars.box_moving = true
	vars.box_hit_edge = false
	newtimer('box', 0, 1, 1)

	table.insert(vars.selections, 'klondike')
	if save.seenpickup then
		table.insert(vars.selections, 'pickup')
	end
	table.insert(vars.selections, 'statistics')
	if catalog then
		table.insert(vars.selections, 'highscores')
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
		newtimer('fade', 250, 1, 0, 'linear')
	else
		newtimer('fade', 0, 0, 0)
	end

	loopingtimer('cards', 120000, 0, -2340)

	set_music_level(2)
end

function title:update()
	if pd.buttonJustPressed('up') then self:keypressed('up') end
	if pd.buttonJustPressed('down') then self:keypressed('down') end
	if pd.buttonJustPressed('left') then self:keypressed('left') end
	if pd.buttonJustPressed('right') then self:keypressed('right') end
	if pd.buttonJustPressed('b') then self:keypressed('b') end
	if pd.buttonJustPressed('a') then self:keypressed('a') end

	if vars.sequenceindex > #vars.sequence and not save.seenpickup then
		-- TODO: save.seenpickup = true
		-- TODO: playsound(win)
		-- TODO: duck music for win SFX
		--[[ TODO:
		for i = 1, #vars.selections do
			if vars.selections[i] == 'klondike' then
				table.insert(vars.selections, i + 1, 'pickup')
				break
			end
		end
		]]
	end

	vars.cards_offset -= pd.getCrankChange()

	local ticks = pd.getCrankTicks(4)

	if vars.handler == 'box_inprogress' and not vars.box_moving then
		if ticks > 0 then
			vars.box_selection += 1
			if vars.box_selection > 2 then
				vars.box_selection = 2
				if not vars.box_hit_edge then
					vars.box_hit_edge = true
					playsound(doink)
				end
			else
				playsound(move)
				vars.box_hit_edge = false
			end
		elseif ticks < 0 then
			vars.box_selection -= 1
			if vars.box_selection < 1 then
				vars.box_selection = 1
				if not vars.box_hit_edge then
					vars.box_hit_edge = true
					playsound(doink)
				end
			else
				playsound(move)
				vars.box_hit_edge = false
			end
		end
	else
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
		end
	end
end

function title:draw()
	offset = save.control_bar and 0 or 20

	setcolor(0, 0, 0, -(save.backdrop) + 1, 'black')
	fillrect(0, 150 + offset, 400, 70)
	setcolor(255, 255, 255, 1, 'black')

	drawimage(assets.logo, 10, 75 + offset)

	local cards = ((floor(value('cards') / 2) * 2) + vars.cards_offset) % -2340

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
			drawtext(vars.selection == i and pixolde_bold or pixolde, text('title_' .. vars.selections[i]), 338, 63 + ((i - (#vars.selections / 2)) * 15), center)
		end
	else
		drawimage(assets.accent_large, 260, 0)

		for i = 1, #vars.selections do
			drawtext(vars.selection == i and pixolde_bold or pixolde, text('title_' .. vars.selections[i]), 331, 73 + ((i - (#vars.selections / 2)) * 15), center)
		end
	end

	-- draw dialog box, if available
	if value('box') < 1 then
		setcolor(0, 0, 0, (-value('box') + 1) * 0.75, 'black')
		fillrect(0, 0, 400, 240)

		local box_offset = (value('box') * 200) + (save.control_bar and -10 or 0)

		drawimage(assets.box, 79, 39 + box_offset)

		if vars.handler == 'box_inprogress' then
			drawtext(pixolde_bold, text('box_inprogress'), 200, 65 + box_offset, center)
			drawtext(pixolde, text('box_inprogress_desc'), 200, 85 + box_offset, center)
			drawtext(vars.box_selection == 1 and pixolde_bold or pixolde, text('box_newgame'), 200, 140 + box_offset, center)
			drawtext(vars.box_selection == 2 and pixolde_bold or pixolde, text('box_nevermind'), 200, 155 + box_offset, center)
		elseif find(vars.handler, 'howtoplay_') then
			if vars.handler == 'howtoplay_klondike' then
				if vars.howtoplay_step == 4 or vars.howtoplay_step == 5 then
					drawtext(pixolde_bold, text(vars.handler .. '_standard_scoring'), 200, 68 + box_offset, center)
				elseif vars.howtoplay_step == 6 then
					drawtext(pixolde_bold, text(vars.handler .. '_vegas_scoring'), 200, 68 + box_offset, center)
				else
					drawtext(pixolde_bold, text(vars.handler), 200, 68 + box_offset, center)
				end
			else
				drawtext(pixolde_bold, text(vars.handler), 200, 68 + box_offset, center)
			end
			drawtext(pixolde, text(vars.handler .. '_' .. vars.howtoplay_step), 200, 88 + box_offset, center)
			drawtext(pixolde, '(' .. vars.howtoplay_step .. '/' .. vars[vars.handler .. '_max'] .. ')', 295, 182 + box_offset, right)
		end
	end

	if save.control_bar then
		-- drawing control bar
		setcolor(0, 0, 0, 1, 'black')
		fillrect(0, 220, 400, 20)
		setcolor(255, 255, 255, 1, 'black')

		local controls

		-- parsing controls based on context
		if vars.handler == '' then
			controls = text('control_pleasewait')
		elseif vars.handler == 'box_inprogress' then
			controls = text('control_move_vert') .. text('control_select') .. text('control_back')
		elseif find(vars.handler, 'howtoplay_') then
			if vars.howtoplay_step == vars[vars.handler .. '_max'] then
				controls = text('control_howtoplay_previous') .. text('control_howtoplay_close_a')
			elseif vars.howtoplay_step > 1 then
				controls = text('control_howtoplay_previous') .. text('control_howtoplay_next')
			else
				controls = text('control_howtoplay_close_b') .. text('control_howtoplay_next')
			end
		else
			controls = text('control_move_vert')
			if vars.selections[vars.selection] == 'klondike' or vars.selections[vars.selection] == 'pickup' then
				controls = controls .. text('control_play') .. text('control_howtoplay')
			elseif vars.selections[vars.selection] == 'continue' then
				controls = controls .. text('control_play')
			else
				controls = controls .. text('control_select')
			end
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

	if timeleft('fade') > 0 then
		setcolor(0, 0, 0, value('fade'), 'black')
		fillrect(0, 0, 400, 240)
		setcolor(255, 255, 255, 1, 'black')
	end
end

function title:keypressed(button)
	if vars.handler == 'box_inprogress' and not vars.box_moving then
		if button == 'up' then
			vars.box_selection -= 1
			if vars.box_selection < 1 then
				vars.box_selection = 1
				playsound(doink)
			else
				playsound(move)
				vars.box_hit_edge = false
			end
		elseif button == 'down' then
			vars.box_selection += 1
			if vars.box_selection > 2 then
				vars.box_selection = 2
				playsound(doink)
			else
				playsound(move)
				vars.box_hit_edge = false
			end
		elseif button == 'a' then
			playsound(accept)
			if vars.box_selection == 1 then
				vars.box_moving = true
				timerendedcallback('box')
				resettimer('box', 150, value('box'), 1, 'inSine', function()
					save.snapshot = nil
					scenemanager:transitionscene(klondike)
				end)
			elseif vars.box_selection == 2 then
				playsound(accept)
				vars.box_moving = true
				timerendedcallback('box')
				set_music_level(2)
				resettimer('box', 150, value('box'), 1, 'inSine', function()
					vars.handler = 'title'
				end)
			end
		elseif button == 'b' then
			playsound(bump)
			vars.box_moving = true
			timerendedcallback('box')
			set_music_level(2)
			resettimer('box', 150, value('box'), 1, 'inSine', function()
				vars.handler = 'title'
			end)
		end
	elseif find(vars.handler, 'howtoplay_') and not vars.box_moving then
		local max = vars[vars.handler .. '_max']
		if vars.howtoplay_step == max then
			if button == 'left' or button == 'b' then
				playsound(move)
				vars.howtoplay_step -= 1
			elseif button == 'right' or button == 'a' then
				playsound(bump)
				vars.box_moving = true
				timerendedcallback('box')
				set_music_level(2)
				resettimer('box', 150, value('box'), 1, 'inSine', function()
					vars.handler = 'title'
				end)
			end
		elseif vars.howtoplay_step > 1 then
			if button == 'left' or button == 'b' then
				playsound(move)
				vars.howtoplay_step -= 1
			elseif button == 'right' or button == 'a' then
				playsound(move)
				vars.howtoplay_step += 1
			end
		else
			if button == 'left' or button == 'b' then
				playsound(bump)
				vars.box_moving = true
				timerendedcallback('box')
				set_music_level(2)
				resettimer('box', 150, value('box'), 1, 'inSine', function()
					vars.handler = 'title'
				end)
			elseif button == 'right' or button == 'a' then
				playsound(move)
				vars.howtoplay_step += 1
			end
		end
	elseif vars.handler == 'title' then
		if button == 'up' then
			if vars.sequence[vars.sequenceindex] == 'up' then
				vars.sequenceindex += 1
			else
				vars.sequenceindex = 1
			end

			vars.selection -= 1
			if vars.selection < 1 then
				vars.selection = 1
				playsound(doink)
			else
				playsound(move)
				vars.hit_edge = false
			end
		elseif button == 'down' then
			if vars.sequence[vars.sequenceindex] == 'down' then
				vars.sequenceindex += 1
			else
				vars.sequenceindex = 1
			end

			vars.selection += 1
			if vars.selection > #vars.selections then
				vars.selection = #vars.selections
				playsound(doink)
			else
				playsound(move)
				vars.hit_edge = false
			end
		elseif button == 'left' then
			if vars.sequence[vars.sequenceindex] == 'left' then
				vars.sequenceindex += 1
			else
				vars.sequenceindex = 1
			end
		elseif button == 'right' then
			if vars.sequence[vars.sequenceindex] == 'right' then
				vars.sequenceindex += 1
			else
				vars.sequenceindex = 1
			end

			if vars.selections[vars.selection] == 'klondike' then
				vars.handler = 'howtoplay_klondike'
				vars.howtoplay_step = 1
				set_music_level(1)
				resettimer('box', 150, value('box'), 0, 'outSine', function()
					vars.box_moving = false
				end)
				playsound(accept)
			elseif vars.selections[vars.selection] == 'pickup' then
				vars.handler = 'howtoplay_pickup'
				vars.howtoplay_step = 1
				set_music_level(1)
				resettimer('box', 150, value('box'), 0, 'outSine', function()
					vars.box_moving = false
				end)
				playsound(accept)
			end
		elseif button == 'b' then
			if vars.sequence[vars.sequenceindex] == 'b' then
				vars.sequenceindex += 1
			else
				vars.sequenceindex = 1
			end
		elseif button == 'a' then
			if vars.sequence[vars.sequenceindex] == 'a' then
				vars.sequenceindex += 1
			else
				vars.sequenceindex = 1
			end

			if vars.selections[vars.selection] == 'continue' then
				scenemanager:transitionscene(klondike, {}, true)
			elseif vars.selections[vars.selection] == 'klondike' then
				if save.snapshot ~= nil then
					-- game in progress
					vars.handler = 'box_inprogress'
					vars.box_selection = 1
					set_music_level(1)
					resettimer('box', 150, value('box'), 0, 'outSine', function()
						vars.box_moving = false
					end)
				else
					scenemanager:transitionscene(klondike)
				end
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