local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local format <const> = string.format

class('settings').extends(gfx.sprite)
function settings:init(...)
	settings.super.init(self)
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

function settings:initialize(args)
	assets = {
		customization_backdrop = newimage(132, 72),
	}

	self:render_cards()

	vars = {
		handler = '',
		categories = {'gameplay', 'klondike_rules', 'customization'},
		category_selection = 1,
		gameplay_selections = {'music', 'sfx', 'card_sfx', 'timer', 'move_count', 'control_bar', 'loop', 'crank_direction', 'quickpick'},
		klondike_rules_selections = {'deck_draw', 'undo', 'possible', 'auto', 'crank', 'stack_anywhere', 'deck_passes'},
		customization_selections = {'card_front', 'card_back', 'cursor', 'anim_speed', 'backdrop', 'card_guide'},
		card_fronts = {
			'antennae',
			'big',
			'placeholder',
			-- begin guest artist decks
			'shattered',
			'reelistic',
			'bedbeard',
		},
		card_backs = {
			'antennae',
			'simple',
			'gradient',
			'logo',
			'smiley',
			'fullmoon',
			'lavalamp',
			'nosignal',
			'peedee',
			'catalog',
			'bunny',
			'pesto',
			-- begin guest artist items
			'shattered',
			'reelistic',
			'bedbeard',
			'groove',
		},
		cursors = {
			'cartoon',
			'pinky',
			'crank',
			'pointer',
			'retro_light',
			'retro_dark',
			'paw_light',
			'paw_gray',
			'paw_dark',
			'fork',
			'spoon',
			'bang',
			'oar',
		},
		selection = 1,
		category_offset = 0,
		category_target = 0,
		reload = false,
		hit_edge = false,
	}
	afterdelay('handler_delay', transitiontime, function() vars.handler = 'settings' end)

	newmusic('audio/music/level1')
end

function settings:update()
	if pd.buttonJustPressed('up') then self:keypressed('up') end
	if pd.buttonJustPressed('down') then self:keypressed('down') end
	if pd.buttonJustPressed('left') then self:keypressed('left') end
	if pd.buttonJustPressed('right') then self:keypressed('right') end
	if pd.buttonJustPressed('a') then self:keypressed('a') end
	if pd.buttonJustPressed('b') then self:keypressed('b') end

	if vars.category_target ~= nil and vars.category_offset ~= nil then
		vars.category_offset += (vars.category_target - vars.category_offset) * 0.5
		if vars.category_offset > (vars.category_target - 0.1) and vars.category_offset < (vars.category_target + 0.1) then
			vars.category_offset = vars.category_target
		else
			gfx.sprite.addDirtyRect(0, 0, 250, 30)
		end
	end

	if vars.reload then
		-- re-load the common card images
		vars.handler = ''
	end

	local ticks = pd.getCrankTicks(4)
	local cat = vars.categories[vars.category_selection]
	local cat_sels = vars[cat .. '_selections']

	if ticks > 0 then
		vars.selection += 1
		if vars.selection > #cat_sels then
			vars.selection = #cat_sels
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

