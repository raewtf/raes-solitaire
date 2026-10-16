local pd <const> = playdate
local gfx <const> = pd.graphics
local center <const> = kTextAlignment.center
local right <const> = kTextAlignment.right
local floor <const> = math.floor
local ceil <const> = math.ceil
local min <const> = math.min
local format <const> = string.format
local gsub <const> = string.gsub
local len <const> = string.len

class('highscores').extends(gfx.sprite)
function highscores:init(...)
	highscores.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here

	function pd.gameWillPause()
		local menu = pd.getSystemMenu()
		menu:removeAllMenuItems()
		if not vars.loading then
			menu:addMenuItem(text('slide_refresh'), function()
				self:refresh()
			end)
		end
		menu:addMenuItem(text('slide_back'), function()
			scenemanager:transitionsceneback(title, 'statistics')
		end)
	end

	self:initialize(args)
	gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
		self:draw()
	end)

	self:add()
end

function highscores:initialize(args)
	assets = {
		loading = newimagetable('images/loading'),
		empty = newimagetable('images/empty'),
		failed = newimagetable('images/failed'),
		battery = newimagetable('images/battery'),
	}

	vars = {
		handler = '',
		categories = {'klondike_score', 'klondike_daily_score', 'klondike_lowest_moves'},
		loading = false,
		category_selection = 1,
		category_offset = 0,
		category_target = 0,
		results = {},
		bests = {},
	}
	afterdelay('handler_delay', transitiontime, function() vars.handler = 'refreshingscores' end)

	if save.seenpickup then
		table.insert(vars.categories, 'pickup_score')
		table.insert(vars.categories, 'pickup_daily_score')
	end

	-- individual result and best tables, to limit refreshing on category hops
	for i = 1, #vars.categories do
		vars.results[vars.categories[i] .. '_result'] = {}
		vars.bests[vars.categories[i] .. '_best'] = {}
	end

	self:refresh()

	set_music_level(1)
end

function highscores:update()
	if pd.buttonJustPressed('left') then self:keypressed('left') end
	if pd.buttonJustPressed('right') then self:keypressed('right') end
	if pd.buttonJustPressed('a') then self:keypressed('a') end
	if pd.buttonJustPressed('b') then self:keypressed('b') end

	if vars.category_target ~= nil and vars.category_offset ~= nil then
		vars.category_offset += (vars.category_target - vars.category_offset) * 0.5
		if vars.category_offset > (vars.category_target - 0.1) and vars.category_offset < (vars.category_target + 0.1) then
			vars.category_offset = vars.category_target
		end
	end

	local gmt = pd.getGMTTime()
	if gmt.hour == 0 and gmt.minute == 0 and gmt.second == 0 and not vars.loading and (vars.categories[vars.category_selection] == 'klondike_daily_score' or vars.categories[vars.category_selection] == 'pickup_daily_score') then
		self:refresh()
	end
end

