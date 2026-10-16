local pd <const> = playdate
local gfx <const> = pd.graphics

catalog = false
delta = 0

local music = {}
local current_music = 2
local music_loaded = false
local sfx_loaded = false
local fonts_loaded = false
local floor <const> = math.floor
local ceil <const> = math.ceil

import 'CoreLibs/math'
import 'CoreLibs/timer'
import 'CoreLibs/crank'
import 'CoreLibs/object'
import 'CoreLibs/sprites'
import 'CoreLibs/graphics'
import 'CoreLibs/animation'

import 'libraries/wrappers'
import 'libraries/xorshift'
import 'libraries/scenemanager'
import 'langs'
scenemanager = scenemanager()

import 'title'

version = pd.metadata.version
if pd.metadata.bundleID == 'wtf.rae.solitaire' then
	catalog = true
	-- these global variables are for posting to the scoreboard afterwards.
	queued_score = 0
	queued_moves = 0
end

pd.display.setRefreshRate(30)
setbackgroundcolor('white')
gfx.setLineWidth(2)
gfx.sprite.setAlwaysRedraw(true)

-- Localized text function.
function text(key)
	local data
	if save.language == 'en' then
		data = langs.en
	end
	return data and data[key] or key
end

-- Save check
function savecheck()
    save = pd.datastore.read()
    if save == nil then save = {} end

	save.language = save.language or 'en'

	if save.seenpickup == nil then save.seenpickup = false end

	-- gameplay
	if save.music == nil then save.music = true end
	if save.sfx == nil then save.sfx = true end
	if save.card_sfx == nil then save.card_sfx = true end -- card SFX
	if save.timer == nil then save.timer = true end -- show timer
	if save.move_count == nil then save.move_count = true end -- show move counter
	if save.control_bar == nil then save.control_bar = true end -- show control bar at bottom of screen
	if save.loop == nil then save.loop = true end -- loop around at the far left and right edges of screen
	save.crank_direction = save.crank_direction or 0 -- 0 = clockwise, 1 = counter-clockwise, 2 = both-wise
	save.shoulddo24hour = save.shoulddo24hour or 0 -- 0 = system, 1 = 12-hour, 2 = 24-hour

	-- klondike rules
	save.deck_draw = save.deck_draw or 1 -- 1- or 3-draw
	save.scoring = save.scoring or 'standard'
	if save.undo == nil then save.undo = true end -- undo
	save.undo_limit = save.undo_limit or 0 -- undo limit
	if save.flip == nil then save.flip = true end
	if save.possible == nil then save.possible = false end -- guarantee possible games
	save.auto = save.auto or 1 -- auto-complete upon all cards being revealed
	if save.prompt_on_no_moves == nil then save.prompt_on_no_moves = true end -- prompt the player to try a new game if the game runs out of perceived moves
	save.crank = save.crank or 1 -- crank-to-complete
	if save.quickpick == nil then save.quickpick = true end -- quick-pick
	if save.stack_anywhere == nil then save.stack_anywhere = false end -- allow any card onto blank spaces in the tableau
	save.deck_passes = save.deck_passes or 0 -- Number of passes through the deck the player can get. 0 = infinite

	-- customization
	save.card_front = save.card_front or 'antennae'
	if save.custom_card_front == nil then save.custom_card_front = false end
	save.card_back = save.card_back or 'antennae'
	if save.custom_card_back == nil then save.custom_card_back = false end
	save.cursor = save.cursor or 'cartoon'
	save.anim_speed = save.anim_speed or 100 -- in percent
	save.backdrop = save.backdrop or 0.5 -- backdrop 'lightness'
	save.card_guide = save.card_guide or 1 -- card guide 'lightness'

	-- statistics
	save.playtime = save.playtime or 0

	save.score_klondike = save.score_klondike or 0
	save.gametime_klondike = save.gametime_klondike or 0
	save.games_played_klondike = save.games_played_klondike or 0
	save.games_won_klondike = save.games_won_klondike or 0
	save.best_time_klondike = save.best_time_klondike or 0
	save.lowest_moves_klondike = save.lowest_moves_klondike or 0
	save.total_moves_klondike = save.total_moves_klondike or 0
	save.total_undos_klondike = save.total_undos_klondike or 0
	save.least_deck_passes_klondike = save.least_deck_passes_klondike or 0
	save.total_deck_passes_klondike = save.total_deck_passes_klondike or 0

	-- TODO: hook up statistics for pickup
	save.score_pickup = save.score_pickup or 0
	save.gametime_pickup = save.gametime_pickup or 0
	save.games_played_pickup = save.games_played_pickup or 0
	save.best_time_pickup = save.best_time_pickup or 0
	save.countups_pickup = save.countups_pickup or 0
	save.countdowns_pickup = save.countdowns_pickup or 0