function settings:draw()
	-- defining hot variables
	local cat = vars.categories[vars.category_selection]
	local cat_sels = vars[cat .. '_selections']
	local cat_sel = cat_sels[vars.selection]

	-- top category selector bar
	fillrect(0, 0, 250, 30)
	setcolor(255, 255, 255, 1, 'white')
	fillrect(65, 5, 120, 20, 5)

	if vars.category_selection > 1 then
		drawtext(pixolde_inverted, text('settings_' .. vars.categories[vars.category_selection - 1]), 125 - 75 + vars.category_offset, 8, right)
	end
	drawtext(pixolde_bold, text('settings_' .. cat), 125 + vars.category_offset, 8, center)
	if vars.category_selection < #vars.categories then
		drawtext(pixolde_inverted, text('settings_' .. vars.categories[vars.category_selection + 1]), 125 + 75 + vars.category_offset, 8)
	end

	for i = 1, #cat_sels do
		drawtext(vars.selection == i and pixolde_italic or pixolde, text('settings_' .. cat_sels[i]), 10, 23 + (i * 15))
		drawtext(vars.selection == i and pixolde_italic or pixolde, self:status(cat_sels[i]), 240, 23 + (i * 15), right)
	end

	setcolor(255, 255, 255, 1, 'black')
	drawline(250, 0, 250, 240)

	if cat_sel == 'card_front' then
		local by = text('credits_card_front_' .. save.card_front)
		gfx.drawText(text('settings_' .. cat_sel .. '_desc') .. text('settings_card_front_by') .. (by == 'credits_card_front_' .. save.card_front and '*rae*.' or '*' .. by .. '*.'), 260, 10)
	elseif cat_sel == 'card_back' then
		local by = text('credits_card_back_' .. save.card_back)
		gfx.drawText(text('settings_' .. cat_sel .. '_desc') .. text('settings_card_back_by') .. (by == 'credits_card_back_' .. save.card_back and '*rae*.' or '*' .. by .. '*.'), 260, 10)
	else
		gfx.drawText(text('settings_' .. cat_sel .. '_desc'), 260, 10)
	end

	-- customization preview
	if vars.categories[vars.category_selection] == 'customization' then
		local offset = save.control_bar and 0 or 22

		drawimage(assets.customization_backdrop, 259, 139 + offset)

		drawimage(assets.card_front, 265, 145 + offset)
		drawimage(assets.card_back, 315, 145 + offset)
		drawimage(assets.cursor, 272, 182)
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
		else
			controls = text('control_category') .. text('control_move_vert')
			if (cat == 'gameplay' and cat_sel ~= 'crank_direction') or cat_sel == 'undo' or cat_sel == 'quickpick' then
				controls = controls .. text('control_toggle')
			else
				controls = controls .. text('control_change')
			end
			controls = controls .. text('control_back')
		end
		drawtext(pixolde_inverted, controls, 5, 223)

		local time = gettime()
		local hour = time.hour
		local minute = time.minute
		drawtext(pixolde_inverted, (pd.shouldDisplay24HourTime() and (format("%02d:%02d", hour, minute)) or (format("%01d:%02d", ((hour % 12) == 0 and 12 or (hour % 12)), minute)) .. (hour < 12 and 'a' or 'p')), 395, 223, right)
	end

	if vars.reload then
		pd.display.flush()
		load_card_images()
		vars.reload = false
		vars.handler = 'settings'
	end
end

function settings:render_cards()
	gfx.pushContext(assets.customization_backdrop)
		-- backdrop
		setcolor(255, 255, 255, 1, 'white')
		fillrect(1, 1, 130, 70, 5)

		setcolor(0, 0, 0, -(save.backdrop - 1), 'black')
		fillrect(1, 1, 130, 70, 5)

		-- card guides
		for i = 1, 2 do
			if i == 1 then
				setcolor(255, 255, 255, 1, 'white')
			else
				setcolor(0, 0, 0, -(save.card_guide - 1), 'black')
			end
			drawrect(6, 6, 40, 60, 5)
			drawrect(56, 6, 40, 60, 5)
			drawrect(106, 6, 40, 60, 5)
		end

		setcolor(255, 255, 255, 1, 'black')
		drawrect(1, 1, 130, 70, 5)
	gfx.popContext()
	assets.card_back = newimage('images/cards/' .. save.card_back .. '/back')
	local rand = randInt(1, 4)
	local rand_suit = rand == 1 and 'clubs' or rand == 2 and 'hearts' or rand == 3 and 'spades' or rand == 4 and 'diamonds'
	assets.card_front = newimage('images/cards/' .. save.card_front .. '/' .. rand_suit .. randInt(1, 13))
	assets.cursor = newimage('images/cursors/' .. save.cursor)
end

function settings:status(item)
	if item == 'deck_draw' or item == 'possible' or item == 'stack_anywhere' or item == 'deck_passes' or item == 'card_front' or item == 'card_back' or item == 'auto' or item == 'crank' or item == 'cursor' or item == 'crank_direction' then
		return text('settings_' .. item .. '_' .. tostring(save[item]))
	elseif item == 'backdrop' or item == 'card_guide' then
		return tostring(save[item])
	elseif item == 'anim_speed' then
		if save.anim_speed == 0 then
			return text('settings_anim_speed_0')
		else
			return tostring(save[item]) .. '%'
		end
	else
		return text('settings_' .. tostring(save[item]))
	end
end

