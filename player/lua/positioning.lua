--[[
This file is part of mpv.

mpv is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

mpv is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with mpv.  If not, see <http://www.gnu.org/licenses/>.
]]

local options = {
    toggle_align_to_cursor = false,
    suppress_osd = false,
    -- [mpv-for-aoe] cursor-centric-zoom keeps video-zoom inside this range,
    -- so the wheel never shrinks the video below the window fit.
    zoom_min = 0,
    zoom_max = 6,
    -- [mpv-for-aoe] animate cursor-centric-zoom instead of jumping a whole
    -- wheel step at once. The zoom follows the wheel like a critically damped
    -- spring: it starts and stops softly and keeps its speed when more wheel
    -- steps arrive. zoom_smoothness is roughly the settle time in seconds.
    smooth_zoom = true,
    zoom_smoothness = 0.25,
    -- [mpv-for-aoe] camera-* bindings: window heights per second while held.
    camera_speed = 1.0,
    -- [mpv-for-aoe] while zooming or panning, downscale with plain bilinear
    -- and sync to the display, restoring the configured dscale and
    -- video-sync once the view stops; redrawing a 9216 px frame with hermite
    -- costs ~14 ms on an integrated GPU vs ~1 ms.
    fast_scaling_in_motion = true,
}

require "mp.options".read_options(options, nil, function () end)

local function clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

mp.add_key_binding(nil, "pan-x", function (t)
    if t.arg == nil or t.arg == "" then
        mp.osd_message("Usage: script-binding positioning/pan-x <amount>")
        return
    end

    if t.event == "up" then
        return
    end

    local dims = mp.get_property_native("osd-dimensions")
    local width = dims.w - dims.ml - dims.mr
    -- 1 video-align shifts the OSD by (width - osd-width) / 2 pixels, so the
    -- equation to find how much video-align to add to offset the OSD by
    -- osd-width is:
    -- x/1 = osd-width / ((width - osd-width) / 2)
    local amount = t.arg * t.scale * 2 * dims.w / (width - dims.w)
    mp.commandv("add", "video-align-x", clamp(amount, -2, 2))
end, { complex = true, scalable = true })

mp.add_key_binding(nil, "pan-y", function (t)
    if t.arg == nil or t.arg == "" then
        mp.osd_message("Usage: script-binding positioning/pan-y <amount>")
        return
    end

    if t.event == "up" then
        return
    end

    local dims = mp.get_property_native("osd-dimensions")
    local height = dims.h - dims.mt - dims.mb
    local amount = t.arg * t.scale * 2 * dims.h / (height - dims.h)
    mp.commandv("add", "video-align-y", clamp(amount, -2, 2))
end, { complex = true, scalable = true })

-- [mpv-for-aoe] The view (zoom and alignment) is kept in the script and sent
-- asynchronously. Getting and setting properties synchronously makes every
-- step wait for the core, and while a 9216 px video plays the core is busy
-- with the other scripts reacting to each change: animations got only a few
-- steps per second. So the values are observed, steps are computed locally,
-- and while a send is in flight newer steps only replace what is sent next.
local view = { zoom = 0, ax = 0, ay = 0, pan_x = 0, pan_y = 0 }
local dims, params
local mouse = { x = 0, y = 0 }
local in_flight = 0
local queued = false

for property, key in pairs({ ["video-zoom"] = "zoom", ["video-align-x"] = "ax",
                             ["video-align-y"] = "ay", ["video-pan-x"] = "pan_x",
                             ["video-pan-y"] = "pan_y" }) do
    mp.observe_property(property, "number", function (_, value)
        -- while our own sends are pending, these are their echoes
        if value and in_flight == 0 and not queued then
            view[key] = value
        end
    end)
end
mp.observe_property("osd-dimensions", "native", function (_, value) dims = value end)
local paused = false
mp.observe_property("pause", "bool", function (_, value) paused = value end)
mp.observe_property("video-params", "native", function (_, value) params = value end)
mp.observe_property("mouse-pos", "native", function (_, value)
    if value then
        mouse = value
    end
end)

local function send_view()
    in_flight = 3
    local function done()
        in_flight = in_flight - 1
        if in_flight == 0 and queued then
            queued = false
            send_view()
        end
    end
    mp.command_native_async({ "no-osd", "set", "video-zoom", tostring(view.zoom) }, done)
    mp.command_native_async({ "no-osd", "set", "video-align-x", tostring(view.ax) }, done)
    mp.command_native_async({ "no-osd", "set", "video-align-y", tostring(view.ay) }, done)
