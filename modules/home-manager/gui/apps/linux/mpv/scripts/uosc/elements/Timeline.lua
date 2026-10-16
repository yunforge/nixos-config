-- Modified 2026-09-29 by StatIndet: Cupertino UI / interaction customization.
-- Derived from uosc 5.13.0; retains its LGPL license (see LICENSES/).
local Element = require('elements/Element')

---@class Timeline : Element
local Timeline = class(Element)

function Timeline:new() return Class.new(self) --[[@as Timeline]] end
function Timeline:init()
	Element.init(self, 'timeline', {render_order = 5})
	---@type false|{pause: boolean, distance: number, last: {x: number, y: number}}
	self.pressed = false
	self.obstructed = false
	self.size = 0
	self.progress_size = 0
	self.min_progress_size = 0 -- used for `flash-progress`
	self.font_size = 0
	self.top_border = 0
	self.line_width = 0
	self.progress_line_width = 0
	self.is_hovered = false
	self.has_thumbnail = false
	self.heatmap = nil
	self.marker_reveal = 0
	self.marker_visible = false

	self:decide_progress_size()
	self:update_dimensions()

	-- Load Youtube heatmap data if available
	self:register_mp_event('file-loaded', function()
		self.heatmap = load_youtube_heatmap()
	end)
	-- Release any dragging and clear heatmap when file gets unloaded
	self:register_mp_event('end-file', function()
		self:reset_marker()
		self.pressed = false
		self.heatmap = nil
	end)
end

function Timeline:get_visibility()
	return math.max(Elements:maybe('controls', 'get_visibility') or 0, Element.get_visibility(self))
end

function Timeline:decide_enabled()
	local previous = self.enabled
	self.enabled = not self.obstructed and state.duration ~= nil and state.duration > 0 and state.time ~= nil
	if self.enabled ~= previous then Elements:trigger('timeline_enabled', self.enabled) end
end

function Timeline:get_effective_size()
	if Elements:v('speed', 'dragging') then return self.size end
	local progress_size = math.max(self.min_progress_size, self.progress_size)
	return progress_size + math.ceil((self.size - self.progress_size) * self:get_visibility())
end

function Timeline:get_is_hovered() return self.enabled and self.is_hovered end

function Timeline:update_dimensions()
	self.size = round(options.timeline_size * state.scale)
	self.top_border = round(options.timeline_border * state.scale)
	self.line_width = round(options.timeline_line_width * state.scale)
	self.progress_line_width = round(options.progress_line_width * state.scale)
	self.tooltip_font_size = math.floor(18 * state.scale * options.font_scale)
	local window_border_size = Elements:v('window_border', 'size', 0)
	self:update_time_gutters()
	self.by = display.height - window_border_size - (options.controls_size * 1.3 + options.controls_margin + 2) * state.scale
	self.ay = self.by - 22 * state.scale
	self.width = self.bx - self.ax
	self.chapter_size = math.max((self.by - self.ay) / 10, 3)
	self.chapter_size_hover = self.chapter_size * 2

	-- Disable if not enough space
	local available_space = display.height - window_border_size * 2 - Elements:v('top_bar', 'size', 0)
	self.obstructed = available_space < self.size + 10
	self:decide_enabled()
end