end

-- num is a passthrough to set the first music level.
function load_music(num)
	if save.music and not music_loaded then
		for i = 1, 4 do
			-- create the music for each level, set it to "silent" volume, and let it loop forever.
			-- vol has to be 0.001 because apparently, at 0, fileplayers just get unloaded? whatever
			music[i] = pd.sound.fileplayer.new('audio/music/level' .. i)
			music[i]:setLoopRange(0)
			music[i]:setVolume(0.001)
			music[i]:play(0)
		end
		music_loaded = true
		set_music_level(num)
	end
end

-- num: an integer number, 1 to 4. this'll determine what music should start playing
-- delay: a time in milliseconds to fade from the start level to the target level.
function set_music_level(num, delay)
	delay = delay or 1500
	if save.music then
		music[num]:setVolume(1, 1, delay / 1000)
		if current_music ~= num then
			music[current_music]:setVolume(0.001, 0.001, delay / 1000)
			current_music = num
		end
	end
end

-- num: a number on the range from 0 to 1. this sets the playback volume of the current track.
-- delay: a time in milliseconds to fade from the start volume to the target volume.
function set_music_volume(num, delay)
	if num == 0 then num = 0.001 end
	delay = delay or 400
	if save.music then
		music[current_music]:setVolume(num, num, delay / 1000)
	end
end

-- stops all music playback, for reals this time.
function stop_music()
	for i = 1, 4 do
		music[i]:stop()
		music[i] = nil
	end
	music_loaded = false
end

function load_common_sfx()
	if (save.sfx or save.card_sfx) and not sfx_loaded then
		accept = newsound('audio/sfx/accept')
		bonk = newsound('audio/sfx/bonk')
		bump = newsound('audio/sfx/bump')
		doink = newsound('audio/sfx/doink')
		move = newsound('audio/sfx/move')

		fan1 = newsound('audio/sfx/fan1')
		fan2 = newsound('audio/sfx/fan2')
		fan3 = newsound('audio/sfx/fan3')
		fan4 = newsound('audio/sfx/fan4')
		fan5 = newsound('audio/sfx/fan5')

		pick1 = newsound('audio/sfx/pick1')
		pick2 = newsound('audio/sfx/pick2')
		pick3 = newsound('audio/sfx/pick3')
		pick4 = newsound('audio/sfx/pick4')
		pick5 = newsound('audio/sfx/pick5')

		put1 = newsound('audio/sfx/put1')
		put2 = newsound('audio/sfx/put2')
		put3 = newsound('audio/sfx/put3')
		put4 = newsound('audio/sfx/put4')
		put5 = newsound('audio/sfx/put5')

		win = newsound('audio/sfx/win')
		sfx_loaded = true
	end
end

function load_common_fonts()
	if not fonts_loaded then
		pixolde = newfont('fonts/pixolde')
		pixolde_bold = newfont('fonts/pixolde_bold')
		pixolde_italic = newfont('fonts/pixolde_italic')
		pixolde_inverted = newfont('fonts/pixolde_inverted')
		pixolde_bold_inverted = newfont('fonts/pixolde_bold_inverted')
		pixolde_italic_inverted = newfont('fonts/pixolde_italic_inverted')

		gfx.setFontFamily({
			[gfx.font.kVariantNormal] = pixolde,
			[gfx.font.kVariantBold] = pixolde_bold,
			[gfx.font.kVariantItalic] = pixolde_italic,
		})

		fonts_loaded = true
	end
