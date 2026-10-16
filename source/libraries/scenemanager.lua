transitiontime = 400
transitioning = false
transition = {}

local pd <const> = playdate
local gfx <const> = pd.graphics
local floor <const> = math.floor

class('scenemanager').extends()

function scenemanager:init()
	self.sprite = gfx.sprite.new()
	self.sprite:setZIndex(26000)
	self.sprite:setCenter(0, 0)
	self.sprite:moveTo(0, 0)
	self.sprite:setIgnoresDrawOffset(true)
end

function scenemanager:switchscene(scene, ...)
	if transitioning then return end
    self.newscene = scene
    self.sceneargs = {...}
    self:loadnewscene()
    transitioning = false
end

-- This function will transition the scene with an animated effect.
function scenemanager:transitionscene(scene, ...)
	if transitioning then return end -- If there's already a scene transition, go away.
	transitioning = true -- Set this to true
	self.newscene = scene
	self.sceneargs = {...}
	if vars ~= nil then vars.handler = '' end
	self.sprite:moveTo(0, 0 - (save.control_bar and 20 or 0))
	self.sprite:add()
	newtimer('transition', transitiontime, 0, 8, 'linear', function()
		self:loadnewscene()
		self.sprite:moveTo(0, 0 - (save.control_bar and 20 or 0))
		self.sprite:add()
		newtimer('transition', transitiontime, 8, 16, 'linear', function()
			-- After this timer's over, remove the transition and the sprites.
			transitioning = false
			self.sprite:remove()
		end, transition)
		vars.transition.updateCallback = function(timer)
			self.sprite:setImage(transition_image[floor(timer.value)])
		end
	end, transition)
	vars.transition.updateCallback = function(timer)
		self.sprite:setImage(transition_image[floor(timer.value)])
	end
end

-- This function will transition the scene with an animated effect.
function scenemanager:transitionsceneback(scene, ...)
	if transitioning then return end -- If there's already a scene transition, go away.
	transitioning = true -- Set this to true
	self.newscene = scene
	self.sceneargs = {...}
	if vars ~= nil then vars.handler = '' end
	self.sprite:moveTo(0, 0 - (save.control_bar and 20 or 0))
	self.sprite:add()
	newtimer('transition', transitiontime, 16, 8, 'linear', function()
		self:loadnewscene()
		self.sprite:moveTo(0, 0 - (save.control_bar and 20 or 0))
		self.sprite:add()
		newtimer('transition', transitiontime, 8, 0, 'linear', function()
			-- After this timer's over, remove the transition and the sprites.
			transitioning = false
			self.sprite:remove()
		end, transition)
		vars.transition.updateCallback = function(timer)
			self.sprite:setImage(transition_image[floor(timer.value)])
		end
	end, transition)
	vars.transition.updateCallback = function(timer)
		self.sprite:setImage(transition_image[floor(timer.value)])
	end
end

function scenemanager:loadnewscene()
    self:cleanupscene()
	savegame()
	self.newscene(table.unpack(self.sceneargs))
end

function scenemanager:cleanupscene()
	gfx.sprite:removeAll()
	local alltimers = pd.timer.allTimers()
	for _, timer in ipairs(alltimers) do
		timer:remove()
		timer = nil
	end
	gfx.setDrawOffset(0, 0) -- Lastly, reset the drawing offset. just in case.
    if assets ~= nil then
        for i = 1, #assets do
            assets[i] = nil
        end
    end
    assets = {} -- Nil all the assets,
    if vars ~= nil then
        for i = 1, #vars do
            vars[i] = nil
        end
    end
    vars = {} -- and nil all the variables.
    collectgarbage('collect') -- and collect the garbage.
end