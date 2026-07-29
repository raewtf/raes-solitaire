local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local floor <const> = math.floor
local min <const> = math.min
local max <const> = math.max
local find <const> = string.find
local format <const> = string.format

class('klondike').extends(gfx.sprite)
function klondike:init(...)
	klondike.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here

	function pd.gameWillPause()
		local menu = pd.getSystemMenu()
		menu:removeAllMenuItems()
		if vars.handler ~= '' and not find(vars.handler, 'box') then
			menu:addMenuItem(text('slide_titlescreen'), function()
				self:save_game()
				scenemanager:transitionsceneback(title)
			end)
			menu:addMenuItem(text('slide_replaydeal'), function()
				self:redeal(true)
			end)
			menu:addMenuItem(text('slide_newdeal'), function()
				self:redeal(false)
			end)
		end
	end

	self:initialize(args)
	gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
		self:draw()
	end)

	self:add()
end

function klondike:initialize(args)
	assets = {
		card_back = newimage('images/cards/' .. save.card_back .. '/back'),
		cursor = newimage('images/cursors/' .. save.cursor),
		box = newimage('images/box'),
		background = newimage(400, 240, 'white'),
		stack = newimage('images/stack'),
	}

	gfx.pushContext(assets.background)
		-- backdrop
		setcolor(0, 0, 0, -(save.backdrop - 1), 'black')
		fillrect(0, 0, 400, 240)

		-- card guides
		for i = 1, 2 do
			if i == 1 then
				setcolor(255, 255, 255, 1, 'white')
			else
				setcolor(0, 0, 0, -(save.card_guide - 1), 'black')
			end
			drawrect(30, 14, 40, 60, 5)
			drawrect(80, 14, 40, 60, 5)

			drawrect(180, 14, 40, 60, 5)
			drawrect(230, 14, 40, 60, 5)
			drawrect(280, 14, 40, 60, 5)
			drawrect(330, 14, 40, 60, 5)

			drawrect(30, 80, 40, 60, 5)
			drawrect(80, 80, 40, 60, 5)
			drawrect(130, 80, 40, 60, 5)
			drawrect(180, 80, 40, 60, 5)
			drawrect(230, 80, 40, 60, 5)
			drawrect(280, 80, 40, 60, 5)
			drawrect(330, 80, 40, 60, 5)
		end

		setcolor(255, 255, 255, 1, 'black')
	gfx.popContext()

	vars = {
		deck = args[1] or {}, -- where the reserve cards are. can accept a deck if provided one
		continue = args[1] or false, -- if true, attempt to read status info from save-data
		deck_reverse = {}, -- where the cards you pull from the deck wind up
		hand = {}, -- where you hold the cards temporarily
		banks = {
			{},
			{},
			{},
			{}
		}, -- where you're trying to get the cards in the end
		slots = {
			{},
			{},
			{},
			{},
			{},
			{},
			{}
		}, -- where the cards start out
		handler = '', -- playing, slot1 thru slot7, bank1 thru bank4, deck_reverse
		selection = 'slot1', -- slot1 thru slot7; bank1 thru bank4; deck, deck_reverse
		cursor = {x = 37, y = 280, tx = 37, ty = 240}, -- position of the cursor
		reversing_deck = false, -- if the deck is reversing, you can't attempt to futz with it.
		handler_x = 0, -- saving the X of the card last picked up by the hand so it can go back home later
		deck_passes = save.deck_passes,
		deck_passes_left = save.deck_passes, -- number of passes through the deck remaining (0 = infinite)
		left = true, -- last horizontal movement of the D-pad, for slot 3
		undo_history = {},
		time = 0,
		moves = 0,
		box_selection = 1,
		box_moving = true,
		box_hit_edge = false,
		extras_width = 0,
		seen_autocomplete_prompt = false,
	}

	-- prep timer for dialog box
	newtimer('box', 0, 1, 1)

	self:extras_width()

	-- anim for cursor
	loopingtimer('anim_cursor', 1000, -5, 0, 'outSine')

	for i = 2, 5 do
		assets['card_backflip' .. i - 1] = assets.card_back:scaledImage(1.2 - (i * 0.2), 1)
	end

	newmusic('audio/music/level1')

	afterdelay('transition_delay', transitiontime, function()
		if vars.continue and save.klondike_snapshot ~= nil then -- continue data found, and we wanna use it. let's plunk it in
			-- TODO: entrance animation for cards
			vars.undo_history = deepcopy(save.klondike_snapshot.undo_history)
			vars.deck = deepcopy(save.klondike_snapshot.deck)
			vars.deck_reverse = deepcopy(save.klondike_snapshot.deck_reverse)
			vars.reversing_deck = save.klondike_snapshot.reversing_deck
			vars.deal = deepcopy(save.klondike_snapshot.deal)

			if vars.reversing_deck then
				-- TODO: find a solution to this that's a bit less broken
				if vars.undo_history[#vars.undo_history].type == 'deck_reverse' then
					-- TODO: move cards into place
				else
					-- TODO: move cards into place
				end
			end

			vars.hand = deepcopy(save.klondike_snapshot.hand)
			vars.bank = deepcopy(save.klondike_snapshot.banks)
			vars.slots = deepcopy(save.klondike_snapshot.slots)
			vars.cursor = deepcopy(save.klondike_snapshot.cursor)

			-- mask any cursor animation
			vars.cursor.x = vars.cursor.tx
			vars.cursor.y = vars.cursor.ty

			vars.deck_passes = save.klondike_snapshot.deck_passes
			vars.deck_passes_left = save.klondike_snapshot.deck_passes_left
			vars.time = save.klondike_snapshot.time
			vars.moves = save.klondike_snapshot.moves
			vars.handler = save.klondike_snapshot.handler
			vars.selection = save.klondike_snapshot.selection
			-- TODO: newmusic()
		else -- start a new game
			save.games_played_klondike += 1

			local deck = {} -- for initial shuffle
			local new_deal = false

			if save.possible then
				-- adding cards into final banks
				for i = 1, 13 do
					if vars.deck[1] == nil then
						new_deal = true
						table.insert(vars.banks[1], {t = 'clubs', i = i, f = 0, x = 50, y = -150, tf = 0, tx = 50, ty = -150})
						table.insert(vars.banks[2], {t = 'diamonds', i = i, f = 0, x = 50, y = -150, tf = 0, tx = 50, ty = -150})
						table.insert(vars.banks[3], {t = 'hearts', i = i, f = 0, x = 50, y = -150, tf = 0, tx = 50, ty = -150})
						table.insert(vars.banks[4], {t = 'spades', i = i, f = 0, x = 50, y = -150, tf = 0, tx = 50, ty = -150})
					end
				end

				if new_deal then
					setRandomSeed(pd.getSecondsSinceEpoch())

					-- sorting the topmost cards from the banks into the slots
					for i = 1, 7 do
						for n = i, 7 do
							local pick_rand = randInt(1, 4)
							local pick_deck = vars.banks[pick_rand]
							table.insert(vars.slots[n], pick_deck[#pick_deck])
							table.remove(pick_deck, #pick_deck)
						end
					end

					-- placing the generated slots back into the deck
					for i = 1, 7 do
						for n = 1, #vars.slots[i] do
							table.insert(deck, vars.slots[i][1])
							table.remove(vars.slots[i], 1)
						end
					end

					-- placing the rest of the banked cards into the deck as well
					local todeck = {}

					for i = 1, 4 do
						for n = 1, #vars.banks[i] do
							table.insert(todeck, vars.banks[i][1])
							table.remove(vars.banks[i], 1)
						end
					end

					local twodeck = self:shuffle(todeck)
					todeck = nil

					for i = 1, #twodeck do
						table.insert(deck, twodeck[1])
						table.remove(twodeck, 1)
					end

					twodeck = nil

					-- shuffling the deck
					vars.deck = deepcopy(deck)
				end
			else
				for i = 1, 13 do
					-- add cards to deck, starting at position for deck drop anim during initial shuffle
					-- only adding if the deck isn't already positioned, though
					if vars.deck[1] == nil then
						new_deal = true
						table.insert(deck, {t = 'clubs', i = i, f = 0, x = 50, y = -150, tf = 0, tx = 50, ty = -150})
						table.insert(deck, {t = 'diamonds', i = i, f = 0, x = 50, y = -150, tf = 0, tx = 50, ty = -150})
						table.insert(deck, {t = 'hearts', i = i, f = 0, x = 50, y = -150, tf = 0, tx = 50, ty = -150})
						table.insert(deck, {t = 'spades', i = i, f = 0, x = 50, y = -150, tf = 0, tx = 50, ty = -150})
					end
				end

				-- shuffle the deck if it's a brand new draw
				if new_deal then
					vars.deck = self:shuffle(deck) -- shuffle the deck
				end
			end

			vars.deal = deepcopy(vars.deck) -- for "replay (same deal)"
			deck = nil

			local last_card_dealt = false

			-- deal the top-most cards into the slots
			for i = 1, 7 do
				afterdelay('slot_shuffle' .. i, ((i - 1) * (300 - (i * 15))) / (save.anim_speed / 100), function()
					for n = i, 7 do
						afterdelay('card_shuffle' .. n, ((n - 1) * 30) / (save.anim_speed / 100), function()
							if save.anim_speed > 0 then randomizecardsfx(pick1, pick2, pick3, pick4, pick5) end
							if n == i then vars.deck[1].tf = 1 end
							vars.deck[1].x = 200 + ((n - 4) * 40)
							vars.deck[1].y = 240
							vars.deck[1].tx = 200 + ((n - 4) * 50)
							vars.deck[1].ty = 80 + (#vars.slots[n] * (save.control_bar and 10 or 14))
							table.insert(vars.slots[n], vars.deck[1]) -- insert the card into the appropriate slot
							table.remove(vars.deck, 1) -- remove it from the shuffled deck
							if i == 7 and n == 7 then
								last_card_dealt = true
								-- drop in deck
								if save.anim_speed > 0 then randomizecardsfx(fan1, fan2, fan3, fan4, fan5) end
								for i = 1, #vars.deck do
									afterdelay('deck_shuffle' .. i, (i * 10) / (save.anim_speed / 100), function()
										vars.deck[i].ty = (15 - (i * 0.2))
									end)
									if i == #vars.deck then
										afterdelay('give_input', 700 / (save.anim_speed / 100), function()
											vars.handler = 'playing'
											newmusic('audio/music/level4')
										end)
									end
								end
							end
						end)
					end
				end)
			end

			if save.anim_speed == 0 then randomizecardsfx(pick1, pick2, pick3, pick4, pick5) end
		end
	end)
end

function klondike:update()
	if pd.buttonJustPressed('up') then self:keypressed('up') end
	if pd.buttonJustPressed('down') then self:keypressed('down') end
	if pd.buttonJustPressed('left') then self:keypressed('left') end
	if pd.buttonJustPressed('right') then self:keypressed('right') end
	if pd.buttonJustPressed('a') then self:keypressed('a') end
	if pd.buttonJustPressed('b') then self:keypressed('b') end

	if vars.handler ~= '' then
		local ticks = pd.getCrankTicks(4)

		if find(vars.handler, 'box') and not vars.box_moving then
			if ticks > 0 then
				local selmax = (vars.handler == 'box_complete' and 3 or vars.handler == 'box_autocomplete' and 2)

				vars.box_selection += 1
				if vars.box_selection > selmax then
					vars.box_selection = selmax
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
			save.gametime_klondike += delta
			vars.time += delta

			if (save.crank_direction == 0 and ticks > 0) or (save.crank_direction == 1 and ticks < 0) or (save.crank_direction == 2 and ticks ~= 0) then
				if vars.handler == 'playing' then
					if save.crank == 1 then
						self:top_level_moves(false)
					elseif save.crank == 2 then
						self:top_level_moves(true)
					elseif save.crank == 3 then
						self:stack_level_moves()
					end
				else
					if save.quickpick and vars.selection ~= 'deck' and vars.handler == vars.selection then self:pick_card() end
				end
			end
		end
	end

	local card
	local multiplier = 0.5 + ((save.anim_speed - 100) / 400)
	local facing_up = 0

	-- update position data of cards
	for i = 1, #vars.deck do
		facing_up += 1
		card = vars.deck[i]
		if save.anim_speed == 0 then
			if card.f ~= card.tf then card.f = card.tf end
			if card.x ~= card.tx then card.x = card.tx end
			if card.y ~= card.ty then card.y = card.ty end
		else
			if card.f ~= card.tf then
				card.f = card.f + (card.tf - card.f) * multiplier
				if (card.f >= card.tf - 0.05) and (card.f <= card.tf + 0.05) then card.f = card.tf end
			end
			if card.x ~= card.tx then
				card.x = card.x + (card.tx - card.x) * multiplier
				if (card.x >= card.tx - 0.5) and (card.x <= card.tx + 0.5) then card.x = card.tx end
			end
			if card.y ~= card.ty then
				card.y = card.y + (card.ty - card.y) * multiplier
				if (card.y >= card.ty - 0.5) and (card.y <= card.ty + 0.5) then card.y = card.ty end
			end
		end
	end
	for i = 1, #vars.deck_reverse do
		card = vars.deck_reverse[i]
		if card.tf == 1 then facing_up += 1 end
		if save.anim_speed == 0 then
			if card.f ~= card.tf then card.f = card.tf end
			if card.x ~= card.tx then card.x = card.tx end
			if card.y ~= card.ty then card.y = card.ty end
		else
			if card.f ~= card.tf then
				card.f = card.f + (card.tf - card.f) * multiplier
				if (card.f >= card.tf - 0.05) and (card.f <= card.tf + 0.05) then card.f = card.tf end
			end
			if card.x ~= card.tx then
				card.x = card.x + (card.tx - card.x) * multiplier
				if (card.x >= card.tx - 0.5) and (card.x <= card.tx + 0.5) then card.x = card.tx end
			end
			if card.y ~= card.ty then
				card.y = card.y + (card.ty - card.y) * multiplier
				if (card.y >= card.ty - 0.5) and (card.y <= card.ty + 0.5) then card.y = card.ty end
			end
		end
	end
	for i = 1, #vars.hand do
		card = vars.hand[i]
		if save.anim_speed == 0 then
			if card.f ~= card.tf then card.f = card.tf end
			if card.x ~= card.tx then card.x = card.tx end
			if card.y ~= card.ty then card.y = card.ty end
		else
			if card.f ~= card.tf then
				card.f = card.f + (card.tf - card.f) * multiplier
				if (card.f >= card.tf - 0.05) and (card.f <= card.tf + 0.05) then card.f = card.tf end
			end
			if card.x ~= card.tx then
				card.x = card.x + (card.tx - card.x) * multiplier
				if (card.x >= card.tx - 0.5) and (card.x <= card.tx + 0.5) then card.x = card.tx end
			end
			if card.y ~= card.ty then
				card.y = card.y + (card.ty - card.y) * multiplier
				if (card.y >= card.ty - 0.5) and (card.y <= card.ty + 0.5) then card.y = card.ty end
			end
		end
	end
	for i = 1, 4 do
		for n = 1, #vars.banks[i] do
			card = vars.banks[i][n]
			if card.tf == 1 then facing_up += 1 end
			if save.anim_speed == 0 then
				if card.f ~= card.tf then card.f = card.tf end
				if card.x ~= card.tx then card.x = card.tx end
				if card.y ~= card.ty then card.y = card.ty end
			else
				if card.f ~= card.tf then
					card.f = card.f + (card.tf - card.f) * multiplier
					if (card.f >= card.tf - 0.05) and (card.f <= card.tf + 0.05) then card.f = card.tf end
				end
				if card.x ~= card.tx then
					card.x = card.x + (card.tx - card.x) * multiplier
					if (card.x >= card.tx - 0.5) and (card.x <= card.tx + 0.5) then card.x = card.tx end
				end
				if card.y ~= card.ty then
					card.y = card.y + (card.ty - card.y) * multiplier
					if (card.y >= card.ty - 0.5) and (card.y <= card.ty + 0.5) then card.y = card.ty end
				end
			end
		end
	end
	for i = 1, 7 do
		for n = 1, #vars.slots[i] do
			card = vars.slots[i][n]
			if card.tf == 1 then facing_up += 1 end
			if save.anim_speed == 0 then
				if card.f ~= card.tf then card.f = card.tf end
				if card.x ~= card.tx then card.x = card.tx end
				if card.y ~= card.ty then card.y = card.ty end
			else
				if card.f ~= card.tf then
					card.f = card.f + (card.tf - card.f) * multiplier
					if (card.f >= card.tf - 0.05) and (card.f <= card.tf + 0.05) then card.f = card.tf end
				end
				if card.x ~= card.tx then
					card.x = card.x + (card.tx - card.x) * multiplier
					if (card.x >= card.tx - 0.5) and (card.x <= card.tx + 0.5) then card.x = card.tx end
				end
				if card.y ~= card.ty then
					card.y = card.y + (card.ty - card.y) * multiplier
					if (card.y >= card.ty - 0.5) and (card.y <= card.ty + 0.5) then card.y = card.ty end
				end
			end
		end
	end

	-- if all the cards are either in the deck or facing upright (and there are no cards in the hand)
	if facing_up == 52 and save.auto > 0 and (vars.handler ~= '' and not find(vars.handler, 'box')) and not vars.seen_autocomplete_prompt then
		vars.seen_autocomplete_prompt = true
		if save.auto == 1 then -- prompt
			vars.handler = 'box_autocomplete'
			vars.box_selection = 1
			newmusic('audio/music/level1')
			resettimer('box', 150, value('box'), 0, 'outSine', function()
				vars.box_moving = false
			end)
		elseif save.auto == 2 then -- auto
			self:auto()
		end
	end

	-- cursor logic
	local table, modifier = self:get_table_from_selection(true)

	if vars.handler ~= '' and not find(vars.handler, 'box') then
		local table_len = #table
		if table_len == 0 then
			if find(vars.selection, 'bank') then
				vars.cursor.tx = 137 + (modifier * 50)
				vars.cursor.ty = 60
			elseif find(vars.selection, 'slot') then
				vars.cursor.tx = 187 + ((modifier - 4) * 50)
				vars.cursor.ty = 125
			elseif vars.selection == 'deck' then
				vars.cursor.tx = 37
				vars.cursor.ty = 60
			elseif vars.selection == 'deck_reverse' then
				vars.cursor.tx = 87
				vars.cursor.ty = 60
			end
		else
			vars.cursor.tx = table[table_len].tx - 13
			vars.cursor.ty = table[table_len].ty + 45
		end
	end

	if save.anim_speed == 0 then
		vars.cursor.x = vars.cursor.tx
		vars.cursor.y = vars.cursor.ty
	else
		vars.cursor.x = vars.cursor.x + (vars.cursor.tx - vars.cursor.x) * multiplier
		vars.cursor.y = vars.cursor.y + (vars.cursor.ty - vars.cursor.y) * multiplier
	end
end

function klondike:draw()
	local selection = vars.selection
	local handler = vars.handler
	local hand = vars.hand
	local control_bar = save.control_bar

	drawimage(assets.background, 0, 0)

	-- draw cards in slots
	local slots = vars.slots
	local slotsi

	for i = 1, 7 do
		slotsi = slots[i]
		for n = 1, #slotsi do
			self:draw_card(slotsi[n])
		end
	end

	-- draw cards in deck
	local deck = vars.deck
	local decki
	local deckl

	if #deck > 0 then
		if deck[1].f == deck[1].tf then drawimage(assets.stack, ((deck[1].x - 20) // 2) * 2, ((deck[1].y) // 2) * 2) end
		for i = 1, #deck do
			decki = deck[i]
			if i == 1 then
				self:draw_card(decki)
			else
				if deckl.x == decki.x and deckl.y == decki.y and deckl.f == decki.f then
					break
				else
					self:draw_card(decki)
				end
			end
			deckl = decki
		end
	end

	-- draw cards in reverse deck
	local deck_reverse = vars.deck_reverse
	local deck_reversei
	local deck_reversel

	if #deck_reverse > 0 then
		if deck_reverse[1].f == deck_reverse[1].tf then drawimage(assets.stack, ((deck_reverse[1].x - 20) // 2) * 2, ((deck_reverse[1].y) // 2) * 2) end
		for i = 1, #deck_reverse do
			deck_reversei = deck_reverse[i]
			if i == 1 then
				self:draw_card(deck_reversei)
			else
				if deck_reversel.x == deck_reversei.x and deck_reversel.y == deck_reversei.y and deck_reversel.f == deck_reversei.f then
					break
				else
					self:draw_card(deck_reversei)
				end
			end
			deck_reversel = deck_reversei
		end
	end

	-- draw cards in banks
	local banks = vars.banks
	local banksi
	local banksin
	local banksil

	for i = 1, 4 do
		banksi = banks[i]
		if #banksi > 0 then
			drawimage(assets.stack, ((banksi[1].x - 20) // 2) * 2, ((banksi[1].y) // 2) * 2) -- fake stack for height factor
			for n = 1, #banksi do
				banksin = banksi[n]
				if n == 1 then -- if this is the first card, we should draw it no matter what.
					self:draw_card(banksin)
				else
					if banksil.x == banksin.x and banksil.y == banksin.y then
						-- if there's a card above this at the same X and Y position, then we know it and everything else is obscured in the stack. skip the rest of the loop
						break
					else
						-- this card is gonna be visible on-screen, and we should draw it.
						self:draw_card(banksin)
					end
				end
				banksil = banksin
			end
		end
	end

	-- drawing the cursor
	local cursor = vars.cursor

	drawimage(assets.cursor, (cursor.x // 2) * 2, ((cursor.y + value('anim_cursor')) // 2) * 2)

	-- draw cards in hand
	for i = #hand, 1, -1 do self:draw_card(hand[i]) end

	-- draw dialog box, if available
	if value('box') < 1 then
		setcolor(0, 0, 0, (-value('box') + 1) * 0.75, 'black')
		fillrect(0, 0, 400, 240)

		local box_offset = (value('box') * 200) + (control_bar and -10 or 0)

		drawimage(assets.box, 79, 39 + box_offset)

		if vars.handler == 'box_complete' then
			drawtext(pixolde_bold, text('box_complete'), 200, 80 + box_offset, center)
			drawtext(vars.box_selection == 1 and pixolde_italic or pixolde, text('box_newdeal'), 200, 110 + box_offset, center)
			drawtext(vars.box_selection == 2 and pixolde_italic or pixolde, text('box_replaydeal'), 200, 125 + box_offset, center)
			drawtext(vars.box_selection == 3 and pixolde_italic or pixolde, text('box_titlescreen'), 200, 140 + box_offset, center)
		elseif vars.handler == 'box_autocomplete' then
			drawtext(pixolde_bold, text('box_autocomplete'), 200, 65 + box_offset, center)
			drawtext(pixolde, text('box_autocomplete_desc'), 200, 85 + box_offset, center)
			drawtext(vars.box_selection == 1 and pixolde_italic or pixolde, text('box_sure'), 200, 140 + box_offset, center)
			drawtext(vars.box_selection == 2 and pixolde_italic or pixolde, text('box_nothanks'), 200, 155 + box_offset, center)
		end
	end

	-- drawing additional metadata
	local extras = '  '

	if save.timer then -- show timer
		local time = vars.time
		extras = extras .. '⏱️ ' .. floor(time / 60) .. ':' .. format('%02d', floor(time % 60)) .. '  '
	end

	if save.move_count then -- show move counter
		extras = extras .. '🔄 ' .. vars.moves .. '  '
	end

	if vars.deck_passes > 0 then -- if deck passes are limited, show how many are left
		extras = extras .. '🃏 ' .. vars.deck_passes_left .. '  '
	end

	if extras ~= '  ' then -- draw if any metadata is shown
		setcolor(0, 0, 0, 1, 'black')
		fillrect(5, 200 + (save.control_bar and 0 or 20), vars.extras_width, 25, 5)
		setcolor(255, 255, 255, 1, 'black')
		drawtext(pixolde_inverted, extras, 6, 204 + (control_bar and 0 or 20))
	end

	if control_bar then
		local table = self:get_table_from_selection(true)

		-- drawing control bar
		setcolor(0, 0, 0, 1, 'black')
		fillrect(0, 220, 400, 20)
		setcolor(255, 255, 255, 1, 'black')

		-- parsing controls based on context
		local controls = ''
		if handler == '' then
			controls = controls .. text('control_pleasewait')
		elseif handler == 'auto' then
			controls = controls .. text('control_auto')
		elseif find(handler, 'box_') then
			controls = controls .. text('control_move_vert') .. text('control_select')
		else
			if handler == 'playing' then
				if selection == 'deck' then
					if (vars.deck_passes_left > 0 or vars.deck_passes == 0) and (not vars.reversing_deck) then
						if #vars.deck > 0 then
							controls = controls .. text('control_draw')
						else
							if #vars.deck_reverse > 0 then
								controls = controls .. text('control_refill')
							end
						end
					end
				elseif selection == 'deck_reverse' then
					if #vars.deck_reverse > 0 and (not vars.reversing_deck) then
						controls = controls .. text('control_pick')
					end
				elseif #table > 0 then
					controls = controls .. text('control_pick')
				end

				if save.undo and vars.undo_history[1] ~= nil and not vars.reversing_deck then
					controls = controls .. text('control_undo')
				end
			else
				if (handler == selection) and (#table > 0 and table[#table].tf == 1) and (find(handler, 'slot') or #hand == 0) then
					controls = controls .. text('control_pick')
				elseif #hand > 0 and selection ~= handler then
					if find(selection, 'bank') then
						if #table == 0 then
							if hand[#hand].i == 1 then
								controls = controls .. text('control_put')
							end
						else
							if (table[#table].t == hand[#hand].t) and (table[#table].i + 1 == hand[#hand].i) then
								controls = controls .. text('control_put')
							end
						end
					elseif find(selection, 'slot') then
						if #table == 0 then
							if hand[#hand].i == 13 or save.stack_anywhere then
								controls = controls .. text('control_put')
							end
						else
							if (self:check_stack_validity(hand[#hand], table[#table])) then
								controls = controls .. text('control_put')
							end
						end
					end
				end
				controls = controls .. text('control_put_back')
			end
			controls = controls .. text('control_settings')
		end
		drawtext(pixolde_inverted, controls, 5, 223)

		local time = gettime()
		local hour = time.hour
		local minute = time.minute
		drawtext(pixolde_inverted, (pd.shouldDisplay24HourTime() and (format("%02d:%02d", hour, minute)) or (format("%01d:%02d", ((hour % 12) == 0 and 12 or (hour % 12)), minute)) .. (hour < 12 and 'a' or 'p')), 395, 223, right)
	end


end

function klondike:get_table_from_selection(cursor)
	local table
	local modifier
	if vars.selection == 'deck' and cursor then
		table = vars.deck
	elseif vars.selection == 'deck_reverse' then
		table = vars.deck_reverse
	elseif vars.selection == 'bank1' then
		table = vars.banks[1]
		modifier = 1
	elseif vars.selection == 'bank2' then
		table = vars.banks[2]
		modifier = 2
	elseif vars.selection == 'bank3' then
		table = vars.banks[3]
		modifier = 3
	elseif vars.selection == 'bank4' then
		table = vars.banks[4]
		modifier = 4
	elseif vars.selection == 'slot1' then
		table = vars.slots[1]
		modifier = 1
	elseif vars.selection == 'slot2' then
		table = vars.slots[2]
		modifier = 2
	elseif vars.selection == 'slot3' then
		table = vars.slots[3]
		modifier = 3
	elseif vars.selection == 'slot4' then
		table = vars.slots[4]
		modifier = 4
	elseif vars.selection == 'slot5' then
		table = vars.slots[5]
		modifier = 5
	elseif vars.selection == 'slot6' then
		table = vars.slots[6]
		modifier = 6
	elseif vars.selection == 'slot7' then
		table = vars.slots[7]
		modifier = 7
	end
	return table, cursor and modifier
end

function klondike:get_table_from_handler(cursor)
	local table
	local modifier
	if vars.handler == 'deck_reverse' then
		table = vars.deck_reverse
	elseif vars.handler == 'bank1' then
		table = vars.banks[1]
		modifier = 1
	elseif vars.handler == 'bank2' then
		table = vars.banks[2]
		modifier = 2
	elseif vars.handler == 'bank3' then
		table = vars.banks[3]
		modifier = 3
	elseif vars.handler == 'bank4' then
		table = vars.banks[4]
		modifier = 4
	elseif vars.handler == 'slot1' then
		table = vars.slots[1]
		modifier = 1
	elseif vars.handler == 'slot2' then
		table = vars.slots[2]
		modifier = 2
	elseif vars.handler == 'slot3' then
		table = vars.slots[3]
		modifier = 3
	elseif vars.handler == 'slot4' then
		table = vars.slots[4]
		modifier = 4
	elseif vars.handler == 'slot5' then
		table = vars.slots[5]
		modifier = 5
	elseif vars.handler == 'slot6' then
		table = vars.slots[6]
		modifier = 6
	elseif vars.handler == 'slot7' then
		table = vars.slots[7]
		modifier = 7
	end
	return table, cursor and modifier
end

-- A button action
function klondike:pick_card()
	local selection_table = self:get_table_from_selection()
	local hand = vars.hand
	if (vars.handler == 'playing' or vars.handler == vars.selection) and (#selection_table > 0 and selection_table[#selection_table].tf == 1) and (find(vars.handler, 'slot') or (not find(vars.handler, 'slot')) and #hand == 0) then
		if (vars.selection == 'deck_reverse' and not vars.reversing_deck) or (vars.selection ~= 'deck_reverse') then
			-- We're picking up a new card! (and adding it to the stack, if necessary)
			randomizecardsfx(pick1, pick2, pick3, pick4, pick5)
			vars.handler_x = selection_table[#selection_table].tx
			selection_table[#selection_table].ty = 200
			table.insert(hand, selection_table[#selection_table])
			table.remove(selection_table, #selection_table)
			for i = 1, #hand do
				hand[i].tx = (200 - (((i - 0.5) - (#hand / 2)) * (15))) + (vars.extras_width / 2)
			end
			vars.handler = vars.selection
			if find(vars.handler, 'slot') then
				for i = 1, #selection_table do
					selection_table[i].ty = 80 + ((i - 1) * ((save.control_bar and 75 or 100) / #selection_table))
				end
			end
		end
	elseif #hand > 0 and vars.selection ~= vars.handler then -- prevent king-starting slots from being put back immediately on one bonus press
		-- We're dropping the entire stack in a new place
		if find(vars.selection, 'bank') then
			if #selection_table == 0 then
				if hand[#hand].i == 1 then
					self:put_card_down(selection_table)
				end
			else
				if (selection_table[#selection_table].t == hand[#hand].t) and (selection_table[#selection_table].i + 1 == hand[#hand].i) then
					self:put_card_down(selection_table)
				end
			end
		elseif find(vars.selection, 'slot') then
			if #selection_table == 0 then
				if hand[#hand].i == 13 or save.stack_anywhere then
					self:put_card_down(selection_table)
				end
			else
				if (self:check_stack_validity(hand[#hand], selection_table[#selection_table])) then
					self:put_card_down(selection_table)
				end
			end
		end
	end
	self:sort_3_card()
end

-- if match is true, we're putting the card somewhere new (A button action on card match)
-- if match is false, we're putting it back down where it came from (B button action)
function klondike:put_card_down(match)
	local selection_table = self:get_table_from_handler(true)
	local _, modifier = self:get_table_from_selection(true)
	local hand = vars.hand
	randomizecardsfx(put1, put2, put3, put4, put5)
	if match ~= nil then
		local existingstack = true
		if #selection_table > 0 and selection_table[#selection_table].tf ~= 1 then
			existingstack = false
			selection_table[#selection_table].tf = 1
		end
		if find(vars.handler, 'slot') then
			for i = 1, #selection_table do
				selection_table[i].ty = 80 + ((i - 1) * ((save.control_bar and 75 or 100) / #selection_table))
			end
		end
		selection_table = match

		-- calculating X placement of cards to be put down
		local table_len = #selection_table
		if table_len == 0 then
			if find(vars.selection, 'bank') then
				vars.handler_x = 150 + (modifier * 50)
			elseif find(vars.selection, 'slot') then
				vars.handler_x = 200 + ((modifier - 4) * 50)
			end
		else
			vars.handler_x = selection_table[table_len].tx
		end

		vars.moves += 1
		self:extras_width()

		table.insert(vars.undo_history, {type = 'move_card', whereitisnow = selection_table, itsposition = #selection_table + 1, whereitshouldgo = self:get_table_from_handler(true), whereitisnow_existingstack = existingstack, handler = vars.handler})
	end
	for i = 1, #hand do
		hand[#hand].tx = vars.handler_x
		if find(match ~= nil and vars.selection or vars.handler, 'slot') then
			hand[#hand].ty = 80 + (#selection_table * 10)
		else
			hand[#hand].ty = 15 - (#selection_table * 0.2)
		end
		table.insert(selection_table, hand[#hand])
		table.remove(hand, #hand)
		if #hand == 0 and find(match ~= nil and vars.selection or vars.handler, 'slot') then
			for n = 1, #selection_table do
				selection_table[n].ty = 80 + ((n - 1) * ((save.control_bar and 75 or 100) / #selection_table))
			end
		end
	end
	vars.handler = 'playing'
	self:sort_3_card()
	self:check_win()
end

function klondike:sort_3_card()
	if save.deck_draw == 3 then
		local deck_reverse = vars.deck_reverse
		-- move other cards into neat stack on far left edge
		for i = 0, #deck_reverse do
			if i ~= 0 then deck_reverse[i].tx = 100 end
		end
		-- making sure the X alignment is OK regardless of deck size
		if #deck_reverse >= 3 then
			deck_reverse[#deck_reverse - 1].tx = 125
			deck_reverse[#deck_reverse].tx = 150
		elseif #deck_reverse == 2 then
			deck_reverse[#deck_reverse].tx = 125
		end
	end
end

-- check first-level moves for the cards at the top of the stacks on the tableau
function klondike:top_level_moves(slots)
	if #vars.deck_reverse > 0 and not vars.reversing_deck then
		local go = self:first_level_move_banks(vars.deck_reverse[#vars.deck_reverse], false, vars.deck_reverse, #vars.deck_reverse)
		if go then return true end
		if slots then
			go = self:first_level_move_slots(vars.deck_reverse[#vars.deck_reverse], false, vars.deck_reverse, #vars.deck_reverse)
			if go then return true end
		end
	end
	-- check for banks first,
	for i = 1, 7 do
		if #vars.slots[i] > 0 then
			local go = self:first_level_move_banks(vars.slots[i][#vars.slots[i]], false, vars.slots[i], #vars.slots[i])
			if go then return true end
		end
	end
	-- then for slots, if needed.
	if slots then
		for i = 1, 7 do
			if #vars.slots[i] > 0 then
				local go = self:first_level_move_slots(vars.slots[i][#vars.slots[i]], false, vars.slots[i], #vars.slots[i])
				if go then return true end
			end
		end
	end
	return false
end

-- check first-level moves for entire stacks on the tableau, working from the bottom to the top
function klondike:stack_level_moves()
	if #vars.deck_reverse > 0 and not vars.reversing_deck then
		local go = self:first_level_move_banks(vars.deck_reverse[#vars.deck_reverse], false, vars.deck_reverse, #vars.deck_reverse)
		if go then return end
		go = self:first_level_move_slots(vars.deck_reverse[#vars.deck_reverse], false, vars.deck_reverse, #vars.deck_reverse)
		if go then return end
	end
	-- check for banks first,
	for i = 1, 7 do
		if #vars.slots[i] > 0 then
			local face_up_cards = 0
			for n = 1, #vars.slots[i] do
				if vars.slots[i][n].tf == 1 then
					face_up_cards += 1
				end
			end
			for j = #vars.slots[i] - (face_up_cards - 1), #vars.slots[i] do
				local go = self:first_level_move_banks(vars.slots[i][j], true, vars.slots[i], j)
				if go then return end
			end
		end
	end
	-- then for slots.
	for i = 1, 7 do
		if #vars.slots[i] > 0 then
			local face_up_cards = 0
			for n = 1, #vars.slots[i] do
				if vars.slots[i][n].tf == 1 then
					face_up_cards += 1
				end
			end
			for j = #vars.slots[i] - (face_up_cards - 1), #vars.slots[i] do
				local go = self:first_level_move_slots(vars.slots[i][j], true, vars.slots[i], j)
				if go then return end
			end
		end
	end
end

-- analyzing available first-level moves for a single card
-- "first-level move" — given the cards available on-screen right now, what can we do with them?
function klondike:first_level_move_banks(card, is_stack, selection_table, order)
	-- if the card is a stack of multiple, don't attempt to put it in a bank.
	if (not is_stack) or (order == #selection_table) then
		-- banks
		for i = 1, 4 do
			if #vars.banks[i] > 0 then
				local compare_card = vars.banks[i][#vars.banks[i]]
				if (card.t == compare_card.t) and (compare_card.i + 1 == card.i) then
					-- move card
					selection_table[#selection_table].tx = 150 + (i * 50)
					selection_table[#selection_table].ty = 15 - (#vars.banks[i] * 0.2)
					table.insert(vars.banks[i], card)
					table.remove(selection_table, #selection_table)

					-- re-fit the table that the card came from
					if #selection_table > 0 and selection_table ~= vars.deck_reverse then
						selection_table[#selection_table].tf = 1
						for n = 1, #selection_table do
							selection_table[n].ty = 80 + ((n - 1) * ((save.control_bar and 75 or 100) / #selection_table))
						end
					end

					randomizecardsfx(put1, put2, put3, put4, put5)

					vars.moves += 1
					self:extras_width()
					self:sort_3_card()
					self:check_win()
					return true
				end
			elseif card.i == 1 then -- bank is empty and this card can start it
				-- move card
				selection_table[#selection_table].tx = 150 + (i * 50)
				selection_table[#selection_table].ty = 15 - (#vars.banks[i] * 0.2)
				table.insert(vars.banks[i], card)
				table.remove(selection_table, #selection_table)

				-- re-fit the table that the card came from
				if #selection_table > 0 and selection_table ~= vars.deck_reverse then
					selection_table[#selection_table].tf = 1
					for n = 1, #selection_table do
						selection_table[n].ty = 80 + ((n - 1) * ((save.control_bar and 75 or 100) / #selection_table))
					end
				end

				randomizecardsfx(put1, put2, put3, put4, put5)

				vars.moves += 1
				self:extras_width()
				self:sort_3_card()
				self:check_win()
				return true
			end
		end
	end
	return false
end

function klondike:first_level_move_slots(card, is_stack, selection_table, order)
	for i = 1, 7 do
		-- check validity against top card in stack
		-- also allow if the slot is empty and the card is a king
		if (#vars.slots[i] > 0 and self:check_stack_validity(card, vars.slots[i][#vars.slots[i]])) or (#vars.slots[i] == 0 and card.i == 13) then
			-- move card(s)
			local order_end = #selection_table
			for n = (order ~= nil and order or order_end), order_end do
				selection_table[n].tx = (i * 50)
				selection_table[n].ty = 80 + (#vars.slots[i] * 10)
				table.insert(vars.slots[i], selection_table[n])
			end
			for n = (order ~= nil and order or order_end), order_end do
				table.remove(selection_table, #selection_table)
			end

			-- re-fit the table that the card came from
			if #selection_table > 0 and selection_table ~= vars.deck_reverse then
				selection_table[#selection_table].tf = 1
				for n = 1, #selection_table do
					selection_table[n].ty = 80 + ((n - 1) * ((save.control_bar and 75 or 100) / #selection_table))
				end
			end

			-- re-fit the table that the card is going into
			for n = 1, #vars.slots[i] do
				vars.slots[i][n].ty = 80 + ((n - 1) * ((save.control_bar and 75 or 100) / #vars.slots[i]))
			end

			randomizecardsfx(put1, put2, put3, put4, put5)

			vars.moves += 1
			self:extras_width()
			self:sort_3_card()
			return true
		end
	end
	return false
end

-- check validity of stack in the tableau. card1 will be stacked on top of card2.
function klondike:check_stack_validity(card1, card2)
	local valid = false
	-- check if the suit is alternating color
	if ((card1.t == 'diamonds' or card1.t == 'hearts') and (card2.t == 'spades' or card2.t == 'clubs')) or ((card1.t == 'spades' or card1.t == 'clubs') and (card2.t == 'diamonds' or card2.t == 'hearts')) then
		-- check if both cards are actually facing up
		if card1.tf == 1 and card2.tf == 1 then
			-- check if the number is sequential
			if card2.i - 1 == card1.i then
				valid = true
			end
		end
	end
	return valid
end

function klondike:save_game()
	-- TODO: save all variable settings into the snapshot
	-- do we literally just copy vars in? i dunno. report back to me later
	save.klondike_snapshot = {}
	save.klondike_snapshot.deck = deepcopy(vars.deck)
	save.klondike_snapshot.deck_reverse = deepcopy(vars.deck_reverse)
	save.klondike_snapshot.hand = deepcopy(vars.hand)
	save.klondike_snapshot.banks = deepcopy(vars.banks)
	save.klondike_snapshot.slots = deepcopy(vars.slots)
	save.klondike_snapshot.deck_passes = vars.deck_passes
	save.klondike_snapshot.deck_passes_left = vars.deck_passes_left
	save.klondike_snapshot.undo_history = deepcopy(vars.undo_history)
	save.klondike_snapshot.time = vars.time
	save.klondike_snapshot.moves = vars.moves
	save.klondike_snapshot.handler = vars.handler
	save.klondike_snapshot.selection = vars.selection
	save.klondike_snapshot.reversing_deck = vars.reversing_deck
	save.klondike_snapshot.cursor = deepcopy(vars.cursor)
	save.klondike_snapshot.deal = deepcopy(vars.deal)
	savegame()
end

-- NOTE: undo is broken when handling moves made with crank
-- NOTE: take a particular look into stack-based crank moves and undo
function klondike:undo()
	if save.undo and #vars.undo_history > 0 and not vars.reversing_deck then
		local entry = vars.undo_history[#vars.undo_history]
		if entry.type == 'reverse_deck' then
			local deck = vars.deck
			local deck_reverse = vars.deck_reverse
			vars.reversing_deck = true
			for i = 1, #deck do
				afterdelay('deck_reverse' .. i, (i * 10) / (save.anim_speed / 100), function()
					deck[#deck].tf = 1
					deck[#deck].tx = 100
					deck[#deck].ty = (15 - (#deck_reverse * 0.2))
					table.insert(deck_reverse, deck[#deck])
					table.remove(deck, #deck)
					if #deck == 0 then
						vars.reversing_deck = false
						self:sort_3_card()
					end
				end)
			end
		elseif entry.type == 'deck' then
			local deck = vars.deck
			local deck_reverse = vars.deck_reverse
			local cards_flipped = entry.cards_flipped

			randomizecardsfx(put1, put2, put3, put4, put5)

			if vars.deck_passes ~= 0 and #deck == 0 then
				vars.deck_passes_left += 1
				save.total_deck_passes_klondike -= 1
				self:extras_width()
			end
			for i = 1, cards_flipped do
				deck_reverse[#deck_reverse].tf = 0
				deck_reverse[#deck_reverse].tx = 50
				deck_reverse[#deck_reverse].ty = (15 - (#deck * 0.2))
				table.insert(deck, deck_reverse[#deck_reverse])
				table.remove(deck_reverse, #deck_reverse)
			end
			self:sort_3_card()
		elseif entry.type == 'move_card' then
			randomizecardsfx(put1, put2, put3, put4, put5)

			local now = entry.whereitisnow
			local pos = entry.itsposition
			local go = entry.whereitshouldgo
			local stack = entry.whereitisnow_existingstack
			local handler = entry.handler

			-- un-flip card in stack if it was revealed by this move
			if #go > 0 and not stack then
				go[#go].tf = 0
			end

			-- calculate X placement
			local calc_x = 0

			local table_len = #go
			if table_len == 0 then
				if find(handler, 'bank') then
					calc_x = 150 + ((string.sub(handler, -1)) * 50)
				elseif find(handler, 'slot') then

					calc_x = 200 + ((string.sub(handler, -1) - 4) * 50)
				elseif find(handler, 'deck_reverse') then
					calc_x = 100
				end
			else
				calc_x = go[table_len].tx
			end

			local now_len = #now
			for i = pos, now_len do
				now[pos].tx = calc_x
				-- calculate Y placement
				-- BUG: undoing single move to bank will splay bank out over the tableau
				if find(handler, 'slot') then
					now[pos].ty = 80 + (#go * 10)
				else
					now[pos].ty = 15 - (#go * 0.2)
				end
				table.insert(go, now[pos])
				table.remove(now, pos)
				if i == now_len and find(handler, 'slot') then
					for n = 1, #go do
						go[n].ty = 80 + ((n - 1) * ((save.control_bar and 75 or 100) / #go))
					end
					for n = 1, #now do
						now[n].ty = 80 + ((n - 1) * ((save.control_bar and 75 or 100) / #now))
					end
				end
			end
		end
		table.remove(vars.undo_history, #vars.undo_history)
		vars.moves -= 1
		self:extras_width()
	end
end

function klondike:auto(skip_tableau, timer_delay)
	vars.handler = 'auto'

	timer_delay = timer_delay or 100
	if timer_delay < 5 then timer_delay = 5 end -- baseline minimum timeframe

	afterdelay('auto_step', timer_delay, function()
		local do_deck_check = skip_tableau or false
		local move
		local won

		if not skip_tableau then
			move = self:top_level_moves(false)

			if move then
				timer_delay = max(10, timer_delay - 10)
				won = self:check_win()

				if not won then
					self:auto(false, timer_delay)
				end
			else
				do_deck_check = true
			end
		end

		if do_deck_check then
			local deck = vars.deck
			local deck_reverse = vars.deck_reverse
			if #deck == 0 and (vars.deck_passes_left > 0 or vars.deck_passes == 0) and #deck_reverse > 0 then
				randomizecardsfx(fan1, fan2, fan3, fan4, fan5)
				vars.reversing_deck = true
				for i = 1, #deck_reverse do
					deck_reverse[#deck_reverse].tf = 0
					deck_reverse[#deck_reverse].tx = 50
					deck_reverse[#deck_reverse].ty = (15 - (#deck * 0.2))
					table.insert(deck, deck_reverse[#deck_reverse])
					table.remove(deck_reverse, #deck_reverse)
					if #deck_reverse == 0 then
						vars.reversing_deck = false
					end
				end
			elseif #deck > 0 then
				randomizecardsfx(pick1, pick2, pick3, pick4, pick5)
				local cards_flipped = 1
				if save.deck_draw == 3 then -- 3-draw game
					cards_flipped = min(#deck, 3)
					for i = 1, min(#deck, 3) do
						deck[#deck].tf = 1
						deck[#deck].tx = 100
						deck[#deck].ty = (15 - (#deck_reverse * 0.2))
						table.insert(deck_reverse, deck[#deck])
						table.remove(deck, #deck)
					end
					self:sort_3_card()
				elseif save.deck_draw == 1 then -- 1-draw game
					deck[#deck].tf = 1
					deck[#deck].tx = 100
					deck[#deck].ty = (15 - (#deck_reverse * 0.2))
					table.insert(deck_reverse, deck[#deck])
					table.remove(deck, #deck)
				end
				if vars.deck_passes ~= 0 and #deck == 0 then
					vars.deck_passes_left -= 1
					save.total_deck_passes_klondike += 1
					self:extras_width()
				end
			end
			vars.moves += 1
			self:extras_width()

			self:auto(false, timer_delay)
		end
	end)
end

function klondike:check_win()
	won = true
	for i = 1, 4 do
		if #vars.banks[i] ~= 13 then
			won = false
		end
	end
	if won then
		self:win()
	end
	return won
end

function klondike:win()
	-- adjusting stats
	save.games_won_klondike += 1
	if vars.time < save.best_time_klondike or save.best_time_klondike == 0 then
		save.best_time_klondike = vars.time
	end
	if vars.moves < save.lowest_moves_klondike or save.lowest_moves_klondike == 0 then
		save.lowest_moves_klondike = vars.moves
	end
	if (vars.deck_passes - vars.deck_passes_left) < save.least_deck_passes_klondike or save.least_deck_passes_klondike == 0 then
		save.least_deck_passes_klondike = (vars.deck_passes - vars.deck_passes_left)
	end

	vars.handler = ''
	save.klondike_snapshot = nil
	vars.cursor.ty = 240
	afterdelay('windelay', 500, function()
		vars.handler = 'box_complete'
		vars.box_selection = 1
		newmusic('audio/music/level3')
		resettimer('box', 150, value('box'), 0, 'outSine', function()
			vars.box_moving = false
		end)
	end)
	-- TODO: win sequence
	-- TODO: win sfx
end

function klondike:redeal(same)
	newmusic('audio/music/level1')
	if save.anim_speed > 0 then randomizecardsfx(fan1, fan2, fan3, fan4, fan5) end
	vars.cursor.ty = 240
	vars.handler = ''
	for i = 1, 7 do
		if i <= 4 then
			for n = 1, #vars.banks[i] do
				vars.banks[i][n].tx = 200
				vars.banks[i][n].ty = 240
				vars.banks[i][n].tf = 0
			end
		end
		for n = 1, #vars.slots[i] do
			vars.slots[i][n].tx = 200
			vars.slots[i][n].ty = 240
			vars.slots[i][n].tf = 0
		end
	end
	for i = 1, #vars.deck do
		vars.deck[i].tx = 200
		vars.deck[i].ty = 240
		vars.deck[i].tf = 0
	end
	for i = 1, #vars.deck_reverse do
		vars.deck_reverse[i].tx = 200
		vars.deck_reverse[i].ty = 240
		vars.deck_reverse[i].tf = 0
	end
	for i = 1, #vars.hand do
		vars.hand[i].tx = 200
		vars.hand[i].ty = 240
		vars.hand[i].tf = 0
	end
	afterdelay('redeal', 600 / (save.anim_speed / 100), function()
		scenemanager:switchscene(klondike, same and vars.deal)
	end)
end

-- calculate width of 'extras' bar at bottom of t' screen
function klondike:extras_width()
	local extras = '  '
	if save.timer then -- show timer
		local time = vars.time
		extras = extras .. '⏱️ ' .. floor(time / 60) .. ':' .. format('%02d', floor(time % 60)) .. '  '
	end
	if save.move_count then -- show move counter
		extras = extras .. '🔄 ' .. vars.moves .. '  '
	end
	if vars.deck_passes > 0 then -- if deck passes are limited, show how many are left
		extras = extras .. '🃏 ' .. vars.deck_passes_left .. '  '
	end
	if extras ~= '  ' then -- calculate length if any metadata is shown
		vars.extras_width = textwidth(pixolde_inverted, extras)
	end
end

-- ...the visual kind of draw. renders a card with the anchor at its top-middle
function klondike:draw_card(card)
	local f = floor(card.f * 10)
	local x = (card.x // 2) * 2
	local y = (card.y // 2) * 2
	if f == 0 then
		drawimage(assets['card_back'], x - 20, y)
	elseif f == 1 then
		drawimage(assets['card_backflip' .. f], x - 16, y)
	elseif f == 2 then
		drawimage(assets['card_backflip' .. f], x - 12, y)
	elseif f == 3 then
		drawimage(assets['card_backflip' .. f], x - 8, y)
	elseif f == 4 then
		drawimage(assets['card_backflip' .. f], x - 4, y)
	elseif f == 6 then
		drawimage(card_images['card_' .. card.t .. card.i .. 'flip' .. f], x - 4, y)
	elseif f == 7 then
		drawimage(card_images['card_' .. card.t .. card.i .. 'flip' .. f], x - 8, y)
	elseif f == 8 then
		drawimage(card_images['card_' .. card.t .. card.i .. 'flip' .. f], x - 12, y)
	elseif f == 9 then
		drawimage(card_images['card_' .. card.t .. card.i .. 'flip' .. f], x - 16, y)
	elseif f == 10 then
		drawimage(card_images['card_' .. card.t .. card.i], x - 20, y)
	end
end

-- Shuffly code from https://gist.github.com/Uradamus/10323382
function klondike:shuffle(tbl)
	setRandomSeed(pd.getSecondsSinceEpoch())
	for i = #tbl, 2, -1 do
		local j = randInt(1, i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

-- TODO: adjust handlers for moving to/from deck_reverse if draw mode is 3-card and there are 3 visible cards in the deck_reverse.
-- (fall back to the current handlers if mode is 1-draw, or if there's only 1 card in the deck_reverse?)
function klondike:keypressed(button)
	if vars.handler == 'box_complete' and not vars.box_moving then
		if button == 'up' then
			vars.box_selection -= 1
			if vars.box_selection < 1 then
				vars.box_selection = 1
				playsound(doink)
			else
				playsound(move)
				vars.box_hit_edge = false
			end
			gfx.sprite.redrawBackground()
		elseif button == 'down' then
			vars.box_selection += 1
			if vars.box_selection > 3 then
				vars.box_selection = 3
				playsound(doink)
			else
				playsound(move)
				vars.box_hit_edge = false
			end
			gfx.sprite.redrawBackground()
		elseif button == 'a' then
			if vars.box_selection == 1 then
				vars.box_moving = true
				timerendedcallback('box')
				resettimer('box', 150, value('box'), 1, 'inSine')
				self:redeal(false)
			elseif vars.box_selection == 2 then
				vars.box_moving = true
				timerendedcallback('box')
				resettimer('box', 150, value('box'), 1, 'inSine')
				self:redeal(true)
			elseif vars.box_selection == 3 then
				vars.box_moving = true
				resettimer('box', 150, value('box'), 1, 'inSine', function()
					scenemanager:transitionsceneback(title, 'klondike')
				end)
			end
		end
	elseif vars.handler == 'box_autocomplete' and not vars.box_moving then
		if button == 'up' then
			vars.box_selection -= 1
			if vars.box_selection < 1 then
				vars.box_selection = 1
				playsound(doink)
			else
				playsound(move)
			end
			gfx.sprite.redrawBackground()
		elseif button == 'down' then
			vars.box_selection += 1
			if vars.box_selection > 2 then
				vars.box_selection = 2
				playsound(doink)
			else
				playsound(move)
			end
			gfx.sprite.redrawBackground()
		elseif button == 'a' then
			vars.box_moving = true
			if vars.box_selection == 1 then
				timerendedcallback('box')
				newmusic('audio/music/level4')
				resettimer('box', 150, value('box'), 1, 'inSine')
				self:auto()
			elseif vars.box_selection == 2 then
				timerendedcallback('box')
				newmusic('audio/music/level4')
				resettimer('box', 150, value('box'), 1, 'inSine', function()
					vars.handler = 'playing'
				end)
			end
		end
	elseif vars.handler ~= '' then
		if button == 'up' then
			if vars.selection == 'slot1' then
				vars.selection = 'deck'
			elseif vars.selection == 'slot2' then
				vars.selection = 'deck_reverse'
			elseif vars.selection == 'slot3' then
				if vars.left then
					vars.selection = 'deck_reverse'
				else
					vars.selection = 'bank1'
				end
			elseif vars.selection == 'slot4' then
				vars.selection = 'bank1'
			elseif vars.selection == 'slot5' then
				vars.selection = 'bank2'
			elseif vars.selection == 'slot6' then
				vars.selection = 'bank3'
			elseif vars.selection == 'slot7' then
				vars.selection = 'bank4'
			end
		elseif button == 'down' then
			if vars.selection == 'deck' then
				vars.selection = 'slot1'
			elseif vars.selection == 'deck_reverse' then
				vars.selection = 'slot2'
			elseif vars.selection == 'bank1' then
				vars.selection = 'slot4'
			elseif vars.selection == 'bank2' then
				vars.selection = 'slot5'
			elseif vars.selection == 'bank3' then
				vars.selection = 'slot6'
			elseif vars.selection == 'bank4' then
				vars.selection = 'slot7'
			end
		elseif button == 'left' then
			vars.left = true
			if vars.selection == 'deck' and save.loop then
				vars.selection = 'bank4'
			elseif vars.selection == 'deck_reverse' then
				vars.selection = 'deck'
			elseif vars.selection == 'bank1' then
				vars.selection = 'deck_reverse'
			elseif vars.selection == 'bank2' then
				vars.selection = 'bank1'
			elseif vars.selection == 'bank3' then
				vars.selection = 'bank2'
			elseif vars.selection == 'bank4' then
				vars.selection = 'bank3'
			elseif vars.selection == 'slot1' and save.loop then
				vars.selection = 'slot7'
			elseif vars.selection == 'slot2' then
				vars.selection = 'slot1'
			elseif vars.selection == 'slot3' then
				vars.selection = 'slot2'
			elseif vars.selection == 'slot4' then
				vars.selection = 'slot3'
			elseif vars.selection == 'slot5' then
				vars.selection = 'slot4'
			elseif vars.selection == 'slot6' then
				vars.selection = 'slot5'
			elseif vars.selection == 'slot7' then
				vars.selection = 'slot6'
			end
		elseif button == 'right' then
			vars.left = false
			if vars.selection == 'deck' then
				vars.selection = 'deck_reverse'
			elseif vars.selection == 'deck_reverse' then
				vars.selection = 'bank1'
			elseif vars.selection == 'bank1' then
				vars.selection = 'bank2'
			elseif vars.selection == 'bank2' then
				vars.selection = 'bank3'
			elseif vars.selection == 'bank3' then
				vars.selection = 'bank4'
			elseif vars.selection == 'bank4' and save.loop then
				vars.selection = 'deck'
			elseif vars.selection == 'slot1' then
				vars.selection = 'slot2'
			elseif vars.selection == 'slot2' then
				vars.selection = 'slot3'
			elseif vars.selection == 'slot3' then
				vars.selection = 'slot4'
			elseif vars.selection == 'slot4' then
				vars.selection = 'slot5'
			elseif vars.selection == 'slot5' then
				vars.selection = 'slot6'
			elseif vars.selection == 'slot6' then
				vars.selection = 'slot7'
			elseif vars.selection == 'slot7' and save.loop then
				vars.selection = 'slot1'
			end
		elseif button == 'a' then
			if (vars.selection == 'deck' and not vars.reversing_deck and vars.handler == 'playing') and (vars.deck_passes == 0 or vars.deck_passes_left > 0) then
				local deck = vars.deck
				local deck_reverse = vars.deck_reverse
				if #deck == 0 and (vars.deck_passes_left > 0 or vars.deck_passes == 0) and #deck_reverse > 0 then
					randomizecardsfx(fan1, fan2, fan3, fan4, fan5)
					vars.reversing_deck = true
					for i = 1, #deck_reverse do
						afterdelay('deck_reverse' .. i, (i * 10) / (save.anim_speed / 100), function()
							deck_reverse[#deck_reverse].tf = 0
							deck_reverse[#deck_reverse].tx = 50
							deck_reverse[#deck_reverse].ty = (15 - (#deck * 0.2))
							table.insert(deck, deck_reverse[#deck_reverse])
							table.remove(deck_reverse, #deck_reverse)
							if #deck_reverse == 0 then
								vars.reversing_deck = false
							end
						end)
					end
					table.insert(vars.undo_history, {type = 'reverse_deck'})
				elseif #deck > 0 then
					randomizecardsfx(pick1, pick2, pick3, pick4, pick5)
					local cards_flipped = 1
					if save.deck_draw == 3 then -- 3-draw game
						cards_flipped = min(#deck, 3)
						for i = 1, min(#deck, 3) do
							deck[#deck].tf = 1
							deck[#deck].tx = 100
							deck[#deck].ty = (15 - (#deck_reverse * 0.2))
							table.insert(deck_reverse, deck[#deck])
							table.remove(deck, #deck)
						end
						self:sort_3_card()
					elseif save.deck_draw == 1 then -- 1-draw game
						deck[#deck].tf = 1
						deck[#deck].tx = 100
						deck[#deck].ty = (15 - (#deck_reverse * 0.2))
						table.insert(deck_reverse, deck[#deck])
						table.remove(deck, #deck)
					end
					if vars.deck_passes ~= 0 and #deck == 0 then
						vars.deck_passes_left -= 1
						save.total_deck_passes_klondike += 1
						self:extras_width()
					end
					table.insert(vars.undo_history, {type = 'deck', cards_flipped = cards_flipped})
				end
				vars.moves += 1
				self:extras_width()
			elseif vars.selection ~= 'deck' then
				self:pick_card()
			end
		elseif 'b' then
			if vars.handler == 'playing' then
				self:undo()
			else
				self:put_card_down()
			end
		end
	end
end