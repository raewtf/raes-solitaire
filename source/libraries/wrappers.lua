local pd <const> = playdate
local gfx <const> = pd.graphics
local smp <const> = pd.sound.sampleplayer
local geo <const> = pd.geometry
local sub <const> = string.sub

function savegame()
	pd.datastore.write(save)
end

function newimage(image, y, color)
	if y ~= nil then
		color = color or 'clear'
		if color == 'black' then
			return gfx.image.new(image, y, gfx.kColorBlack)
		elseif color == 'white' then
			return gfx.image.new(image, y, gfx.kColorWhite)
		elseif color == 'clear' then
			return gfx.image.new(image, y, gfx.kColorClear)
		end
	else
		return gfx.image.new(image)
	end
end

function drawimage(image, x, y, flip)
	local flipp
	if flip == 'flipx' then
		flipp = gfx.kImageFlippedX
	end
	image:draw(x, y, flip)
end

function clearimage(image, color)
	color = color or 'clear'
	if color == 'black' then
		image:clear(gfx.kColorBlack)
	elseif color == 'white' then
		image:clear(gfx.kColorWhite)
	elseif color == 'clear' then
		image:clear(gfx.kColorClear)
	end
end

function newimagetable(image, width, height, cells)
	return gfx.imagetable.new(image)
end

function drawimagetable(image, index, x, y)
	drawimage(image[index], x, y)
end

function newnineslice(image, innerx, innery, innerwidth, innerheight)
	return gfx.nineSlice.new(image, innerx, innery, innerwidth, innerheight)
end

function drawnineslice(image, x, y, width, height)
	image:drawInRect(x, y, width, height)
end

function newtimer(name, duration, startvalue, endvalue, easing, callback)
	vars[name] = pd.timer.new(duration, startvalue, endvalue, easing ~= nil and pd.easingFunctions[easing] or pd.easingFunctions.linear)
	vars[name].discardOnCompletion = false
	vars[name].timerEndedCallback = callback or nil
	vars[name].delay = 0
end

function timerendedcallback(name, callback)
	vars[name].timerEndedCallback = callback or nil
end

function timeleft(name)
	if vars[name] ~= nil then
		return vars[name].timeLeft
	else
		return 0
	end
end

function value(name)
	if vars[name] ~= nil then
		return vars[name].value
	else
		return 0
	end
end

function resettimer(name, duration, startvalue, endvalue, easing, callback)
	if name == 'quikword' then
		self = quikword
	else
		self = vars[name]
	end
	self.duration = duration
	if startvalue ~= nil then
		self._startValue = startvalue
		self.originalValues.startValue = startvalue
		self._endValue = endvalue or 0
		self.originalValues.endValue = endvalue or 0
		self._easingFunction = easing ~= nil and pd.easingFunctions[easing] or pd.easingFunctions.linear
		self.originalValues.easingFunction = easing ~= nil and pd.easingFunctions[easing] or pd.easingFunctions.linear
		self._currentTime = 0
		self.value = self._startValue
	end
	self._lastTime = nil
	self.active = true
	self.hasReversed = false
	self.reverses = false
	self.repeats = false
	self.delay = 0
	self.remainingDelay = self.delay
	self._calledOnRepeat = nil
	self.discardOnCompletion = false
	self.paused = false
	self.timerEndedCallback = callback or self.timerEndedCallback
end

function loopingtimer(name, duration, startvalue, endvalue, easing, callback)
	newtimer(name, duration, startvalue, endvalue, easing, callback)
	if vars[name] ~= nil then
		vars[name].repeats = true
	end
end

function delaytimer(name, delay, duration, startvalue, endvalue, easing, callback)
	newtimer(name, duration, startvalue, endvalue, easing, callback)
	if vars[name] ~= nil then
		vars[name].delay = delay
	end
end

function loopingdelaytimer(name, delay, duration, startvalue, endvalue, easing, callback)
	newtimer(name, duration, startvalue, endvalue, easing, callback)
	if vars[name] ~= nil then
		vars[name].delay = delay
		vars[name].repeats = true
	end
end

function afterdelay(name, duration, callback)
	if save.anim_speed == 0 then
		callback()
	else
		if vars ~= nil then
			vars[name] = pd.timer.performAfterDelay(duration, callback)
		end
	end
end

function newfont(font)
	return gfx.font.new(font)
end

function drawtext(font, text, x, y, alignment)
	if alignment ~= nil then
		font:drawTextAligned(text, x, y, alignment)
	else
		font:drawText(text, x, y)
	end
end

function textwidth(font, text)
	return font:getTextWidth(text)
end

function newsound(sound)
	return smp.new(sound)
end

-- Plays a sound (stopping the previous instance if already playing). Import peedee sound object
function playsound(sound)
	if save.sfx then
		sound:stop()
		sound:play()
	end
end