end

local function set_view(zoom, ax, ay)
    view.zoom, view.ax, view.ay = zoom, ax, ay
    if in_flight > 0 then
        queued = true
    else
        send_view()
    end
end

-- [mpv-for-aoe] Cheap downscaling while the view moves. Every zoom/pan step
-- re-renders the whole frame, so the configured dscale is swapped for
-- bilinear on the first step and restored after the view rests.
local saved_scaling
-- Restoring hermite compiles a shader for the current zoom (~100 ms), which
-- stalled a zoom started right then; waiting 0.8 s keeps back-to-back
-- moves on the fast path.
local restore_scaling_timer = mp.add_timeout(0.8, function ()
    if saved_scaling then
        mp.command_native_async({ "no-osd", "set", "dscale", saved_scaling.dscale }, function () end)
        mp.command_native_async({ "no-osd", "set", "correct-downscaling", saved_scaling.correct }, function () end)
        if saved_scaling.video_sync then
            mp.command_native_async({ "no-osd", "set", "video-sync", saved_scaling.video_sync }, function () end)
        end
        saved_scaling = nil
    end
end)
restore_scaling_timer:kill()

-- The first switch to bilinear compiles its shaders, which stalled the first
-- zoom of a session by ~100 ms; do that once while the video starts instead.
local prewarm_scaling
mp.register_event("file-loaded", function ()
    if not options.fast_scaling_in_motion or saved_scaling or prewarm_scaling then
        return
    end
    prewarm_scaling = {
        dscale = mp.get_property("dscale"),
        correct = mp.get_property("correct-downscaling"),
    }
    mp.command_native_async({ "no-osd", "set", "dscale", "bilinear" }, function () end)
    mp.command_native_async({ "no-osd", "set", "correct-downscaling", "no" }, function () end)
    mp.add_timeout(0.2, function ()
        -- a motion that started meanwhile restores these when it ends
        if not saved_scaling then
            mp.command_native_async({ "no-osd", "set", "dscale", prewarm_scaling.dscale }, function () end)
            mp.command_native_async({ "no-osd", "set", "correct-downscaling", prewarm_scaling.correct }, function () end)
        end
        prewarm_scaling = nil
    end)
end)

local function view_moving()
    if not options.fast_scaling_in_motion then
        return
    end
    if not saved_scaling then
        saved_scaling = prewarm_scaling or {
            dscale = mp.get_property("dscale"),
            correct = mp.get_property("correct-downscaling"),
        }
        mp.command_native_async({ "no-osd", "set", "dscale", "bilinear" }, function () end)
        mp.command_native_async({ "no-osd", "set", "correct-downscaling", "no" }, function () end)
    end
    -- Switching video-sync stalls the VO for ~140 ms, and while paused every
    -- redraw is immediate anyway, so only do it during playback.
    if not saved_scaling.video_sync and not paused then
        saved_scaling.video_sync = mp.get_property("video-sync")
        -- While playing, the VO draws the next video frame ahead and sleeps
        -- until it is due, so view changes only show at the video frame rate
        -- (25 fps). Syncing to the display renders every vsync instead; it is
        -- only used while the view moves because a VO that cannot keep up
        -- slows playback down in this mode instead of dropping frames.
        mp.command_native_async({ "no-osd", "set", "video-sync", "display-resample" }, function () end)
    end
    restore_scaling_timer:kill()
    restore_scaling_timer:resume()
end

-- [mpv-for-aoe] Video placement computed the way video/out/aspect.c does it,
-- rather than read back from osd-dimensions margins, which only update after
-- the VO renders and lag behind animation steps.
local function placement(zoom)
    if not dims or not params or not params.dw or dims.w <= 0 then
        return nil
    end
    local fit = math.min(dims.w / params.dw, dims.h / params.dh)
    return {
        w = dims.w, h = dims.h,
        vw = params.dw * fit * 2^zoom, vh = params.dh * fit * 2^zoom,
        video_w = params.w,
    }
end

-- Left/top margin of the video for an alignment, and back.
local function margin(size, video_size, align, pan)
    return (size - video_size) * (align + 1) / 2 + pan * video_size
