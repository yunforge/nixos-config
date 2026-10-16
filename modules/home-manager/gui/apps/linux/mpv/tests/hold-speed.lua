-- Run from repository root: lua tests/hold-speed.lua
package.path = './scripts/uosc/?.lua;' .. package.path
require('lib/std')
local timeout, key, speed = nil, nil, 1.25
local events, observers, commands = {}, {}, {}
state = {}
cursor = {disabled=false,trigger=function() commands[#commands+1]='mouse' end}
function create_shortcut(s) return s end
function request_render() end
package.preload['mp.options'] = function() return {read_options=function() end} end
mp = {
 add_timeout=function(_,cb) timeout={fire=cb,kill=function(self) self.killed=true end};return timeout end,
 get_property_bool=function() return false end,
 get_property_number=function() return speed end,
 set_property_number=function(_,v) speed=v end,
 commandv=function() commands[#commands+1]='seek' end,
 register_event=function(k,cb) events[k]=cb end,
 observe_property=function(k,_,cb) observers[k]=cb end,
 add_key_binding=function(_,_,cb) key=cb end,
}
local hold=require('lib/hold_speed')
key({event='down'});key({event='up'})
assert(timeout.killed and not state.hold_speed_active and speed==1.25 and commands[1]=='seek')
key({event='down'});timeout.fire()
assert(speed==2 and state.hold_speed_active)
key({event='repeat'});assert(state.hold_speed_active)
key({event='up'});assert(speed==1.25 and not state.hold_speed_active and #commands==1)
for _,cancel in ipairs({function() hold.up() end,function() observers.focused(nil,false) end,
 function() observers['mouse-pos'](nil,{hover=false}) end,events['end-file'],events.shutdown}) do
 hold.down();timeout.fire();assert(state.hold_speed_active)
 cancel();assert(not state.hold_speed_active and speed==1.25)
end
speed=3;hold.down();timeout.fire();assert(speed==3 and state.hold_speed_active);hold.up();assert(speed==3)
local Element=class()
function Element:get_visibility() return .2 end
package.loaded['elements/Element']=Element
Elements={curtain={opacity=0,render_order=10}}
local Speed=require('elements/Speed')
local widget=setmetatable({render_order=5},{__index=Speed})
state.hold_speed_active=true;assert(widget:get_visibility()==1)
Elements.curtain.opacity=1;assert(widget:get_visibility()==.2)
Elements.curtain.opacity=0;state.hold_speed_active=false;assert(widget:get_visibility()==.2)
print('PASS: short tap, keyboard/mouse hold visibility, repeat, cancellation, speed restoration and curtain priority')
