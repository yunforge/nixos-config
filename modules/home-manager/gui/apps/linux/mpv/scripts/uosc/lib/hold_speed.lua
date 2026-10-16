-- SPDX-License-Identifier: MIT
-- Delay secondary-click dispatch so a long press never opens a menu.
local opts = {delay = 0.35, speed = 2}
require('mp.options').read_options(opts, 'hold-speed')
local timer, previous, pressed
local function cancel()
	if timer then timer:kill(); timer = nil end
	if previous then
		mp.set_property_number('speed', previous)
		previous = nil
		state.hold_speed_active = false
		request_render()
	end
	pressed = false
end
local function down(source)
	if pressed or cursor.disabled then return end
	pressed = source
	timer = mp.add_timeout(math.max(0.05, opts.delay), function()
		timer = nil
		if pressed and not mp.get_property_bool('idle-active') then
			previous = mp.get_property_number('speed', 1)
			mp.set_property_number('speed', math.max(previous, opts.speed))
			state.hold_speed_active = true
			request_render()
		end
	end)
end
local function up(source)
	if pressed ~= source then return end
	local was_held = previous ~= nil
	cancel()
	if not was_held then
		if source == 'keyboard' then
			mp.commandv('script-message-to', 'seek_feedback', 'seek', '5')
		else
			cursor:trigger('secondary_down', create_shortcut('secondary_down'))
			cursor:trigger('secondary_up', create_shortcut('secondary_up'))
		end
	end
end
mp.register_event('end-file', cancel)
mp.register_event('shutdown', cancel)
mp.observe_property('focused', 'bool', function(_, value) if value == false then cancel() end end)
mp.observe_property('mouse-pos', 'native', function(_, value) if value and value.hover == false then cancel() end end)
mp.add_key_binding(nil, 'hold-right', function(event)
	if event.event == 'down' then down('keyboard')
	elseif event.event == 'up' then up('keyboard')
	elseif event.event == 'press' then mp.commandv('script-message-to', 'seek_feedback', 'seek', '5') end
end, {complex = true})
return {down = function() down('mouse') end, up = function() up('mouse') end}