end

card_images = {}
transition_image = newimagetable('images/transition')

-- should be run any time the card style is changed
function load_card_images(custom_front, custom_back)
	if custom_front then
		if not pd.file.exists('custom_cards/' .. save.card_front .. '/') then
			custom_front = false
			save.custom_card_front = false
			save.card_front = 'antennae'
		end
	end
	if custom_back then
		if not pd.file.exists('custom_cards/' .. save.card_back .. '/') then
			custom_back = false
			save.custom_card_back = false
			save.card_back = 'antennae'
		end
	end

	local w
	local h
	local card_back
	local total_fronts = 0

	for i = 1, 13 do
		-- import card images
		if custom_front then
			card_images['card_clubs' .. i] = newimage('custom_cards/' .. save.card_front .. '/clubs' .. i)
			card_images['card_diamonds' .. i] = newimage('custom_cards/' .. save.card_front .. '/diamonds' .. i)
			card_images['card_hearts' .. i] = newimage('custom_cards/' .. save.card_front .. '/hearts' .. i)
			card_images['card_spades' .. i] = newimage('custom_cards/' .. save.card_front .. '/spades' .. i)
		else
			card_images['card_clubs' .. i] = newimage('images/cards/' .. save.card_front .. '/clubs' .. i)
			card_images['card_diamonds' .. i] = newimage('images/cards/' .. save.card_front .. '/diamonds' .. i)
			card_images['card_hearts' .. i] = newimage('images/cards/' .. save.card_front .. '/hearts' .. i)
			card_images['card_spades' .. i] = newimage('images/cards/' .. save.card_front .. '/spades' .. i)
		end
		total_fronts += 4

		w, h = card_images['card_clubs' .. i]:getSize()
		assert(w == 40, 'Sorry, cards have to be exactly 40 pixels wide! Please adjust your clubs' .. i .. '.pdi to get past this crash. Set being imported: ' .. save.card_front)
		assert(h == 60, 'Sorry, cards have to be exactly 60 pixels tall! Please adjust your clubs' .. i .. '.pdi to get past this crash. Set being imported: ' .. save.card_front)

		w, h = card_images['card_diamonds' .. i]:getSize()
		assert(w == 40, 'Sorry, cards have to be exactly 40 pixels wide! Please adjust your diamonds' .. i .. '.pdi to get past this crash. Set being imported: ' .. save.card_front)
		assert(h == 60, 'Sorry, cards have to be exactly 60 pixels tall! Please adjust your diamonds' .. i .. '.pdi to get past this crash. Set being imported: ' .. save.card_front)

		w, h = card_images['card_hearts' .. i]:getSize()
		assert(w == 40, 'Sorry, cards have to be exactly 40 pixels wide! Please adjust your hearts' .. i .. '.pdi to get past this crash. Set being imported: ' .. save.card_front)
		assert(h == 60, 'Sorry, cards have to be exactly 60 pixels tall! Please adjust your hearts' .. i .. '.pdi to get past this crash. Set being imported: ' .. save.card_front)

		w, h = card_images['card_spades' .. i]:getSize()
		assert(w == 40, 'Sorry, cards have to be exactly 40 pixels wide! Please adjust your spades' .. i .. '.pdi to get past this crash. Set being imported: ' .. save.card_front)
		assert(h == 60, 'Sorry, cards have to be exactly 60 pixels tall! Please adjust your spades' .. i .. '.pdi to get past this crash. Set being imported: ' .. save.card_front)

		for n = 1, 4 do
			card_images['card_clubs' .. i .. 'flip' .. (n + 5)] = card_images['card_clubs' .. i]:scaledImage(n / 5, 1)
			card_images['card_diamonds' .. i .. 'flip' .. (n + 5)] = card_images['card_diamonds' .. i]:scaledImage(n / 5, 1)
			card_images['card_hearts' .. i .. 'flip' .. (n + 5)] = card_images['card_hearts' .. i]:scaledImage(n / 5, 1)
			card_images['card_spades' .. i .. 'flip' .. (n + 5)] = card_images['card_spades' .. i]:scaledImage(n / 5, 1)
		end
	end

	assert(total_fronts == 0 or total_fronts == 52, 'Sorry, it looks like you might not have all the front cards in your import! Make sure they\'re all there (there should be 52 of \'em), and that they\'re all named properly. Set being imported: ' .. save.card_front)

	if custom_back then
		card_back = newimage('custom_cards/' .. save.card_back .. '/back')
	else
		card_back = newimage('images/cards/' .. save.card_back .. '/back')
	end
	w, h = card_back:getSize()
	assert(w == 40, 'Sorry, cards have to be exactly 40 pixels wide! Please adjust your back.pdi to get past this crash. Set being imported: ' .. save.card_back)
	assert(h == 60, 'Sorry, cards have to be exactly 60 pixels tall! Please adjust your back.pdi to get past this crash. Set being imported: ' .. save.card_back)