end

local function align_for(size, video_size, m, pan)
    -- When the video exactly fills an axis, alignment has no effect on it and
    -- the division is by 0, so center it instead.
    if math.abs(size - video_size) < 0.5 then
        return 0
    end
    return clamp(2 * (m - pan * video_size) / (size - video_size) - 1, -1, 1)
end

-- Drag: the point grabbed stays under the cursor. Applied from a timer on the
-- observed mouse position rather than per MOUSE_MOVE event, so a burst of
-- mouse events costs one step per frame.
local drag
local drag_timer = mp.add_periodic_timer(1 / 120, function ()
    local p = placement(view.zoom)
    if not drag or not p or (mouse.x == drag.last_x and mouse.y == drag.last_y) then
        return
    end
    drag.last_x, drag.last_y = mouse.x, mouse.y
    view_moving()
    set_view(view.zoom,
             align_for(p.w, p.vw, drag.ml + mouse.x - drag.x, view.pan_x),
             align_for(p.h, p.vh, drag.mt + mouse.y - drag.y, view.pan_y))
end)
drag_timer:kill()

mp.add_key_binding(nil, "drag-to-pan", function (t)
    if t.event == "up" then
        drag = nil
        drag_timer:kill()
        return
    end
    local p = placement(view.zoom)
    if drag or not p then
        return
    end
    mouse = mp.get_property_native("mouse-pos") or mouse
    drag = {
        x = mouse.x, y = mouse.y, last_x = mouse.x, last_y = mouse.y,
        ml = margin(p.w, p.vw, view.ax, view.pan_x),
        mt = margin(p.h, p.vh, view.ay, view.pan_y),
    }
    drag_timer:resume()
end, { complex = true })


local align_to_cursor_bound = false

local function align_to_cursor(_, mouse_pos)
    local dims = mp.get_property_native("osd-dimensions")
    local align = (mouse_pos.x * 2 - dims.w) / dims.w
    mp.set_property("video-align-x", clamp(align, -1, 1))
    align = (mouse_pos.y * 2 - dims.h) / dims.h
    mp.set_property("video-align-y", clamp(align, -1, 1))
end

mp.add_key_binding(nil, "align-to-cursor", function (t)
    if options.toggle_align_to_cursor == false then
        if t.event == "down" then
            mp.observe_property("mouse-pos", "native", align_to_cursor)
        else
            mp.unobserve_property(align_to_cursor)
        end

        return
    end

    if t.event ~= "up" then
        return
    end

    if align_to_cursor_bound then
        mp.unobserve_property(align_to_cursor)
    else
        mp.observe_property("mouse-pos", "native", align_to_cursor)
    end
    align_to_cursor_bound = not align_to_cursor_bound
end, { complex = true })


-- [mpv-for-aoe] Zoom by amount (log2) keeping the point under x, y still.
local function zoom_around(amount, x, y)
    local before = placement(view.zoom)
    local after = placement(view.zoom + amount)
    if not before then
        return
    end
    local ml = (margin(before.w, before.vw, view.ax, view.pan_x) - x) * 2^amount + x
    local mt = (margin(before.h, before.vh, view.ay, view.pan_y) - y) * 2^amount + y
    set_view(view.zoom + amount,
             align_for(after.w, after.vw, ml, view.pan_x),
             align_for(after.h, after.vh, mt, view.pan_y))
    if not options.suppress_osd and after.video_w then
        local text = string.format("Zoom %d%%", math.floor(after.vw / after.video_w * 100 + 0.5))
        mp.command_native_async({ "show-text", text, "1000" }, function () end)
    end
end

-- Animated zoom: the wheel moves the target and the zoom follows it like a
-- critically damped spring around the latest cursor position.
local zoom_target, zoom_x, zoom_y, zoom_last_tick
local zoom_velocity = 0
local zoom_timer
zoom_timer = mp.add_periodic_timer(1 / 120, function ()
    local now = mp.get_time()
    -- a stalled frame must not turn into one big jump
    local dt = math.min(math.max(now - zoom_last_tick, 0.001), 1 / 30)
    zoom_last_tick = now
    local omega = 4.5 / options.zoom_smoothness
    local diff = zoom_target - view.zoom
    zoom_velocity = zoom_velocity + (omega * omega * diff - 2 * omega * zoom_velocity) * dt
    local step = zoom_velocity * dt
    if math.abs(diff - step) < 0.001 and math.abs(zoom_velocity) < 0.05 then
        step = diff
        zoom_timer:kill()
        zoom_target = nil
        zoom_velocity = 0
    end
    view_moving()
    zoom_around(step, zoom_x, zoom_y)
end)
zoom_timer:kill()

