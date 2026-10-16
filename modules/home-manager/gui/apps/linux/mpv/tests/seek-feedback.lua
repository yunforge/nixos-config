-- Run from repository root: lua tests/seek-feedback.lua
local time, timer, seek, bindings, events = 0, nil, nil, {}, {}
local overlay = {update=function() end, remove=function(self) self.data='' end}
local fake = {
 create_osd_overlay=function() return overlay end,
 get_time=function() return time end,
 get_osd_size=function() return 1280,720 end,
 get_property_bool=function() return false end,
 command=function(command) assert(command:match('^no%-osd seek .+ relative%+exact$')) end,
 add_periodic_timer=function(_,cb) timer={tick=cb,kill=function(self) self.killed=true end}; return timer end,
 register_script_message=function(_,cb) seek=cb end,
 add_key_binding=function(_,name,cb) bindings[name]=cb end,
 register_event=function(name,cb) events[name]=cb end,
 observe_property=function() end,
}
package.preload.mp=function() return fake end
package.preload['mp.assdraw']=function() return {ass_new=function()
 return setmetatable({text=''}, {__index=function(_,key)
  if key=='append' then return function(self,s) self.text=self.text..s end end
  return function() end
 end})
end} end
 dofile('scripts/seek_feedback.lua')
seek('5');time=.08;timer.tick()
local function arrows() local _,n=overlay.data:gsub('\\an7','');return n end
assert(arrows()==1, 'single tap must show one arrow')
time=.1;seek('5');time=.2;seek('5');time=.3;timer.tick()
assert(overlay.data:find('+ 15',1,true), 'same-direction seeks must accumulate')
assert(arrows()>1, 'repeated taps must create pursuing arrows')
time=.55;timer.tick();assert(arrows()==1, 'pursuing arrows must merge, not loop')
bindings.back10({event="press"});time=.65;timer.tick()
assert(overlay.data:find('− 10',1,true), 'reversing direction must reset accumulation')
time=1.9;timer.tick();assert(overlay.data=='' and timer.killed)
bindings.forward5({event="press"});events['end-file']();assert(overlay.data=='')
bindings.forward5({event='down'});time=2.1;bindings.forward5({event='repeat'});timer.tick()
assert(overlay.data:find('+ 10',1,true))
bindings.forward5({event='up'});time=3.5;timer.tick();assert(overlay.data=='')
print('PASS: accumulation, reversal, silent seek, tap/repeat/hold, finite arrow merging, timed dismissal and end-file cleanup')
local function zoom() return tonumber(overlay.data:match('\\fscx([%d.]+)')) end
time=4;bindings.forward5({event='press'})
time=4.04;timer.tick();assert(zoom()<95, 'number must compress after seek')
time=4.15;timer.tick();assert(zoom()>100, 'number must rebound past resting scale')
local before=zoom();bindings.forward5({event='press'});assert(math.abs(zoom()-before)<0.001, 'retrigger must preserve current scale')
time=4.52;timer.tick();assert(zoom()==100, 'number must settle without lingering oscillation')
events['end-file']()
print('PASS: numeral compression, nonlinear rebound, seamless retrigger and settling')
