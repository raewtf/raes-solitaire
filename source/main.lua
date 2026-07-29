local pd <const> = playdate
local gfx <const> = pd.graphics

music = nil
catalog = false
delta = 0

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
import 'langs'
import 'scenemanager'
scenemanager = scenemanager()

import 'title'

version = pd.metadata.version
if pd.metadata.bundleID == 'wtf.rae.solitaire' then catalog = true end

pd.display.setRefreshRate(30)
-- TODO: do i need to flip this for a smooth launch animation?
setbackgroundcolor('white')
gfx.setLineWidth(2)
-- TODO: calculate dirty rects properly in each scene
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
	if save.move_count == nil then save.move_count = true end -- show move count
	if save.control_bar == nil then save.control_bar = true end -- show control bar at bottom of screen
	if save.loop == nil then save.loop = true end -- loop around at the far left and right edges of screen
	save.crank_direction = save.crank_direction or 0 -- 0 = clockwise, 1 = counter-clockwise, 2 = both-wise

	-- klondike rules
	save.deck_draw = save.deck_draw or 1 -- 1- or 3-draw
	if save.undo == nil then save.undo = true end -- undo
	if save.possible == nil then save.possible = false end -- guarantee possible games
	save.auto = save.auto or 1 -- auto-complete upon all cards being revealed
	save.crank = save.crank or 1 -- crank-to-complete
	if save.quickpick == nil then save.quickpick = true end -- quick-pick
	if save.stack_anywhere == nil then save.stack_anywhere = false end -- allow any card onto blank spaces in the tableau
	save.deck_passes = save.deck_passes or 0 -- Number of passes through the deck the player can get. 0 = infinite

	-- customization
	save.card_front = save.card_front or 'antennae'
	save.card_back = save.card_back or 'antennae'
	save.cursor = save.cursor or 'cartoon'
	save.anim_speed = save.anim_speed or 100 -- in percent
	save.backdrop = save.backdrop or 0.5 -- backdrop 'lightness'
	save.card_guide = save.card_guide or 1 -- card guide 'lightness'

	-- statistics
	save.playtime = save.playtime or 0

	save.games_played_klondike = save.games_played_klondike or 0
	save.games_won_klondike = save.games_won_klondike or 0
	save.best_time_klondike = save.best_time_klondike or 0
	save.lowest_moves_klondike = save.lowest_moves_klondike or 0
	save.least_deck_passes_klondike = save.least_deck_passes_klondike or 0
	save.total_deck_passes_klondike = save.total_deck_passes_klondike or 0
	save.gametime_klondike = save.gametime_klondike or 0

	-- TODO: hook up statistics for pickup
	save.games_played_pickup = save.games_played_pickup or 0
	save.best_time_pickup = save.best_time_pickup or 0
	save.countups_pickup = save.countups_pickup or 0
	save.countdowns_pickup = save.countdowns_pickup or 0
	save.gametime_pickup = save.gametime_pickup or 0
end

function load_common_sfx()
	if save.sfx and not sfx_loaded then
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
-- TODO: assert for size == 40x60
-- TODO: custom card image import from .pdi files in save-data folder
function load_card_images()
	for i = 1, 13 do
		-- import card images
		card_images['card_clubs' .. i] = newimage('images/cards/' .. save.card_front .. '/clubs' .. i)
		card_images['card_diamonds' .. i] = newimage('images/cards/' .. save.card_front .. '/diamonds' .. i)
		card_images['card_hearts' .. i] = newimage('images/cards/' .. save.card_front .. '/hearts' .. i)
		card_images['card_spades' .. i] = newimage('images/cards/' .. save.card_front .. '/spades' .. i)

		for n = 1, 4 do
			card_images['card_clubs' .. i .. 'flip' .. (n + 5)] = card_images['card_clubs' .. i]:scaledImage(n / 5, 1)
			card_images['card_diamonds' .. i .. 'flip' .. (n + 5)] = card_images['card_diamonds' .. i]:scaledImage(n / 5, 1)
			card_images['card_hearts' .. i .. 'flip' .. (n + 5)] = card_images['card_hearts' .. i]:scaledImage(n / 5, 1)
			card_images['card_spades' .. i .. 'flip' .. (n + 5)] = card_images['card_spades' .. i]:scaledImage(n / 5, 1)
		end
	end
end

savecheck()
load_common_sfx()
load_common_fonts()
load_card_images()

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

-- TODO: write manual
-- TODO: set up catalog page
-- TODO: publicize github page
-- TODO: publicize itch page

-- TODO: crossfade between musics

-- TODO: more card fronts
-- TODO: more card backs
-- TODO: more cursors

-- TODO: potentially a series of tutorial slides on how to play klondike?

function pd.gameWillTerminate()
	-- TODO: save game capture if mid-play
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
	-- TODO: save game capture if mid-play
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
	pd.drawFPS(10, 10)
end