function settings:keypressed(button)
	-- defining hot variables
	local cat = vars.categories[vars.category_selection]
	local cat_sels = vars[cat .. '_selections']
	local cat_sel = cat_sels[vars.selection]

	if vars.handler == 'settings' then
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
			if vars.selection > #cat_sels then
				vars.selection = #cat_sels
				playsound(doink)
			else
				playsound(move)
				vars.hit_edge = false
			end
			gfx.sprite.redrawBackground()
		elseif button == 'left' then
			vars.category_selection -= 1
			if vars.category_selection < 1 then
				vars.category_selection = 1
				playsound(doink)
				vars.category_offset = 5
			else
				vars.category_offset = -10
				vars.selection = 1
				playsound(bonk)
			end
			gfx.sprite.redrawBackground()
		elseif button == 'right' then
			vars.category_selection += 1
			if vars.category_selection > #vars.categories then
				vars.category_selection = #vars.categories
				playsound(doink)
				vars.category_offset = -5
			else
				vars.category_offset = 10
				vars.selection = 1
				playsound(bonk)
			end
			gfx.sprite.redrawBackground()
		elseif button == 'a' then
			if cat_sel == 'music' then
				save.music = not save.music
				if save.music then
					newmusic('audio/music/level1')
				else
					stopmusic()
				end
			elseif cat_sel == 'sfx' then
				save.sfx = not save.sfx
			elseif cat_sel == 'card_sfx' then
				save.card_sfx = not save.card_sfx
			elseif cat_sel == 'timer' then
				save.timer = not save.timer
			elseif cat_sel == 'move_count' then
				save.move_count = not save.move_count
			elseif cat_sel == 'control_bar' then
				save.control_bar = not save.control_bar
			elseif cat_sel == 'loop' then
				save.loop = not save.loop
			elseif cat_sel == 'deck_draw' then
				if save.deck_draw == 1 then
					save.deck_draw = 3
				else
					save.deck_draw = 1
				end
			elseif cat_sel == 'crank_direction' then
				save.crank_direction += 1
				if save.crank_direction > 2 then
					save.crank_direction = 0
				end
			elseif cat_sel == 'undo' then
				save.undo = not save.undo
			elseif cat_sel == 'possible' then
				save.possible = not save.possible
			elseif cat_sel == 'auto' then
				save.auto += 1
				if save.auto > 2 then
					save.auto = 0
				end
			elseif cat_sel == 'crank' then
				save.crank += 1
				if save.crank > 3 then
					save.crank = 0
				end
			elseif cat_sel == 'quickpick' then
				save.quickpick = not save.quickpick
			elseif cat_sel == 'stack_anywhere' then
				save.stack_anywhere = not save.stack_anywhere
			elseif cat_sel == 'deck_passes' then
				if save.deck_passes == 0 then
					save.deck_passes = 1
				elseif save.deck_passes == 1 then
					save.deck_passes = 2
				elseif save.deck_passes == 2 then
					save.deck_passes = 3
				elseif save.deck_passes == 3 then
					save.deck_passes = 5
				elseif save.deck_passes == 5 then
					save.deck_passes = 10
				elseif save.deck_passes == 10 then
					save.deck_passes = 25
				elseif save.deck_passes == 25 then
					save.deck_passes = 50
				elseif save.deck_passes == 50 then
					save.deck_passes = 0
				end
			elseif cat_sel == 'card_front' then
				local sel = 0
				for i = 1, #vars.card_fronts do
					if save.card_front == vars.card_fronts[i] then
						sel = i
						break
					end
				end
				save.card_front = vars.card_fronts[(sel == #vars.card_fronts and 1 or sel + 1)]
				self:render_cards()
				vars.reload = true
			elseif cat_sel == 'card_back' then
				local sel = 0
				for i = 1, #vars.card_backs do
					if save.card_back == vars.card_backs[i] then
						sel = i
						break
					end
				end
				save.card_back = vars.card_backs[(sel == #vars.card_backs and 1 or sel + 1)]
				self:render_cards()
			elseif cat_sel == 'cursor' then
				local sel = 0
				for i = 1, #vars.cursors do
					if save.cursor == vars.cursors[i] then
						sel = i
						break
					end
				end
				save.cursor = vars.cursors[(sel == #vars.cursors and 1 or sel + 1)]
				self:render_cards()
			elseif cat_sel == 'anim_speed' then
				save.anim_speed += 25
				if save.anim_speed > 250 then
					save.anim_speed = 0
				end
			elseif cat_sel == 'backdrop' then
				save.backdrop = ((save.backdrop * 10) + 1) / 10
				if save.backdrop == 1 then save.backdrop = 1 end
				if save.backdrop > 1 then
					save.backdrop = 0
				end
				self:render_cards()
			elseif cat_sel == 'card_guide' then
				save.card_guide = ((save.card_guide * 10) + 1) / 10
				if save.card_guide == 1 then save.card_guide = 1 end
				if save.card_guide > 1 then
					save.card_guide = 0
				end
				self:render_cards()
			end
			playsound(accept)
			gfx.sprite.redrawBackground()
		elseif button == 'b' then
			playsound(bump)
			scenemanager:transitionsceneback(title, 'settings')
		end
	end
end