mp.add_key_binding(nil, "cursor-centric-zoom", function (t)
    if t.arg == nil or t.arg == "" then
        mp.osd_message("Usage: script-binding positioning/cursor-centric-zoom <amount>")
        return
    end

    -- read now rather than from the observer, which may not have caught up
    mouse = mp.get_property_native("mouse-pos") or mouse
    local x, y = mouse.x, mouse.y
    local touch_positions = mp.get_property_native("touch-pos")
    if touch_positions[1] then
        x, y = 0, 0
        for _, position in pairs(touch_positions) do
            x = x + position.x
            y = y + position.y
        end
        x = x / #touch_positions
        y = y / #touch_positions
    end

    local from = zoom_target or view.zoom
    local target = clamp(from + t.arg * t.scale, options.zoom_min, options.zoom_max)
    if target == from then
        return
    end

    if not options.smooth_zoom then
        view_moving()
        zoom_around(target - view.zoom, x, y)
        return
    end

    zoom_target, zoom_x, zoom_y = target, x, y
    if not zoom_timer:is_enabled() then
        zoom_last_tick = mp.get_time() - 1 / 120
        zoom_timer:resume()
    end
end, { complex = true, scalable = true })

-- [mpv-for-aoe] Move the view like a game camera while a key is held:
-- script-binding positioning/camera-left (also -right, -up, -down).
local camera_held = {}
-- a short tap still moves the view for this long
local camera_hold_until = {}
local camera_last_tick, camera_start
local camera_timer
camera_timer = mp.add_periodic_timer(1 / 120, function ()
    local now = mp.get_time()
    local dt = math.min(math.max(now - camera_last_tick, 0.001), 1 / 30)
    camera_last_tick = now
    local function held(direction)
        return (camera_held[direction] or (camera_hold_until[direction] or 0) > now) and 1 or 0
    end
    local dx = held("right") - held("left")
    local dy = held("down") - held("up")
    if dx == 0 and dy == 0 then
        camera_timer:kill()
        return
    end
    local p = placement(view.zoom)
    if not p then
        return
    end
    -- ease in over 0.15 s so a tap moves a little and a hold glides
    local speed = options.camera_speed * math.min(1, (now - camera_start) / 0.15 + 0.2)
    local distance = speed * math.min(p.w, p.h) * dt
    view_moving()
    set_view(view.zoom,
             align_for(p.w, p.vw, margin(p.w, p.vw, view.ax, view.pan_x) - dx * distance, view.pan_x),
             align_for(p.h, p.vh, margin(p.h, p.vh, view.ay, view.pan_y) - dy * distance, view.pan_y))
end)
camera_timer:kill()

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    mp.add_key_binding(nil, "camera-" .. direction, function (t)
        if t.event == "up" then
            camera_held[direction] = nil
            return
        end
        if t.event == "repeat" then
            return
        end
        -- "down" holds until "up"; a synthetic "press" is just a tap
        camera_held[direction] = t.event == "down" or nil
        camera_hold_until[direction] = mp.get_time() + 0.1
        if not camera_timer:is_enabled() then
            camera_start = mp.get_time()
            camera_last_tick = camera_start - 1 / 120
            camera_timer:resume()
        end
    end, { complex = true })
end

-- [mpv-for-aoe] Back to the whole video, stopping any zoom animation first so
-- it does not pull the view back to its old target.
mp.add_key_binding(nil, "reset-view", function ()
    zoom_timer:kill()
    zoom_target = nil
    zoom_velocity = 0
    mp.command_native_async({ "no-osd", "set", "panscan", "0" }, function () end)
    mp.command_native_async({ "no-osd", "set", "video-pan-x", "0" }, function () end)
    mp.command_native_async({ "no-osd", "set", "video-pan-y", "0" }, function () end)
    set_view(0, 0, 0)
    mp.command_native_async({ "show-text", "Zoom 0", "1000" }, function () end)
end)
