-- Modified 2026-09-29 by StatIndet: Cupertino split-rail volume control.
-- Derived from uosc 5.13.0; retains its LGPL license (see LICENSES/).
local Element = require('elements/Element')

-- The slider keeps a generous hit area; only its central capsule is painted.
local VolumeSlider = class(Element)
function VolumeSlider:new(props) return Class.new(self, props) end
function VolumeSlider:init(props)
	Element.init(self, 'volume_slider', props)
	self.pressed = false
end

function VolumeSlider:get_visibility() return Elements.volume:get_visibility() end

function VolumeSlider:set_volume(volume)
	volume = round(volume / options.volume_step) * options.volume_step
	volume = clamp(0, volume, state.volume_max)
	if state.volume ~= volume then mp.commandv('set', 'volume', volume) end
end

-- Both the rendering and hit testing use this split; the gap holds exactly 100%.
function VolumeSlider:segments()
 local gap = state.volume_max > 100 and 6 * state.scale or 0
 local height = self.by - self.ay - gap
 local split = self.ay + height * math.max(0, 1 - 100 / state.volume_max)
 return split, split + gap
end

function VolumeSlider:set_from_cursor()
 local height = self.by - self.ay
 if height <= 0 or state.volume_max <= 0 then return end
 local boost_bottom, normal_top = self:segments()
 local volume
 if state.volume_max <= 100 then
  volume = (self.by - cursor.y) / height * state.volume_max
 elseif cursor.y < boost_bottom then
  volume = 100 + (boost_bottom - cursor.y) / (boost_bottom - self.ay) * (state.volume_max - 100)
 elseif cursor.y <= normal_top then
  volume = 100
 else
  volume = (self.by - cursor.y) / (self.by - normal_top) * 100
 end
 self:set_volume(volume)
end

function VolumeSlider:on_global_mouse_move()
	if self.pressed then self:set_from_cursor() end
end
function VolumeSlider:on_global_mouse_leave() self.pressed = false end
function VolumeSlider:handle_wheel_up() self:set_volume(state.volume + options.volume_step) end
function VolumeSlider:handle_wheel_down() self:set_volume(state.volume - options.volume_step) end

function VolumeSlider:render()
 local visibility = self:get_visibility()
 if visibility <= 0 or self.by <= self.ay or state.volume_max <= 0 then return end
 cursor:zone('primary_down', self, function()
  self.pressed = true
  self:set_from_cursor()
  cursor:once('primary_up', function() self.pressed = false end)
 end)
 local ass = assdraw.ass_new()
 local hovered = self.pressed or (not cursor.hidden and cursor.x >= self.ax and cursor.x <= self.bx
  and cursor.y >= self.ay and cursor.y <= self.by)
 local width = (hovered and 12 or 9) * state.scale
 local cx = (self.ax + self.bx) / 2
 local boost_bottom, normal_top = self:segments()
 local opacity = visibility * (state.mute and 0.4 or 1)
 local function pill(top, bottom, fraction)
  if bottom <= top then return end
  local radius = math.min(width / 2, (bottom - top) / 2)
  ass:rect(cx - width / 2, top, cx + width / 2, bottom, {
   color = '70645E', opacity = visibility * 0.8, radius = radius,
  })
  local fill_top = bottom - (bottom - top) * clamp(0, fraction, 1)
  if bottom > fill_top then
   ass:rect(cx - width / 2, fill_top, cx + width / 2, bottom, {
    color = 'F7F3F1', opacity = opacity, radius = math.min(width / 2, (bottom - fill_top) / 2),
   })
  end
 end
 pill(normal_top, self.by, state.volume / math.min(100, state.volume_max))
 if state.volume_max > 100 then
  pill(self.ay, boost_bottom, (state.volume - 100) / (state.volume_max - 100))
 end
 return ass
end

