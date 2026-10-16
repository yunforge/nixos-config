-- Run: lua tests/menu-anchor.lua
package.path='./scripts/uosc/?.lua;'..package.path
require('lib/std')
local Element=class()
function Element:set_coordinates(ax,ay,bx,by) self.ax,self.ay,self.bx,self.by=ax,ay,bx,by end
function Element:tween_property(key,_,value) self[key]=value end
package.loaded['elements/Element']=Element
display={width=1280,height=720}
local Menu=require('elements/Menu')
for _,point in ipairs({{0,0},{640,360},{1279,719},{0,719},{1279,0}}) do
 for _,count in ipairs({6,40}) do
  local items={};for i=1,count do items[i]={} end
  local entry={items=items,max_width=300,is_root=true,title='Menu',scroll_y=0}
  local menu=setmetatable({pointer_anchor={x=point[1],y=point[2]},item_height=36,
   scroll_step=37,padding=8,min_width=260,separator_size=1,font_size=22,item_spacing=1,
   all={entry},current=entry,offset_x=0,set_scroll_to=function() end},{__index=Menu})
  menu:update_dimensions()
  assert(menu.ax>=0 and menu.bx<=display.width)
  assert(entry.top-39-menu.padding>=0 and menu.by+33<=display.height)
  local x,y=menu.ax,menu.ay
  cursor={x=900,y=600};menu:update_dimensions()
  assert(menu.ax==x and menu.ay==y,'menu must not follow the pointer after opening')
 end
end
local Curtain=require('elements/Curtain')
local curtain=setmetatable({dependents={},opacity=0},{__index=Curtain})
config={opacity={curtain=.5}}
curtain:register('menu',false);assert(curtain.opacity==1 and curtain:render()==nil)
curtain:unregister('menu');assert(curtain.dim==false)
curtain:register('menu');assert(curtain.dim==true)
print('PASS: pointer placement, four edges, tall menus, stable anchor and undimmed curtain lifecycle')
