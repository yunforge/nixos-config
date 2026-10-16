-- Run: lua tests/volume.lua
-- Optional real ASS preview: MPV_VOLUME_PREVIEW=/tmp/volume.ass mpv --no-config --idle=yes --vo=null --script=tests/volume.lua
package.path = './scripts/uosc/?.lua;' .. package.path
require('lib/std')
local real_mp = mp
local commands, zones, rectangles = {}, {}, {}
mp = {
 log = real_mp and real_mp.log,
 commandv = function(...) commands[#commands + 1] = {...} end,
 set_property_native = function(k, v) commands[#commands + 1] = {'set', k, v} end,
}
local Element = class()
function Element:init(id, props)
 self.id = id
 for k,v in pairs(props or {}) do self[k] = v end
 Elements[id] = self
end
function Element:get_visibility() return self.forced_visibility or 1 end
function Element:flash() self.flashes=(self.flashes or 0)+1 end
function Element:set_coordinates(ax,ay,bx,by) self.ax,self.ay,self.bx,self.by=ax,ay,bx,by end
function Element:destroy() end
package.loaded['elements/Element'] = Element
Elements = {
 v = function(_,id,key,default)
  if id=='top_bar' then return 36 end
  if id=='controls' then return display.height - 76 end
  return default
 end,
 maybe = function() return false end,
}
options = {volume_size=40,volume='right',volume_step=1,font_scale=1}
state = {scale=1,volume=70,volume_max=130,has_audio=true,mute=false}
display = {width=640,height=480}
cursor = {hidden=true, zone=function(_,kind,rect,cb) zones[#zones+1]={kind,rect,cb} end,
 once=function(_,kind,cb) cursor.release=cb end}
config = {font='Noto Sans'}
function opacity_to_alpha(v) return round((1-v)*255) end
if real_mp then
 assdraw = require('mp.assdraw')
 require('lib/ass')
else
 assdraw = {ass_new=function() return setmetatable({rect=function(_,ax,ay,bx,by) rectangles[#rectangles+1]={ax,ay,bx,by} end}, {__index=function() return function() end end}) end}
end
local Volume = require('elements/Volume')
local volume = Volume:new()
local slider = volume.slider
assert(volume.enabled and slider.render_order > volume.render_order)
local function last_volume() return commands[#commands][3] end
for _, max in ipairs({80,100,130,200}) do
 state.volume_max=max
 for _, fraction in ipairs({0,.5,1}) do
  local boost_bottom, normal_top=slider:segments()
  local target=max*fraction
  cursor.y=max<=100 and (slider.by-(slider.by-slider.ay)*fraction)
   or target<=100 and (slider.by-(slider.by-normal_top)*target/100)
   or (boost_bottom-(boost_bottom-slider.ay)*(target-100)/(max-100))
  slider:set_from_cursor()
  assert(last_volume()==round(max*fraction), 'drag must cover the full configured range')
 end
 cursor.y=slider.ay-100;slider:set_from_cursor();assert(last_volume()==max)
 cursor.y=slider.by+100;slider:set_from_cursor();assert(last_volume()==0)
end
state.volume_max=130
local boost_bottom,normal_top=slider:segments()
cursor.y=(boost_bottom+normal_top)/2;slider:set_from_cursor();assert(last_volume()==100, 'gap must hold 100%')
volume:on_prop_volume(75);assert(volume.flashes==1)
volume:on_prop_mute(true);assert(volume.flashes==2)
volume:on_prop_mute(true);assert(volume.flashes==2)
state.volume=100
slider:handle_wheel_up();assert(last_volume()==101, 'wheel must cross 100%')
state.volume=130;local count=#commands;slider:handle_wheel_up();assert(#commands==count, 'max must not issue an out-of-range command')
state.volume=70
volume:render();slider:render()
if not real_mp then
 assert(rectangles[1][3]-rectangles[1][1]==9, 'resting rail must be 9px')
 rectangles={};cursor.hidden=false;cursor.x=(slider.ax+slider.bx)/2;cursor.y=(slider.ay+slider.by)/2
 slider:render();assert(rectangles[1][3]-rectangles[1][1]==12, 'hover rail must be 12px')
 cursor.hidden=true
end
local function trigger(kind,target)
 for _,z in ipairs(zones) do if z[1]==kind and z[2]==target then z[3]();return end end
 error('missing zone '..kind)
end
trigger('primary_down',slider);assert(slider.pressed);cursor.release();assert(not slider.pressed)
slider.pressed=true;slider:on_global_mouse_leave();assert(not slider.pressed)
trigger('secondary_click',volume);assert(last_volume()==100)
for _,z in ipairs(zones) do
 if z[1]=='primary_down' and z[2].ay==volume.mute_ay then
  z[3]();assert(commands[#commands][1]=='cycle' and commands[#commands][2]=='mute')
 end
end
state.volume_max=80;trigger('secondary_click',volume);assert(last_volume()==80)
state.has_audio=false;assert(volume:get_visibility()==0);state.has_audio=true
for _,scale in ipairs({1,1.3,2}) do
 state.scale=scale;display.height=720*scale;volume:update_dimensions()
 assert(volume.enabled and slider.by>slider.ay and slider.ay>volume.ay and slider.by<volume.mute_ay)
end
state.scale=1;display.height=180;volume:update_dimensions();assert(not volume.enabled)
print('PASS: full-range drag, boost, bounds, gap mapping, shortcut flash, reset, drag release, audio visibility and responsive layout')
if real_mp then
 state.scale=1;display.height=480;volume:update_dimensions()
 local f=assert(io.open(assert(os.getenv('MPV_VOLUME_PREVIEW')), 'w'))
 f:write('[Script Info]\nScriptType: v4.00+\nPlayResX: 640\nPlayResY: 480\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,Noto Sans,14,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,5,0,0,0,1\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n')
 for i,s in ipairs({{0,130,false},{70,130,false},{100,130,false},{125,130,false},{125,130,true},{200,200,false}}) do
  state.volume,state.volume_max,state.mute=s[1],s[2],s[3]
  local data=volume:render().text..'\n'..slider:render().text
  for line in data:gmatch('[^\n]+') do
   f:write(string.format('Dialogue: 0,0:00:0%d.00,0:00:0%d.00,Default,,0,0,0,,%s\n',i-1,i,line))
  end
 end
 f:close()
 mp = real_mp
 real_mp.commandv('quit')
end