local Volume = class(Element)
function Volume:new() return Class.new(self) end
function Volume:init()
	Element.init(self, 'volume', {render_order = 7})
	-- Keep the rail above the label/icon element with a deterministic order.
	self.slider = VolumeSlider:new({anchor_id = 'volume', render_order = 7.1})
	self.last_volume, self.last_mute = state.volume, state.mute
	self:update_dimensions()
end

function Volume:destroy()
	self.slider:destroy()
	Element.destroy(self)
end

function Volume:get_visibility()
	if not state.is_idle and not state.has_audio then return 0 end
	if self.slider.pressed then return 1 end
	if not self.forced_visibility and Elements:maybe('timeline', 'get_is_hovered') then return -1 end
	return Element.get_visibility(self)
end

function Volume:update_dimensions()
	local scale = state.scale
	self.size = round(math.max(options.volume_size, 64 * options.font_scale) * scale)
	local min_y = Elements:v('top_bar', 'by') or Elements:v('window_border', 'size', 0)
	local max_y = Elements:v('controls', 'ay') or Elements:v('timeline', 'ay')
		or display.height - Elements:v('window_border', 'size', 0)
	local available_height = max_y - min_y
	local height = round(math.min(360 * scale, available_height * 0.8))
	self.enabled = self.size >= 24 * scale and height >= 140 * scale
	local margin = 12 * scale + Elements:v('window_border', 'size', 0)
	self.ax = round(options.volume == 'left' and margin or display.width - margin - self.size)
	self.ay = round(min_y + (available_height - height) / 2)
	self.bx, self.by = self.ax + self.size, self.ay + height
	self.mute_ay = self.by - 40 * scale
	self.slider.enabled = self.enabled
	self.slider:set_coordinates(self.ax + 6 * scale, self.ay + 40 * scale,
		self.bx - 6 * scale, self.mute_ay - 8 * scale)
end

function Volume:on_prop_volume(value)
 if self.last_volume ~= nil and value ~= self.last_volume then self:flash() end
 self.last_volume = value
end
function Volume:on_prop_mute(value)
 if self.last_mute ~= nil and value ~= self.last_mute then self:flash() end
 self.last_mute = value
end

function Volume:on_display() self:update_dimensions() end
function Volume:on_prop_border() self:update_dimensions() end
function Volume:on_prop_title_bar() self:update_dimensions() end
function Volume:on_prop_volume_max() self:update_dimensions() end
function Volume:on_controls_reflow() self:update_dimensions() end
function Volume:on_options() self:update_dimensions() end

function Volume:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	local scale = state.scale
	cursor:zone('secondary_click', self, function()
		mp.set_property_native('mute', false)
		mp.set_property_native('volume', math.min(100, state.volume_max))
	end)
	cursor:zone('wheel_down', self, function() self.slider:handle_wheel_down() end)
	cursor:zone('wheel_up', self, function() self.slider:handle_wheel_up() end)
	local mute_rect = {ax = self.ax, ay = self.mute_ay, bx = self.bx, by = self.by}
	cursor:zone('primary_down', mute_rect, function() mp.commandv('cycle', 'mute') end)

 local ass = assdraw.ass_new()
 local cx = (self.ax + self.bx) / 2
 local label = tostring(round(state.volume)) .. '%'
 ass:txt(cx, self.ay + 17 * scale, 5, label, {
  font = 'sans-serif', size = math.min(24 * scale * options.font_scale, self.size / (#label * 0.6)),
  color = 'F7F3F1', opacity = visibility * (state.mute and 0.5 or 1), bold = false,
  border = 0.5 * scale, border_color = '202020',
 })
 local icon = state.mute and 'speaker_slash_fill' or state.volume <= 0 and 'speaker_fill'
  or state.volume <= 60 and 'speaker_1_fill' or 'speaker_3_fill'
 ass:icon(cx, self.mute_ay + 18 * scale, 21 * scale, icon, {
  color = 'F7F3F1', opacity = visibility * (state.mute and 0.65 or 1),
  border = 0.5 * scale, border_color = '202020',
 })
	return ass
end

return Volume
