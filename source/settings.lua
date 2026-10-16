local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local format <const> = string.format
local sub <const> = string.sub
local ceil <const> = math.ceil

class('settings').extends(gfx.sprite)
function settings:init(...)
	settings.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here

	function pd.gameWillPause()
		local menu = pd.getSystemMenu()
		menu:removeAllMenuItems()
		if not transitioning then
			menu:addMenuItem(text('slide_resetthese'), function()
				if vars.categories[vars.category_selection] == 'gameplay' then
					-- gameplay
					save.music = true
					load_music(1)
					save.sfx = true
					save.card_sfx = true
					save.undo = true
					save.undo_limit = 0
					save.loop = true
					save.crank_direction = 0
					save.quickpick = true
					save.timer = true
					save.move_count = true
				elseif vars.categories[vars.category_selection] == 'customization' then
					-- customization
					save.card_front = 'antennae'
					save.card_back = 'antennae'
					save.cursor = 'cartoon'
					save.backdrop = 0.5
					save.card_guide = 1
					save.anim_speed = 100
					save.control_bar = true
					vars.control_target = 0
					save.shoulddo24hour = 0
					save.bold_text = false
					self:render_cards(save.custom_card_front, save.custom_card_back, false)
				elseif vars.categories[vars.category_selection] == 'klondike_rules' then
					-- klondike rules
					save.deck_draw = 1
					save.scoring = 'standard'
					save.possible = false
					save.deck_passes = 0
					save.stack_anywhere = false
					save.auto = 1
					save.prompt_on_no_moves = true
					save.flip = true
					save.crank = 1
				end
			end)
			menu:addMenuItem(text('slide_back'), function()
				scenemanager:transitionsceneback(title, 'settings')
			end)
		end
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
		battery = newimagetable('images/battery'),
	}

	vars = {
		handler = '',
		categories = {
			'gameplay',
			'customization',
			'klondike_rules',
		},
		category_selection = 1,
		gameplay_selections = {
			'music',
			'sfx',
			'card_sfx',
			'undo',
			'undo_limit',
			'loop',
			'crank_direction',
			'quickpick',
			'timer',
			'move_count',
		},
		customization_selections = {
			'card_front',
			'card_back',
			'cursor',
			'backdrop',
			'card_guide',
			'anim_speed',
			'control_bar',
			'shoulddo24hour',
		},
		klondike_rules_selections = {
			'deck_draw',
			'scoring',
			'possible',
			'deck_passes',
			'stack_anywhere',
			'auto',
			-- TODO: re-enable this later
			-- 'prompt_on_no_moves',
			'flip',
			'crank',
		},
		card_fronts = {
			'antennae',
			'big',
			'interstellar',
			'dynamic',
			'placeholder',
			-- begin guest artist decks
			'casino',
			'shattered',
			'reelistic',
			'bedbeard',
			'void',
		},
		card_backs = {
			'antennae',
			'logo',
			'simple',
			'gradient',
			'feather',
			'dino',
			'smiley',
			'fullmoon',
			'breakfast',
			'lavalamp',
			'nosignal',
			'peedee',
			'catalog',
			'bunny',
			'pesto',
			'spiral',
			'nest',
			'plaid',
			'checker',
			'circles',
			'skull',
			'x',
			-- begin guest artist backs
			'joker',
			'shattered',
			'reelistic',
			'bedbeard',
			'groove',
			'void',
			'void_alt',
		},
		cursors = {
			'cartoon',
			'pinky',
			'triangle',
			'heart',
			'diamond',
			'club',
			'spade',
			'crank',
			'pointer',
			'retro_light',
			'retro_dark',
			'paw_light',
			'paw_gray',
			'paw_dark',
			'stick',
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

	self:render_cards(save.custom_card_front, save.custom_card_back, false)

	vars.stock_card_fronts = #vars.card_fronts
	vars.stock_card_backs = #vars.card_backs

	local custom_cards = pd.file.listFiles('custom_cards/')
	for i = 1, #custom_cards do
		if pd.file.exists('custom_cards/' .. custom_cards[i] .. 'clubs1.pdi') then
			table.insert(vars.card_fronts, sub(custom_cards[i], 1, -2))
		end
		if pd.file.exists('custom_cards/' .. custom_cards[i] .. 'back.pdi') then
			table.insert(vars.card_backs, sub(custom_cards[i], 1, -2))
		end
	end

	if save.control_bar then
		vars.control_offset = 0
		vars.control_target = 0
	else
		vars.control_offset = 20
		vars.control_target = 20
	end

	set_music_level(1)
end

function settings:update()
	if pd.buttonJustPressed('up') then self:keypressed('up') end
	if pd.buttonJustPressed('down') then self:keypressed('down') end
	if pd.buttonJustPressed('left') then self:keypressed('left') end
	if pd.buttonJustPressed('right') then self:keypressed('right') end
	if pd.buttonJustPressed('a') then self:keypressed('a') end
	if pd.buttonJustPressed('b') then self:keypressed('b') end

	-- offset number for category slider
	if vars.category_target ~= nil and vars.category_offset ~= nil then
		vars.category_offset += (vars.category_target - vars.category_offset) * 0.5
		if vars.category_offset > (vars.category_target - 0.1) and vars.category_offset < (vars.category_target + 0.1) then
			vars.category_offset = vars.category_target
		end
	end

	-- offset number for control bar
	if vars.control_target ~= nil and vars.control_offset ~= nil then
		vars.control_offset += (vars.control_target - vars.control_offset) * 0.75
		if vars.control_offset > (vars.control_target - 0.1) and vars.control_offset < (vars.control_target + 0.1) then
			vars.control_offset = vars.control_target
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

function settings:draw()
	-- defining hot variables
	local sel = vars.selection
	local cat = vars.categories[vars.category_selection]
	local cat_sels = vars[cat .. '_selections']
	local cat_sel = cat_sels[sel]

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
		drawtext(sel == i and pixolde_bold or pixolde, text('settings_' .. cat_sels[i]), 10, 23 + (i * 15))
		drawtext(sel == i and pixolde_bold or pixolde, self:status(cat_sels[i]), 240, 23 + (i * 15), right)
	end

	setcolor(255, 255, 255, 1, 'black')
	drawline(250, 0, 250, 240)

	if cat_sel == 'card_front' then
		if save.custom_card_front then
			if vars.metadata_front ~= nil then
				local by = vars.metadata_front.card_maker
				gfx.drawText(text('settings_' .. cat_sel .. '_desc') .. text('settings_card_front_by') .. (by == 'credits_card_front_' .. save.card_front and '*rae*.' or '*' .. by .. '*.'), 260, 10)
			else
				gfx.drawText(text('settings_' .. cat_sel .. '_desc'), 260, 10)
			end
		else
			local by = text('credits_card_front_' .. save.card_front)
			gfx.drawText(text('settings_' .. cat_sel .. '_desc') .. text('settings_card_front_by') .. (by == 'credits_card_front_' .. save.card_front and '*rae*.' or '*' .. by .. '*.'), 260, 10)
		end
	elseif cat_sel == 'card_back' then
		if save.custom_card_back then
			if vars.metadata_back ~= nil then
				local by = vars.metadata_back.card_maker
				gfx.drawText(text('settings_' .. cat_sel .. '_desc') .. text('settings_card_back_by') .. (by == 'credits_card_back_' .. save.card_back and '*rae*.' or '*' .. by .. '*.'), 260, 10)
			else
				gfx.drawText(text('settings_' .. cat_sel .. '_desc'), 260, 10)
			end
		else
			local by = text('credits_card_back_' .. save.card_back)
			gfx.drawText(text('settings_' .. cat_sel .. '_desc') .. text('settings_card_back_by') .. (by == 'credits_card_back_' .. save.card_back and '*rae*.' or '*' .. by .. '*.'), 260, 10)
		end
	else
		gfx.drawText(text('settings_' .. cat_sel .. '_desc'), 260, 10)
	end

	-- customization preview
	if cat == 'customization' and sel <= 5 then
		local offset = save.control_bar and 0 or 22

		drawimage(assets.customization_backdrop, 259, 139 + offset)

		drawimage(assets.card_front, 265, 145 + offset)
		drawimage(assets.card_back, 315, 145 + offset)
		drawimage(assets.cursor, 272, 182 + offset)
	end

	if vars.control_offset < 20 then
		local offset = vars.control_offset
		-- drawing control bar
		setcolor(0, 0, 0, 1, 'black')
		fillrect(0, 220 + offset, 400, 20)
		setcolor(255, 255, 255, 1, 'black')

		local controls

		-- parsing controls based on context
		if vars.handler == '' then
			controls = text('control_pleasewait')
		else
			controls = text('control_category') .. text('control_move_vert')
			if (cat == 'gameplay' and not (cat_sel == 'crank_direction' or cat_sel == 'shoulddo24hour')) or (cat_sel == 'undo' or cat_sel == 'prompt_on_no_moves' or cat_sel == 'flip' or cat_sel == 'prompt_on_no_moves' or cat_sel == 'bold_text') then
				controls = controls .. text('control_toggle')
			else
				controls = controls .. text('control_change')
			end
			controls = controls .. text('control_back')
		end
		drawtext(pixolde_inverted, controls, 5, 223 + offset)

		local time = gettime()
		local hour = time.hour
		local minute = time.minute
		drawtext(pixolde_inverted, (is24hour() and (format("%02d:%02d", hour, minute)) or (format("%01d:%02d", ((hour % 12) == 0 and 12 or (hour % 12)), minute)) .. (hour < 12 and 'a' or 'p')), 373, 223 + offset, right)

		local bat_stat = pd.getPowerStatus()
		if bat_stat.charging then
			if bat_stat.screws then
				drawimagetable(assets.battery, 7, 380, 225 + offset)
			else
				drawimagetable(assets.battery, 6, 380, 225 + offset)
			end
		else
			local battery = pd.getBatteryPercentage()
			drawimagetable(assets.battery, ceil(battery / 20), 380, 225 + offset)
		end
	else
		setcolor(255, 255, 255, 1, 'black')
	end

	if vars.reload then
		pd.display.flush()
		load_card_images(save.custom_card_front, save.custom_card_back)
		vars.reload = false
		vars.handler = 'settings'
	end
end

function settings:render_cards(custom_front, custom_back, use_same_front)
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
	if custom_back then
		vars.metadata_back = pd.datastore.read('custom_cards/' .. save.card_back .. '/metadata')
		assets.card_back = newimage('custom_cards/' .. save.card_back .. '/back')
	else
		assets.card_back = newimage('images/cards/' .. save.card_back .. '/back')
	end
	local rand
	local rand_card
	if use_same_front then
		rand = vars.rand_suit
		rand_card = vars.rand_card
	else
		rand = randInt(1, 4)
		rand_card = randInt(1, 13)
	end
	local rand_suit = rand == 1 and 'clubs' or rand == 2 and 'hearts' or rand == 3 and 'spades' or rand == 4 and 'diamonds'
	if custom_front then
		vars.metadata_front = pd.datastore.read('custom_cards/' .. save.card_front .. '/metadata')
		assets.card_front = newimage('custom_cards/' .. save.card_front .. '/' .. rand_suit .. rand_card)
	else
		assets.card_front = newimage('images/cards/' .. save.card_front .. '/' .. rand_suit .. rand_card)
	end
	assets.cursor = newimage('images/cursors/' .. save.cursor)
	vars.rand_suit = rand
	vars.rand_card = rand_card
end

function settings:status(item)
	if item == 'deck_draw' or item == 'possible' or item == 'stack_anywhere' or item == 'deck_passes' or item == 'auto' or item == 'crank' or item == 'cursor' or item == 'crank_direction' or item == 'shoulddo24hour' or item == 'undo_limit' or item == 'scoring' then
		return text('settings_' .. item .. '_' .. tostring(save[item]))
	elseif item == 'card_front' then
		if save.custom_card_front then
			if vars.metadata_front ~= nil then
				return vars.metadata_front.card_alias
			else
				return text('control_pleasewait')
			end
		else
			return text('settings_' .. item .. '_' .. tostring(save[item]))
		end
	elseif item == 'card_back' then
		if save.custom_card_back then
			if vars.metadata_back ~= nil then
				return vars.metadata_back.card_alias
			else
				return text('control_pleasewait')
			end
		else
			return text('settings_' .. item .. '_' .. tostring(save[item]))
		end
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
		elseif button == 'down' then
			vars.selection += 1
			if vars.selection > #cat_sels then
				vars.selection = #cat_sels
				playsound(doink)
			else
				playsound(move)
				vars.hit_edge = false
			end
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
		elseif button == 'a' then
			if cat_sel == 'music' then
				save.music = not save.music
				if save.music then
					load_music(1)
				else
					stop_music()
				end
			elseif cat_sel == 'sfx' then
				save.sfx = not save.sfx
				load_common_sfx()
			elseif cat_sel == 'card_sfx' then
				save.card_sfx = not save.card_sfx
				load_common_sfx()
			elseif cat_sel == 'timer' then
				save.timer = not save.timer
			elseif cat_sel == 'move_count' then
				save.move_count = not save.move_count
			elseif cat_sel == 'control_bar' then
				save.control_bar = not save.control_bar
				if save.control_bar then
					vars.control_target = 0
				else
					vars.control_target = 20
				end
			elseif cat_sel == 'shoulddo24hour' then
				save.shoulddo24hour += 1
				if save.shoulddo24hour > 2 then
					save.shoulddo24hour = 0
				end
			elseif cat_sel == 'loop' then
				save.loop = not save.loop
				elseif cat_sel == 'crank_direction' then
				save.crank_direction += 1
				if save.crank_direction > 2 then
					save.crank_direction = 0
				end
			elseif cat_sel == 'deck_draw' then
				if save.deck_draw == 1 then
					save.deck_draw = 3
				else
					save.deck_draw = 1
				end
			elseif cat_sel == 'scoring' then
				if save.scoring == 'standard' then
					save.scoring = 'vegas'
				elseif save.scoring == 'vegas' then
					save.scoring = 'vegas_cumulative'
				elseif save.scoring == 'vegas_cumulative' then
					save.scoring = 'off'
				elseif save.scoring == 'off' then
					save.scoring = 'standard'
				end
			elseif cat_sel == 'undo' then
				save.undo = not save.undo
			elseif cat_sel == 'flip' then
				save.flip = not save.flip
			elseif cat_sel == 'undo_limit' then
				if save.undo_limit == 0 then
					save.undo_limit = 1
				elseif save.undo_limit == 1 then
					save.undo_limit = 5
				elseif save.undo_limit == 5 then
					save.undo_limit = 10
				elseif save.undo_limit == 10 then
					save.undo_limit = 25
				elseif save.undo_limit == 25 then
					save.undo_limit = 50
				elseif save.undo_limit == 50 then
					save.undo_limit = 100
				elseif save.undo_limit == 100 then
					save.undo_limit = 250
				elseif save.undo_limit == 250 then
					save.undo_limit = 500
				elseif save.undo_limit == 500 then
					save.undo_limit = 0
				end
			elseif cat_sel == 'possible' then
				save.possible = not save.possible
			elseif cat_sel == 'prompt_on_no_moves' then
				save.prompt_on_no_moves = not save.prompt_on_no_moves
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
				if sel >= vars.stock_card_fronts and sel < #vars.card_fronts then
					save.custom_card_front = true
				else
					save.custom_card_front = false
				end
				save.card_front = vars.card_fronts[(sel == #vars.card_fronts and 1 or sel + 1)]
				self:render_cards(save.custom_card_front, save.custom_card_back, false)
				vars.reload = true
			elseif cat_sel == 'card_back' then
				local sel = 0
				for i = 1, #vars.card_backs do
					if save.card_back == vars.card_backs[i] then
						sel = i
						break
					end
				end
				if sel >= vars.stock_card_backs and sel < #vars.card_backs then
					save.custom_card_back = true
				else
					save.custom_card_back = false
				end
				save.card_back = vars.card_backs[(sel == #vars.card_backs and 1 or sel + 1)]
				self:render_cards(save.custom_card_front, save.custom_card_back, true)
			elseif cat_sel == 'cursor' then
				local sel = 0
				for i = 1, #vars.cursors do
					if save.cursor == vars.cursors[i] then
						sel = i
						break
					end
				end
				save.cursor = vars.cursors[(sel == #vars.cursors and 1 or sel + 1)]
				self:render_cards(save.custom_card_front, save.custom_card_back, true)
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
				self:render_cards(save.custom_card_front, save.custom_card_back, true)
			elseif cat_sel == 'card_guide' then
				save.card_guide = ((save.card_guide * 10) + 1) / 10
				if save.card_guide == 1 then save.card_guide = 1 end
				if save.card_guide > 1 then
					save.card_guide = 0
				end
				self:render_cards(save.custom_card_front, save.custom_card_back, true)
			end
			playsound(accept)
		elseif button == 'b' then
			playsound(bump)
			scenemanager:transitionsceneback(title, 'settings')
		end
	end
end