end

if not pd.file.isdir('custom_cards/') then
	pd.file.mkdir('custom_cards/example/')
	local example_card_data = {
		card_alias = "Example",
		card_maker = "You...?",
		howto = "Hi! Thanks for poking around. This is where you can create and import your own custom card assets; how nice! It's a bit tech-y, but you can handle it if you wound up here on your own. The first thing you'll wanna do is create some custom card images — they must be 40 pixels wide, 60 pixels high; and of course, 1-bit only. If you want a custom back design, that'll be one image called 'back'. If you want front designs, you'll need to provide all of them — the naming convention is the suit (plural), followed by the numerical value of the card. Just to give a few examples: 'spades1' for an Ace of Spades, 'hearts13' for a King of Hearts, 'diamonds7' for a Seven of Diamonds, and 'clubs11' for a Jack of Clubs. After you've got your drawings made, run them through the pdc tool, included in the Playdate SDK, to convert them into .pdi files; that way the game can read them (standard image files like .png or .jpg will not work). Then, drop your new Playdate images straight into this 'example' folder. Right next to this JSON file! Importantly, you should rename the 'example' folder to something unique (letters only), otherwise the game won't be able to look for it. Also, you should change the 'card_alias' (what it's called) and 'card_maker' (your own name) fields in this file, so that you can find your new deck easily in-game. For those fields, alphanumeric works best; and I'd advise a maximum character length of about 15. You should be good to go after that! Launch your game, enter Settings > Customization, and scroll through the Card Art settings (front or back, depending on what you added) to find your custom creations! If you make something cool and you wanna show me (or you get stuck at some step in the process and need more info), don't hesitate to reach out! (By the way, the game doesn't read this 'howto' field, so feel free to remove it if you wanna clean up a bit.) Have a nice day!"
	}
	pd.datastore.write(example_card_data, 'custom_cards/example/metadata', true)
end

savecheck()
load_music(2)
load_common_sfx()
load_common_fonts()
load_card_images(save.custom_card_front and true or save.custom_card_back and true or false)

-- This function returns the inputted number, with the ordinal suffix tacked on at the end (as a string)
function ordinal(num, balls)
	local m10 = num % 10 -- This is the number, modulo'd by 10.
	local m100 = num % 100 -- This is the number, modulo'd by 100.
	if m10 == 1 and m100 ~= 11 then -- If the number ends in 1 but NOT 11...
		return tostring(num) .. text('st' .. tostring(balls and '_balls' or '')) -- add "st" on.
	elseif m10 == 2 and m100 ~= 12 then -- If the number ends in 2 but NOT 12...
		return tostring(num) .. text('nd' .. tostring(balls and '_balls' or '')) -- add "nd" on,
	elseif m10 == 3 and m100 ~= 13 then -- and if the number ends in 3 but NOT 13...
		return tostring(num) .. text('rd' .. tostring(balls and '_balls' or '')) -- add "rd" on.
	else -- If all those checks passed us by,
		return tostring(num) .. text('th' .. tostring(balls and '_balls' or '')) -- then it ends in "th".
	end
end