-- Reserve a stable digit budget for the whole file, including slow playback
-- remaining times. Noto Sans digits fit within 0.58em, with room for borders.
-- 本地：字体名由上游的 'Noto Sans' 改为 'sans-serif'（NixOS 侧没装 Noto Sans，
-- 改成通用族名后确定性命中 fonts.fontconfig.defaultFonts.sansSerif 首项）。
-- 上面的 0.58em 仍成立：本机 'sans-serif' 与 'Noto Sans' 落到同一个字体文件。
function Timeline:update_time_gutters()
	local border = Elements:v('window_border', 'size', 0)
	self.time_margin = border + 12 * state.scale
	self.font_size = math.min(math.floor(24 * state.scale * options.font_scale), display.width / 25)
	local duration = state.duration or 0
	local full = format_time(duration, duration)
	local remaining = format_time(duration / math.min(state.speed or 1, 1), duration)
	local left_chars = math.max(#full, #(state.time_human or '00:00'))
	local right_chars = math.max(#remaining + 1, #(state.destination_time_human or '-00:00'))
	local gap = 14 * state.scale
	self.ax = self.time_margin + left_chars * self.font_size * 0.58 + gap
	self.bx = display.width - self.time_margin - right_chars * self.font_size * 0.58 - gap
	self.width = math.max(1, self.bx - self.ax)
end

function Timeline:decide_progress_size()
	local show = options.progress == 'always'
		or (options.progress == 'fullscreen' and state.fullormaxed)
		or (options.progress == 'windowed' and not state.fullormaxed)
	self.progress_size = show and options.progress_size or 0
end

function Timeline:toggle_progress()
	local current = self.progress_size
	self:tween_property('progress_size', current, current > 0 and 0 or options.progress_size)
	request_render()
end

function Timeline:flash_progress()
	if self.enabled and options.flash_duration > 0 then
		if not self._flash_progress_timer then
			self._flash_progress_timer = mp.add_timeout(options.flash_duration / 1000, function()
				self:tween_property('min_progress_size', options.progress_size, 0)
			end)
			self._flash_progress_timer:kill()
		end

		self:tween_stop()
		self.min_progress_size = options.progress_size
		request_render()
		self._flash_progress_timer.timeout = options.flash_duration / 1000
		self._flash_progress_timer:kill()
		self._flash_progress_timer:resume()
	end
end

function Timeline:get_time_at_x(x)
	local line_width = (options.timeline_style == 'line' and self.line_width - 1 or 0)
	local time_width = self.width - line_width - 1
	local fax = (time_width) * state.time / state.duration
	local fbx = fax + line_width
	-- time starts 0.5 pixels in
	x = x - self.ax - 0.5
	if x > fbx then
		x = x - line_width
	elseif x > fax then
		x = fax
	end
	local progress = clamp(0, x / time_width, 1)
	return state.duration * progress
end

---@param fast? boolean
function Timeline:set_from_cursor(fast)
	if state.time and state.duration then
		mp.commandv('seek', self:get_time_at_x(cursor.x), fast and 'absolute+keyframes' or 'absolute+exact')
	end
end

function Timeline:clear_thumbnail()
	if self.has_thumbnail then
		mp.commandv('script-message-to', 'thumbfast', 'clear')
		self.has_thumbnail = false
	end
end

function Timeline:handle_cursor_down()
	self.pressed = {pause = state.pause, distance = 0, last = {x = cursor.x, y = cursor.y}}
	mp.set_property_native('pause', true)
	self:set_from_cursor()
end
function Timeline:on_prop_duration() self:decide_enabled() end
function Timeline:on_prop_time() self:decide_enabled() end
function Timeline:on_prop_border() self:update_dimensions() end
function Timeline:on_prop_title_bar() self:update_dimensions() end
function Timeline:on_prop_fullormaxed()
	self:decide_progress_size()
	self:update_dimensions()
end
function Timeline:on_display() self:update_dimensions() end
function Timeline:on_options()
	self:decide_progress_size()
	self:update_dimensions()
end
function Timeline:handle_cursor_up()
	if self.pressed then
		mp.set_property_native('pause', self.pressed.pause)
		self.pressed = false
	end
end
function Timeline:on_global_mouse_leave()
	self:update_marker(false)
	self.pressed = false
end

function Timeline:on_global_mouse_move()
	if self.pressed then
		self.pressed.distance = self.pressed.distance + get_point_to_point_proximity(self.pressed.last, cursor)
		self.pressed.last.x, self.pressed.last.y = cursor.x, cursor.y
		if state.is_video and math.abs(cursor:get_velocity().x) / self.width * state.duration > 30 then
			self:set_from_cursor(true)
		else
			self:set_from_cursor()
		end
	end
end

function Timeline:cursor_command(command)
	if type(command) == 'string' and #command > 0 and state.time and state.duration then
		local expanded_command = command:gsub("{time}", self:get_time_at_x(cursor.x))
		mp.command(expanded_command)
	end
end

-- A separate reversible animation: stopping it preserves the current value.
function Timeline:reset_marker()
	if self.marker_animation then self.marker_animation:kill(); self.marker_animation = nil end
	self.marker_visible, self.marker_reveal = false, 0
end

function Timeline:update_marker(show)
	show = not not show
	if show == self.marker_visible then return end
	if self.marker_animation then self.marker_animation:kill(); self.marker_animation = nil end
	self.marker_visible = show
	local from, target = self.marker_reveal or 0, show and 1 or 0
	local started = mp.get_time()
	local duration = show and 0.18 or 0.16
	self.marker_animation = mp.add_periodic_timer(math.max(state.render_delay, 1 / 120), function()
		local t = math.min((mp.get_time() - started) / duration, 1)
		local eased = 1 - (1 - t) ^ 3 -- cubic ease-out for both expansion and contraction
		self.marker_reveal = from + (target - from) * eased
		if t >= 1 then
			self.marker_animation:kill()
			self.marker_animation = nil
		end
		request_render()
	end)
end

function Timeline:render()
	self:update_time_gutters()
	if self.size == 0 then
		self:reset_marker()
		self:clear_thumbnail()
		return
	end

	local size = self:get_effective_size()
	local visibility = self:get_visibility()
	self.is_hovered = false

	if size < 1 then
		self:reset_marker()
		self:clear_thumbnail()
		return
	end

	if self.proximity_raw <= 0 then
		self.is_hovered = true
	end
	if visibility > 0 then
		cursor:zone('primary_down', self, function()
			self:handle_cursor_down()
			cursor:once('primary_up', function() self:handle_cursor_up() end)
		end)
		if #options.timeline_mbtn_right > 0 then
			cursor:zone('secondary_down', self, function()
				self:cursor_command(options.timeline_mbtn_right)
			end)
		end
		if config.timeline_step ~= 0 then
			cursor:zone('wheel_down', self, function()
				mp.commandv('seek', -config.timeline_step, config.timeline_step_flag)
			end)
			cursor:zone('wheel_up', self, function()
				mp.commandv('seek', config.timeline_step, config.timeline_step_flag)
			end)
		end
	end

	local ass = assdraw.ass_new()
	local progress_size = math.max(self.min_progress_size, self.progress_size)

	-- Text opacity rapidly drops to 0 just before it starts overflowing, or before it reaches progress_size
	local hide_text_below = math.max(self.font_size * 0.8, progress_size * 2)
	local hide_text_ramp = hide_text_below / 2
	local text_opacity = visibility

	local tooltip_gap = round(2 * state.scale)
	local timestamp_gap = tooltip_gap

	local spacing = math.max(math.floor((self.size - self.font_size) / 2.5), 4)
	local progress = state.time / state.duration
	local is_line = options.timeline_style == 'line'

	-- Foreground & Background bar coordinates
	local bottom = display.height - Elements:v('window_border', 'size', 0)
	local rail_bottom = bottom + (self.by - bottom) * visibility
	local bax, bay, bbx, bby = self.ax, rail_bottom - size, self.bx, rail_bottom
	local fax, fay, fbx, fby = 0, bay + self.top_border, 0, bby
	local fcy = fay + (size / 2)

	local line_width = 0

	if is_line then
		local minimized_fraction = 1 - math.min((size - progress_size) / ((self.size - progress_size) / 8), 1)
		local progress_delta = progress_size > 0 and self.progress_line_width - self.line_width or 0
		line_width = self.line_width + (progress_delta * minimized_fraction)
		fax = bax + (self.width - line_width) * progress
		fbx = fax + line_width
		line_width = line_width - 1
	else
		fax, fbx = bax, bax + self.width * progress
	end

	local foreground_size = fby - fay
	local foreground_coordinates = round(fax) .. ',' .. fay .. ',' .. round(fbx) .. ',' .. fby -- for clipping

	-- time starts 0.5 pixels in
	local time_ax = bax + 0.5
	local time_width = self.width - line_width - 1

	-- time to x: calculates x coordinate so that it never lies inside of the line
	local function t2x(time)
		local x = time_ax + time_width * time / state.duration
		return time <= state.time and x or x + line_width
	end

	-- One segmented rail: semantic hue, playback/cache brightness.
	local boundaries = {0, state.duration}
	for _, chapter in ipairs(state.chapters) do
		if chapter.time > 0 and chapter.time < state.duration then boundaries[#boundaries + 1] = chapter.time end
	end
	table.sort(boundaries)
	local rail_hovered = (self.is_hovered or self.pressed) and not Elements:v('speed', 'dragging')
	local hover_time = rail_hovered and self:get_time_at_x(cursor.x) or nil
	local gap = (1 + 2 * visibility) * state.scale
	for i = 1, #boundaries - 1 do
		local start, finish = boundaries[i], boundaries[i + 1]
		local left = t2x(start) + (i > 1 and gap / 2 or 0)
		local right = t2x(finish) - (i < #boundaries - 1 and gap / 2 or 0)
		local hovered = hover_time and hover_time >= start and (hover_time < finish or finish == state.duration)
		local growth = hovered and 1 * state.scale * visibility or 0
		local segment_top, segment_bottom = fay - growth, fby + growth
		if right > left then
			local cuts = {start, finish}
			local function cut(t) if t and t > start and t < finish then cuts[#cuts + 1] = t end end
			cut(state.time)
			for _, range in ipairs(state.chapter_ranges) do cut(range.start); cut(range['end']) end
			for _, range in ipairs(state.uncached_ranges or {}) do cut(range[1]); cut(range[2]) end
			table.sort(cuts)
			for j = 1, #cuts - 1 do
				local mid = (cuts[j] + cuts[j + 1]) / 2
				local played, cached = mid <= state.time, options.timeline_cache and state.uncached_ranges ~= nil
				for _, range in ipairs(state.uncached_ranges or {}) do
					if mid >= range[1] and mid < range[2] then cached = false; break end
				end
				local color = played and 'F7F3F1' or (cached and 'A6978E' or '70645E')
				local opacity = 0.45 + 0.55 * visibility
				for _, range in ipairs(state.chapter_ranges) do
					if mid >= range.start and mid < range['end'] then
						color = range.color
						opacity = opacity * (played and 1 or (cached and 0.65 or 0.3))
					end
				end
				local x1, x2 = math.max(left, t2x(cuts[j])), math.min(right, t2x(cuts[j + 1]))
				if x2 > x1 then
					ass:rect(left, segment_top, right, segment_bottom, {color = color, opacity = opacity, radius = (size + growth * 2) / 2,
						clip = string.format('\\clip(%f,%f,%f,%f)', x1, segment_top, x2, segment_bottom)})
				end
			end
		end
	end
	-- Hysteresis prevents a one-pixel boundary crossing from restarting the animation.
	local marker_hovered = rail_hovered or (self.marker_visible and not cursor.hidden
		and self.proximity_raw <= 3 * state.scale and not Elements:v('speed', 'dragging'))
	self:update_marker(marker_hovered and visibility > 0)
	local hovered_chapter = nil
	if visibility > 0 then
		local opts = {size = self.font_size, font = 'sans-serif', opacity = visibility, border = 0.6, color = bgt}
		ass:txt(self.time_margin, fcy, 4, state.time_human or '', opts)
		ass:txt(display.width - self.time_margin, fcy, 6, state.destination_time_human or '', opts)
		for _, marker in ipairs({{state.ab_loop_a, 'A'}, {state.ab_loop_b, 'B'}}) do
			if type(marker[1]) == 'number' then ass:txt(t2x(marker[1]), fay - 9 * state.scale, 5, marker[2], opts) end
		end
	end

	-- Hovered time and chapter
	local rendered_thumbnail = false
	if (self.proximity_raw <= 0 or self.pressed or hovered_chapter) and not Elements:v('speed', 'dragging') then
		local cursor_x = hovered_chapter and t2x(hovered_chapter.time) or cursor.x
		local hovered_seconds = hovered_chapter and hovered_chapter.time or self:get_time_at_x(cursor.x)

		-- Cursor line
		-- 0.5 to switch when the pixel is half filled in
		local color = ((fax - 0.5) < cursor_x and cursor_x < (fbx + 0.5)) and bg or fg
		local ax, ay, bx, by = cursor_x - 0.5, fay, cursor_x + 0.5, fby
		-- The play triangle is a transparent glyph cutout: do not show a cursor
		-- through it, even though the marker itself is painted last.
		if self.marker_reveal <= 0.01 or math.abs(cursor_x - t2x(state.time)) > 6 * state.scale then
			ass:rect(ax, ay, bx, by, {color = color, opacity = 0.33})
		end
		local tooltip_anchor = {ax = ax, ay = ay - self.top_border, bx = bx, by = by}

		-- Timestamp
		local opts = {
			size = self.tooltip_font_size, offset = timestamp_gap, margin = tooltip_gap, timestamp = options.time_precision > 0,
		}
		local hovered_time_human = format_time(hovered_seconds, state.duration)
		opts.width_overwrite = timestamp_width(hovered_time_human, opts)
		tooltip_anchor = ass:tooltip(tooltip_anchor, hovered_time_human, opts)

		-- Thumbnail
		if not thumbnail.disabled
			and (not self.pressed or self.pressed.distance < 5)
			and thumbnail.width ~= 0
			and thumbnail.height ~= 0
		then
			local border = math.ceil(math.max(2, state.radius / 2) * state.scale)
			local thumb_x_margin, thumb_y_margin = border + tooltip_gap + bax, border + tooltip_gap
			local thumb_width, thumb_height = thumbnail.width, thumbnail.height
			local thumb_x = round(clamp(
				thumb_x_margin,
				cursor_x - thumb_width / 2,
				display.width - thumb_width - thumb_x_margin
			))
			local thumb_y = round(tooltip_anchor.ay - thumb_y_margin - thumb_height)
			local ax, ay = (thumb_x - border), (thumb_y - border)
			local bx, by = (thumb_x + thumb_width + border), (thumb_y + thumb_height + border)
			ass:rect(ax, ay, bx, by, {
				color = bg,
				border = 1,
				opacity = {main = config.opacity.thumbnail, border = 0.08 * config.opacity.thumbnail},
				border_color = fg,
				radius = state.radius,
			})
			local thumb_seconds = (state.rebase_start_time == false and state.start_time) and
				(hovered_seconds - state.start_time) or hovered_seconds
			mp.commandv('script-message-to', 'thumbfast', 'thumb', thumb_seconds, thumb_x, thumb_y)
			self.has_thumbnail, rendered_thumbnail = true, true
			tooltip_anchor.ay = ay
		end

		-- Chapter title
		if config.opacity.chapters > 0 and #state.chapters > 0 then
			local _, chapter = itable_find(state.chapters, function(c) return hovered_seconds >= c.time end,
				#state.chapters, 1)
			if chapter and not chapter.is_end_only then
				ass:tooltip(tooltip_anchor, chapter.title_wrapped, {
					size = self.tooltip_font_size,
					offset = tooltip_gap,
					responsive = false,
					bold = true,
					width_overwrite = chapter.title_wrapped_width * self.tooltip_font_size,
					lines = chapter.title_lines,
					margin = tooltip_gap,
				})
			end
		end
	end

	-- Paint last: the hover cursor must never cut through the current-position glyph.
	-- Keep its font size fixed, animate the transform, and snap its center to pixels.
	if self.marker_reveal > 0.01 then
		local zoom = 100 * self.marker_reveal
		local marker_x, marker_y = round(t2x(state.time)), round(fcy)
		local inset = 3 * state.scale * self.marker_reveal
		-- Cupertino's play triangle is a hole, not dark ink. Mask the rail
		-- underneath it: its fractional progress split moves independently of
		-- the pixel-aligned glyph and otherwise flashes through that hole.
		ass:rect(marker_x - inset, marker_y - inset, marker_x + inset, marker_y + inset, {
			color = '202020', opacity = visibility * self.marker_reveal,
		})
		ass:icon(marker_x, marker_y, 12 * state.scale, 'play_rectangle_fill', {
			scale_x = zoom, scale_y = zoom,
			color = 'F7F3F1', border = 0.35, border_color = '202020',
			opacity = visibility * self.marker_reveal,
		})
	end

	-- Clear thumbnail
	if not rendered_thumbnail then self:clear_thumbnail() end

	return ass
end

return Timeline