function highscores:draw()
	-- defining hot variables
	local cat = vars.categories[vars.category_selection]

	-- top category selector bar
	fillrect(0, 0, 400, 30)
	setcolor(255, 255, 255, 1, 'white')
	fillrect(90, 5, 220, 20, 5)

	if vars.category_selection > 1 then
		drawtext(pixolde_inverted, text('scores_' .. vars.categories[vars.category_selection - 1]), 200 - 125 + vars.category_offset, 8, right)
	end
	drawtext(pixolde_bold, text('scores_' .. cat), 200 + vars.category_offset, 8, center)
	if vars.category_selection < #vars.categories then
		drawtext(pixolde_inverted, text('scores_' .. vars.categories[vars.category_selection + 1]), 200 + 125 + vars.category_offset, 8)
	end

	local result = vars.results[cat .. '_result']
	local best = vars.bests[cat .. '_best']

	if result.scores ~= nil and next(result.scores) ~= nil and not vars.loading then -- show scores!
		for i = 1, min(#result.scores, 9) do
			drawtext(pixolde, ordinal(i) .. '.', 10, 23 + (i * 15))
			drawtext(pixolde_bold, result.scores[i].player, 38, 23 + (i * 15))
			local val = result.scores[i].value
			local appendix = ''
			if cat == 'klondike_score' or cat == 'klondike_daily_score' or cat == 'pickup_score' then
				appendix = text('statistics_points')
			elseif cat == 'klondike_lowest_moves' then
				appendix = text(val == 1 and 'statistics_move' or 'statistics_moves')
			elseif cat == 'pickup_countups' then
				appendix = text(val == 1 and 'statistics_up' or 'statistics_ups')
			elseif cat == 'pickup_countdowns' then
				appendix = text(val == 1 and 'statistics_down' or 'statistics_downs')
			end
			drawtext(pixolde, commalize(val) .. appendix, 390, 23 + (i * 15), right)

			-- TOOD: if board is daily, draw refresh timer as well
		end

		if best.player ~= nil then
			local line_offset = 0

			if len(best.player) == 16 and tonumber(best.player) then
				line_offset = -13
				drawtext(pixolde, text('scores_username_cta'), 200, 183 + (save.control_bar and 0 or 18), center)
			end

			gfx.setLineWidth(1)
			setcolor(0, 0, 0, 1, 'black')
			drawline(20, 191 + line_offset + (save.control_bar and 0 or 18), 380, 191 + line_offset + (save.control_bar and 0 or 18))
			gfx.setLineWidth(2)
			drawtext(pixolde, ordinal(best.rank) .. '.', 10, 198 + (save.control_bar and 0 or 18))
			drawtext(pixolde_bold, best.player, 38, 198 + (save.control_bar and 0 or 18))
			local w = textwidth(pixolde_bold, best.player)
			drawtext(pixolde_italic, text('scores_you'), 43 + w, 198 + (save.control_bar and 0 or 18))
			local val = best.value
			local appendix = ''
			if cat == 'klondike_score' or cat == 'klondike_daily_score' or cat == 'pickup_score' then
				appendix = text('statistics_points')
			elseif cat == 'klondike_lowest_moves' then
				appendix = text(val == 1 and 'statistics_move' or 'statistics_moves')
			elseif cat == 'klondike_games_won' then
				appendix = text(val == 1 and 'statistics_win' or 'statistics_won')
			elseif cat == 'pickup_countups' then
				appendix = text(val == 1 and 'statistics_up' or 'statistics_ups')
			elseif cat == 'pickup_countdowns' then
				appendix = text(val == 1 and 'statistics_down' or 'statistics_downs')
			end
			drawtext(pixolde, commalize(val) .. appendix, 390, 198 + (save.control_bar and 0 or 18), right)
		end
	elseif result == 'fail' then -- show fail state
		drawimagetable(assets.failed, floor(value('failed_anim')), 170, 90 + (save.control_bar and 0 or 9))
		drawtext(pixolde, text('scores_failed'), 200, 135 + (save.control_bar and 0 or 9), center)
	elseif vars.loading then -- loading...!
		drawimagetable(assets.loading, floor(value('loading_anim')), 170, 90 + (save.control_bar and 0 or 9))
		drawtext(pixolde, text('scores_loading'), 200, 135 + (save.control_bar and 0 or 9), center)
	else -- empty scoreboard.
		drawimagetable(assets.empty, floor(value('empty_anim')), 170, 90 + (save.control_bar and 0 or 9))
		drawtext(pixolde, text('scores_empty'), 200, 135 + (save.control_bar and 0 or 9), center)
	end

	if save.control_bar then
		setcolor(0, 0, 0, 1, 'black')
		-- drawing control bar
		fillrect(0, 220, 400, 20)
		setcolor(255, 255, 255, 1, 'black')

		local controls

		-- parsing controls based on context
		if vars.handler == '' then
			controls = text('control_pleasewait')
		else
			if not vars.loading then
				controls = text('control_category') .. text('control_refresh') .. text('control_back')
			else
				controls = text('control_back')
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
end

function highscores:refresh()
	if not vars.loading then
		vars.loading = true
		if vars.handler == 'highscores' then vars.handler = 'refreshingscores' end
		loopingtimer('loading_anim', 3500, 1, 46.99) -- for the card animation
		local cat = vars.categories[vars.category_selection]
		vars.results[cat .. '_result'] = {}
		vars.bests[cat .. '_best'] = {}
		local tograb = gsub(cat, '_', '') -- get scoreboard ID (no underscores)
		-- get global board
		pd.scoreboards.getScores(tograb, function(status, result)
			if vars.handler == 'refreshingscores' then
				if status.code == 'OK' then
					vars.results[cat .. '_result'] = result
					-- attempt to get player's own on-line PB
					pd.scoreboards.getPersonalBest(tograb, function(bstatus, bresult)
						if vars.handler == 'refreshingscores' then
							if bstatus.code == 'OK' then
								vars.bests[cat .. '_best'] = bresult
							end
							vars.loading = false
							vars.handler = 'highscores'
							loopingtimer('empty_anim', 900, 1, 4.99) -- for the card animation
						end
					end)
				else
					vars.results[cat .. '_result'] = 'fail'
					vars.loading = false
					vars.handler = 'highscores'
					newtimer('failed_anim', 500, 1, 9.99) -- for the card animation
				end
			end
		end)
	end
end

function highscores:keypressed(button)
	if vars.handler == 'highscores' then
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
				if vars.results[vars.categories[vars.category_selection] .. '_result'].scores == nil then
					self:refresh()
				end
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
				if vars.results[vars.categories[vars.category_selection] .. '_result'].scores == nil then
					self:refresh()
				end
			end
		elseif button == 'a' then
			self:refresh()
		elseif button == 'b' then
			playsound(bump)
			scenemanager:transitionsceneback(title, 'highscores')
		end
	elseif vars.handler == 'refreshingscores' then
		if button == 'b' then
			playsound(bump)
			scenemanager:transitionsceneback(title, 'highscores')
		end
	end
end