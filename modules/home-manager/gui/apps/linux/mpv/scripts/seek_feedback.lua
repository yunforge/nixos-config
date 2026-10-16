-- SPDX-License-Identifier: MIT
-- Single chevron at rest; repeated seeks send new chevrons out to merge with it.
local mp = require 'mp'
local assdraw = require 'mp.assdraw'
local overlay = mp.create_osd_overlay('ass-events')
local direction, total, started, last = 1, 0, 0, -math.huge
local pulses, timer, held = {}, nil, nil
local number_started, number_from = -math.huge, 1
local function clamp(x) return math.max(0, math.min(1, x)) end
local function out(t) return 1 - (1 - clamp(t)) ^ 3 end
local function smooth(t) t=clamp(t); return t*t*(3-2*t) end
-- Reference recording: numerals compress briefly, rebound, then settle.
-- Sampling the current scale before retriggering keeps rapid repeats continuous.
local function number_scale(now)
    local age = now-number_started
    if age < 0.035 then
        return number_from + (0.88-number_from)*smooth(age/0.035)
    elseif age < 0.355 then
        local t=age-0.035
        local spring=1-0.12*math.exp(-10*t)*math.cos(25*t)
        return 1+(spring-1)*(1-smooth((t-0.24)/0.08))
    end
    return 1
end
local function clear()
    if timer then timer:kill(); timer=nil end
    overlay:remove()
    total, last, pulses, held = 0, -math.huge, {}, nil
    number_started,number_from=-math.huge,1
end
local function render()
    local now = mp.get_time()
    local age = now-last
    if age >= 1.25 and not held then clear(); return end
    local w,h=mp.get_osd_size()
    if w<=0 or h<=0 then return end
    -- Match the enlarged 24px playback labels; scale the whole composition together.
    local scale=1.5*math.max(0.65,math.min(h/856,1.5))
    local enter=smooth((now-started)/0.16)
    local leave=held and 1 or (1-smooth((age-1.02)/0.23))
    local opacity=enter*leave
    local x=direction>0 and w-49*scale or 49*scale
    local y=h/2
    x=x-direction*9*scale*(1-out((now-started)/0.22))
    local ass=assdraw.ass_new()
    local function chevron(cx, bend, alpha)
        if alpha<=0 then return end
        ass:new_event()
        ass:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&HFFFFFF&\\1a&H%02X&}',math.floor(255*(1-clamp(alpha)))))
        -- A vertical stroke opens into a slim chevron before it catches the lead.
        local tip=cx+direction*4.5*scale*bend
        local back=cx-direction*4.5*scale*bend
        local thick=1.8*scale
        ass:draw_start()
        ass:move_to(back,y-9*scale)
        ass:line_to(tip,y)
        ass:line_to(back,y+9*scale)
        ass:line_to(back-direction*thick,y+7.5*scale)
        ass:line_to(tip-direction*thick,y)
        ass:line_to(back-direction*thick,y-7.5*scale)
        ass:draw_stop()
    end
    -- Each actual repeat has its own finite animation; nothing loops after release.
    local alive={}
    for _,birth in ipairs(pulses) do
        local t=(now-birth)/0.30
        if t<1 then
            alive[#alive+1]=birth
            local travel=out(t)
            local cx=x-direction*17*scale*(1-travel)
            local alpha=smooth(t/0.16)*(1-smooth((t-0.65)/0.35))
            chevron(cx,out(t/0.45),opacity*alpha*0.8)
        end
    end
    pulses=alive
    chevron(x,1,opacity*0.95)
    local label=(direction>0 and '+' or '−')..' '..total
    local font_size=24*scale
    -- Keep the resting edge nearest the arrow stable as digit counts change;
    -- animate about the center of the entire label, including its sign.
    local label_width=(#tostring(total)*0.42+0.68)*font_size
    local tx=x-direction*(22*scale+label_width/2)
    local zoom=number_scale(now)*100
    ass:new_event()
    ass:append(string.format('{\\an5\\pos(%f,%f)\\fnsans-serif\\fs%f\\fscx%f\\fscy%f\\bord0\\shad0\\1c&HFFFFFF&\\alpha&H%02X&}%s',
        tx,y,font_size,zoom,zoom,math.floor(255*(1-opacity)),label))
    overlay.res_x,overlay.res_y,overlay.data=w,h,ass.text
    overlay:update()
end
local function seek(seconds)
    seconds=tonumber(seconds)
    if not seconds or seconds==0 or mp.get_property_bool('idle-active') then return end
    local now,dir=mp.get_time(),seconds>0 and 1 or -1
    local continuing=now-last<1.02 and dir==direction
    if not continuing then
        total,started,pulses=0,now,{}
    else
        pulses[#pulses+1]=now
    end
    number_from=continuing and number_scale(now) or 1
    number_started=now
    direction,total,last=dir,total+math.abs(seconds),now
    mp.command('no-osd seek '..seconds..' relative+exact')
    if not timer then timer=mp.add_periodic_timer(1/60,render) end
    render()
end
mp.register_script_message('seek',seek)
for name,seconds in pairs({back5=-5,forward5=5,back10=-10,forward10=10}) do
    local amount,id=seconds,name
    mp.add_key_binding(nil,name,function(event)
        -- Keyboard repeat cadence drives both seeking and individual arrow pulses.
        if event.event=='down' then held=id;seek(amount)
        elseif event.event=='repeat' then held=id;seek(amount)
        elseif event.event=='up' and held==id then held=nil;render()
        elseif event.event=='press' then seek(amount) end
    end,{repeatable=true,complex=true})
end
mp.observe_property('focused','bool',function(_,value) if value==false then clear() end end)
mp.register_event('end-file',clear)
mp.register_event('shutdown',clear)