-- Create a pool of up to five sound effects, randomly playing one of 'em. Import peedee sound objects
function randomizesfx(sfx1, sfx2, sfx3, sfx4, sfx5, rate)
	if save.sfx then
		local sfc = 0
		if sfx1 ~= nil then sfc += 1 end
		if sfx2 ~= nil then sfc += 1 end
		if sfx3 ~= nil then sfc += 1 end
		if sfx4 ~= nil then sfc += 1 end
		if sfx5 ~= nil then sfc += 1 end
		local rand = randInt(1, sfc)
		if rand == 1 then
			sfx1:setRate(rate or 1)
			playsound(sfx1)
		elseif rand == 2 then
			sfx2:setRate(rate or 1)
			playsound(sfx2)
		elseif rand == 3 then
			sfx3:setRate(rate or 1)
			playsound(sfx3)
		elseif rand == 4 then
			sfx4:setRate(rate or 1)
			playsound(sfx4)
		elseif rand == 5 then
			sfx5:setRate(rate or 1)
			playsound(sfx5)
		end
	end
end

-- Plays a sound (stopping the previous instance if already playing). Import peedee sound object
function playcardsound(sound)
	if save.card_sfx then
		sound:stop()
		sound:play()
	end
end

-- Create a pool of up to five sound effects, randomly playing one of 'em. Import peedee sound objects
function randomizecardsfx(sfx1, sfx2, sfx3, sfx4, sfx5, rate)
	if save.card_sfx then
		local sfc = 0
		if sfx1 ~= nil then sfc += 1 end
		if sfx2 ~= nil then sfc += 1 end
		if sfx3 ~= nil then sfc += 1 end
		if sfx4 ~= nil then sfc += 1 end
		if sfx5 ~= nil then sfc += 1 end
		local rand = randInt(1, sfc)
		if rand == 1 then
			sfx1:setRate(rate or 1)
			playsound(sfx1)
		elseif rand == 2 then
			sfx2:setRate(rate or 1)
			playsound(sfx2)
		elseif rand == 3 then
			sfx3:setRate(rate or 1)
			playsound(sfx3)
		elseif rand == 4 then
			sfx4:setRate(rate or 1)
			playsound(sfx4)
		elseif rand == 5 then
			sfx5:setRate(rate or 1)
			playsound(sfx5)
		end
	end
end

-- Fades the music out, and trashes it when finished. Should be called alongside a scene change, only if the music is expected to change. Delay can set the delay (in seconds) of the fade
function fademusic(delay)
	delay = delay or 400
	if music ~= nil then
		music:setVolume(0, 0, delay / 1000, function()
			music:stop()
			music = nil
		end)
	end
end

function stopmusic()
	if music ~= nil then
		music:stop()
		music = nil
	end
end

-- New music track. If a track's already playing, it will attempt to lead in naturally.
function newmusic(file)
	if save.music then
		local offset = 0
		if music ~= nil then
			offset = music:getOffset()
			stopmusic()
		end
		music = pd.sound.fileplayer.new(file)
		music:setOffset(offset)
		music:setLoopRange(0)
		music:play(0)
	end
end

-- r, g, b are unused. alpha and alphaoverride are ranges from 0 to 1
function setcolor(r, g, b, alpha, color, alphaoverride)
	color = color or 'black'
	alpha = alphaoverride or (-alpha + 1) or 0
	if color == 'black' then
		gfx.setColor(gfx.kColorBlack)
	elseif color == 'white' then
		gfx.setColor(gfx.kColorWhite)
	elseif color == 'clear' then
		gfx.setColor(gfx.kColorClear)
		return
	end
	if alpha ~= 0 then
		gfx.setDitherPattern(alpha, gfx.image.kDitherTypeBayer4x4)
	end
end

function setbackgroundcolor(color)
	color = color or 'black'
	if color == 'black' then
		gfx.setBackgroundColor(gfx.kColorBlack)
	elseif color == 'white' then
		gfx.setBackgroundColor(gfx.kColorWhite)
	elseif color == 'clear' then
		gfx.setBackgroundColor(gfx.kColorClear)
	end
end

function drawrect(x, y, w, h, r)
	r = r or 0
	if r > 0 then
		gfx.drawRoundRect(x, y, w, h, r)
	else
		gfx.drawRect(x, y, w, h)
	end
end

function fillrect(x, y, w, h, r)
	r = r or 0
	if r > 0 then
		gfx.fillRoundRect(x, y, w, h, r)
	else
		gfx.fillRect(x, y, w, h)
	end
end

function drawline(x1, y1, x2, y2)
	gfx.drawLine(x1, y1, x2, y2)
end

function drawcircle(x, y, radius)
	gfx.drawCircleAtPoint(x, y, radius)
end

function fillcircle(x, y, radius)
	gfx.fillCircleAtPoint(x, y, radius)
end

function drawtriangle(x1, y1, x2, y2, x3, y3)
	gfx.drawTriangle(x1, y1, x2, y2, x3, y3)
end

function filltriangle(x1, y1, x2, y2, x3, y3)
	gfx.fillTriangle(x1, y1, x2, y2, x3, y3)
end

function drawpolygon(points, transform)
	gfx.drawPolygon(table.unpack(points))
end

function fillpolygon(points, transform)
	gfx.fillPolygon(table.unpack(points))
end

function setcliprect(x, y, w, h)
	gfx.setClipRect(x, y, w, h)
end

function clearcliprect()
	gfx.clearClipRect()
end

function pushcontext(image)
	gfx.pushContext(image)
end

function popcontext()
	gfx.popContext()
end

function gettime()
	return pd.getTime()
end