local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local format <const> = string.format
local floor <const> = math.floor

class('statistics').extends(gfx.sprite)
function statistics:init(...)
	statistics.super.init(self)
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

function statistics:initialize(args)
	assets = {
	}

	vars = {
		handler = '',
		-- TODO: add "all_modes" to the beginning (or the end?) later on, when there's more than one mode
		categories = {'klondike'},
		category_selection = 1,
		category_offset = 0,
		category_target = 0,
	}
	afterdelay('handler_delay', transitiontime, function() vars.handler = 'statistics' end)

	if save.seenpickup then
		table.insert(vars.categories, 'pickup')
	end

	newmusic('audio/music/level1')
end

function statistics:update()
	if pd.buttonJustPressed('left') then self:keypressed('left') end
	if pd.buttonJustPressed('right') then self:keypressed('right') end
	if pd.buttonJustPressed('b') then self:keypressed('b') end

	if vars.category_target ~= nil and vars.category_offset ~= nil then
		vars.category_offset += (vars.category_target - vars.category_offset) * 0.5
		if vars.category_offset > (vars.category_target - 0.1) and vars.category_offset < (vars.category_target + 0.1) then
			vars.category_offset = vars.category_target
		else
			gfx.sprite.addDirtyRect(0, 0, 400, 30)
		end
	end
end

function statistics:gethms(num, hours_enabled)
	local hours = floor((num) / 3600)
	if hours_enabled and hours > 0 then
		local minutes = floor((num) / 60 - (hours * 60))
		local seconds = floor((num) - (hours * 3600) - (minutes * 60))
		return hours .. text(hours == 1 and 'h1' or 'h') .. minutes .. text(minutes == 1 and 'm1' or 'm') .. seconds .. text(seconds == 1 and 's1' or 's')
	else
		local minutes = floor((num) / 60)
		local seconds = floor((num) - (minutes * 60))
		return minutes .. text(minutes == 1 and 'm1' or 'm') .. seconds .. text(seconds == 1 and 's1' or 's')
	end
end

function statistics:draw()
	-- defining hot variables
	local cat = vars.categories[vars.category_selection]

	-- top category selector bar
	fillrect(0, 0, 400, 30)
	setcolor(255, 255, 255, 1, 'white')
	fillrect(140, 5, 120, 20, 5)

	if vars.category_selection > 1 then
		drawtext(pixolde_inverted, text('statistics_' .. vars.categories[vars.category_selection - 1]), 200 - 75 + vars.category_offset, 8, right)
	end
	drawtext(pixolde_bold, text('statistics_' .. cat), 200 + vars.category_offset, 8, center)
	if vars.category_selection < #vars.categories then
		drawtext(pixolde_inverted, text('statistics_' .. vars.categories[vars.category_selection + 1]), 200 + 75 + vars.category_offset, 8)
	end

	local num

	if cat == 'all_modes' then
		-- Total play time
		drawtext(pixolde, text('statistics_playtime'), 10, 38)
		drawtext(pixolde, self:gethms(save.playtime, true), 390, 38, right)

		-- Total games played
		drawtext(pixolde, text('statistics_games_played'), 10, 53)
		num = (save.games_played_klondike + save.games_played_pickup)
		drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'play' or 'played')), 390, 53, right)

		-- Total games won
		drawtext(pixolde, text('statistics_games_won'), 10, 68)
		num = save.games_won_klondike
		drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'win' or 'won')), 390, 68, right)
	elseif cat == 'klondike' then
		-- Total play time
		drawtext(pixolde, text('statistics_playtime'), 10, 38)
		drawtext(pixolde, self:gethms(save.gametime_klondike, true), 390, 38, right)

		-- Total games played
		drawtext(pixolde, text('statistics_games_played'), 10, 53)
		num = save.games_played_klondike
		drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'play' or 'played')), 390, 53, right)

		-- Total games won
		drawtext(pixolde, text('statistics_games_won'), 10, 68)
		num = save.games_won_klondike
		drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'win' or 'won')), 390, 68, right)

		-- Win rate
		drawtext(pixolde, text('statistics_win_rate'), 10, 83)
		num = save.games_won_klondike / save.games_played_klondike
		drawtext(pixolde, format('%.02f', num) .. text('statistics_rate'), 390, 83, right)

		-- Best time in a game
		drawtext(pixolde, text('statistics_best_time'), 10, 98)
		if save.best_time_klondike == 0 then
			drawtext(pixolde, text('na'), 390, 98, right)
		else
			drawtext(pixolde, self:gethms(save.best_time_klondike), 390, 98, right)
		end

		-- Fewest moves in a game
		drawtext(pixolde, text('statistics_lowest_moves'), 10, 113)
		num = save.lowest_moves_klondike
		drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'move' or 'moves')), 390, 113, right)

		-- Total moves made
		drawtext(pixolde, text('statistics_total_moves'), 10, 128)
		num = save.total_moves_klondike
		drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'move' or 'moves')), 390, 128, right)

		-- Total undos
		drawtext(pixolde, text('statistics_total_undos'), 10, 143)
		num = save.total_undos_klondike
		drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'undo' or 'undos')), 390, 143, right)

		-- Total moves minus total undos
		drawtext(pixolde, text('statistics_moves_minus_undos'), 10, 158)
		num = save.total_moves_klondike - save.total_undos_klondike
		drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'move' or 'moves')), 390, 158, right)

		-- Least deck passes in a game
		drawtext(pixolde, text('statistics_least_deck_passes'), 10, 173)
		num = save.least_deck_passes_klondike
		if num == 0 then
			drawtext(pixolde, text('na'), 390, 173, right)
		else
			drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'deck_pass' or 'deck_passes')), 390, 173, right)
		end

		-- Total deck passes
		drawtext(pixolde, text('statistics_total_deck_passes'), 10, 188)
		drawtext(pixolde, num .. text('statistics_' .. (num == 1 and 'deck_pass' or 'deck_passes')), 390, 188, right)
	elseif cat == 'pickup' then
		-- Total play time
		drawtext(pixolde, text('statistics_playtime'), 10, 38)
		drawtext(pixolde, self:gethms(save.gametime_pickup), 390, 38, right)

		-- TODO: finish up pickup statistics
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
			controls = text('control_back')
		end
		drawtext(pixolde_inverted, controls, 5, 223)

		local time = gettime()
		local hour = time.hour
		local minute = time.minute
		drawtext(pixolde_inverted, (pd.shouldDisplay24HourTime() and (format("%02d:%02d", hour, minute)) or (format("%01d:%02d", ((hour % 12) == 0 and 12 or (hour % 12)), minute)) .. (hour < 12 and 'a' or 'p')), 395, 223, right)
	end


end

function statistics:keypressed(button)
	if vars.handler == 'statistics' then
		if button == 'left' then
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
		elseif button == 'b' then
			playsound(bump)
			scenemanager:transitionsceneback(title, 'statistics')
		end
	end
end