-- http://lua-users.org/wiki/CopyTable
-- Save copied tables in `copies`, indexed by original table.
function deepcopy(orig, copies)
	copies = copies or {}
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		if copies[orig] then
			copy = copies[orig]
		else
			copy = {}
			copies[orig] = copy
			for orig_key, orig_value in next, orig, nil do
				copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
			end
			setmetatable(copy, deepcopy(getmetatable(orig), copies))
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

-- http://lua-users.org/wiki/FormattingNumbers
function commalize(amount)
  	local formatted = amount
  	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if (k==0) then
	  		break
	  	end
    end
  	return formatted
end

-- TODO: more card fronts
-- "zoetrope" — a horse in motion frames on ascending cards. Made to animate on title screen
-- "rotatotron" — frames from the moth rotatotron on ascending cards. to animate on title
-- "butterflies" — number cards have number of butterflies. monarch cards show caterpillar evolution?
-- "birds" — number cards are M birds. monarch cards show nice close-ups
-- "flowers" — number cards are flowers, monarch cards are nice big flowers

function pd.gameWillTerminate()
	-- save game capture if mid-play as game is closed
	if klondike:playing() then -- the klondike game scene is in use, and it's safe to save.
		if vars.reversing_deck then -- if deck reverse animation is playing,
			local deck = vars.deck
			local deck_reverse = vars.deck_reverse
			if vars.reversing_deck_undo then
				-- finish putting deck into reverse deck, quickly
				for i = 1, #deck do
					deck[#deck].tf = 1
					deck[#deck].tx = 100
					deck[#deck].ty = (15 - (#deck_reverse * 0.2))
					table.insert(deck_reverse, deck[#deck])
					table.remove(deck, #deck)
				end
			else
				-- finish putting reverse deck into deck, quickly
				for i = 1, #deck_reverse do
					deck_reverse[#deck_reverse].tf = 0
					deck_reverse[#deck_reverse].tx = 50
					deck_reverse[#deck_reverse].ty = (15 - (#deck * 0.2))
					table.insert(deck, deck_reverse[#deck_reverse])
					table.remove(deck_reverse, #deck_reverse)
				end
			end
			vars.reversing_deck = false
			vars.reversing_deck_undo = false
		end
		klondike:save_game()
	end

	local img = gfx.getDisplayImage()
	local byebye = newimagetable('images/byebye')
	local byebyeanim = gfx.animator.new(800, 1, #byebye)
	gfx.setDrawOffset(0, 0)
	while not byebyeanim:ended() do
		drawimage(img, 0, 0)
		drawimagetable(byebye, floor(byebyeanim:currentValue()), 0, 0)
		pd.display.flush()
	end
	savegame()
end

function pd.deviceWillSleep()
	-- save game capture if mid-play as game is closed
	if klondike:playing() then -- the klondike game scene is in use, and it's safe to save.
		if vars.reversing_deck then -- if deck reverse animation is playing,
			local deck = vars.deck
			local deck_reverse = vars.deck_reverse
			if vars.reversing_deck_undo then
				-- finish putting deck into reverse deck, quickly
				for i = 1, #deck do
					deck[#deck].tf = 1
					deck[#deck].tx = 100
					deck[#deck].ty = (15 - (#deck_reverse * 0.2))
					table.insert(deck_reverse, deck[#deck])
					table.remove(deck, #deck)
				end
			else
				-- finish putting reverse deck into deck, quickly
				for i = 1, #deck_reverse do
					deck_reverse[#deck_reverse].tf = 0
					deck_reverse[#deck_reverse].tx = 50
					deck_reverse[#deck_reverse].ty = (15 - (#deck * 0.2))
					table.insert(deck, deck_reverse[#deck_reverse])
					table.remove(deck_reverse, #deck_reverse)
				end
			end
			vars.reversing_deck = false
			vars.reversing_deck_undo = false
		end
		klondike:save_game()
	end

	savegame()
end

scenemanager:switchscene(title, '', true)

function pd.update()
	-- delta time logic
	delta = pd.getElapsedTime()
	pd.resetElapsedTime()

	save.playtime += delta

	-- Catch-all stuff ...
	gfx.sprite.update()
	pd.timer.updateTimers()
end