-- subsync.lua
-- Auto-sync subtitles using ffsubsync (audio fingerprinting)
-- Press 'n' to sync current subtitle track to video audio

local options = {
    -- Path to ffsubsync executable
    ffsubsync_path = "ffsubsync",

    -- Max seconds of video to analyze (0 = full video)
    max_duration = 600,

    -- Show OSD messages
    osd = true,

    -- OSD message duration in seconds
    osd_duration = 3,

    -- Auto-sync on file load (disabled by default)
    auto_sync = false,

    -- Temp directory for downloaded subtitles
    temp_dir = "/tmp/stremio-subs",
}

mp.options = require "mp.options"
mp.options.read_options(options, "subsync")

local utils = require "mp.utils"
local syncing = false
local was_playing = false

-- Show OSD message
local function show_osd(text, duration)
    duration = duration or options.osd_duration
    mp.msg.info("[OSD] " .. text)
    -- Try both methods
    mp.osd_message(text, duration)
    mp.command_native({"show-text", text, duration * 1000})
end

-- Get current subtitle info
local function get_subtitle_info()
    local sub_path = mp.get_property("current-tracks/sub/external-filename")
    if sub_path and sub_path ~= "" then
        local is_url = sub_path:match("^https?://") ~= nil
        return {path = sub_path, is_url = is_url}
    end

    -- Try to find subtitle file next to video
    local video_path = mp.get_property("path")
    if not video_path then return nil end

    local base = video_path:match("(.+)%..+$")
    if not base then return nil end

    local extensions = {".srt", ".ass", ".ssa", ".vtt"}
    for _, ext in ipairs(extensions) do
        local path = base .. ext
        local f = io.open(path, "r")
        if f then
            f:close()
            return {path = path, is_url = false}
        end
    end

    return nil
end

-- Get video reference (URL or local path)
local function get_video_ref()
    local path = mp.get_property("stream-open-filename")
    if path and path ~= "" then
        return path
    end
    return mp.get_property("path")
end

-- Generate unique temp filename for subtitle
local function make_temp_sub_path()
    return options.temp_dir .. "/subsync_" .. os.time() .. ".srt"
end

-- Run ffsubsync
local function run_ffsubsync(video_ref, sub_path, is_url)
    show_osd("Syncing subtitles...", 0)

    local args = {
        options.ffsubsync_path,
        video_ref,
        "-i", sub_path,
        "--overwrite-input",
    }

    if options.max_duration > 0 then
        table.insert(args, "--max-duration-seconds")
        table.insert(args, tostring(options.max_duration))
    end

    -- For remote URLs, extract audio first for stability
    if video_ref:match("^https?://") then
        table.insert(args, "--extract-audio-first")
    end

    mp.msg.info("[DEBUG] Running ffsubsync: " .. table.concat(args, " "))

    mp.command_native_async({
        name = "subprocess",
        args = args,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
    }, function(success, result)
        syncing = false
        local status = result and result.status
        local stderr = result and result.stderr or ""
        local stdout = result and result.stdout or ""

        mp.msg.info("[DEBUG] ffsubsync callback: success=" .. tostring(success) .. " status=" .. tostring(status))
        if stdout ~= "" then mp.msg.info("[DEBUG] stdout: " .. stdout:sub(1, 200)) end
        if stderr ~= "" then mp.msg.info("[DEBUG] stderr: " .. stderr:sub(1, 200)) end

        if success and status == 0 then
            show_osd("Subtitles synced!", 3)
            if is_url then
                mp.commandv("sub-add", sub_path)
            else
                mp.commandv("sub-reload")
            end
        else
            mp.msg.error("Sync failed: " .. stderr)
            show_osd("Sync failed:\n" .. stderr:sub(1, 80), 5)
        end

        -- Resume video if it was playing before
        if was_playing then
            mp.set_property_bool("pause", false)
        end
    end)
end

-- Ensure temp directory exists
local function ensure_temp_dir()
    local dir = options.temp_dir
    if dir and dir ~= "" then
        mp.command_native({
            name = "subprocess",
            args = {"mkdir", "-p", dir},
            playback_only = false,
            capture_stdout = true,
            capture_stderr = true,
        })
    end
end

-- Download subtitle then sync
local function download_and_sync(video_ref, url)
    show_osd("Downloading subtitle...", 0)

    ensure_temp_dir()

    local output_path = make_temp_sub_path()

    mp.msg.info("[DEBUG] Starting download to: " .. output_path)

    mp.command_native_async({
        name = "subprocess",
        args = {"curl", "-sL", "-o", output_path, url},
        playback_only = false,
    }, function(success, result)
        mp.msg.info("[DEBUG] download callback fired: success=" .. tostring(success) .. " status=" .. tostring(result and result.status))

        if not success or not result or result.status ~= 0 then
            syncing = false
            show_osd("Failed to download subtitle", 3)
            -- Resume video on failure
            if was_playing then
                mp.set_property_bool("pause", false)
            end
            return
        end

        -- Verify file exists
        local f = io.open(output_path, "r")
        if not f then
            syncing = false
            show_osd("Failed to download subtitle", 3)
            -- Resume video on failure
            if was_playing then
                mp.set_property_bool("pause", false)
            end
            return
        end
        f:close()

        mp.msg.info("[DEBUG] Download complete, starting sync...")
        run_ffsubsync(video_ref, output_path, true)
    end)
end

-- Main sync function
local function sync_subtitles()
    mp.msg.info("[DEBUG] sync_subtitles called")

    if syncing then
        show_osd("Sync already in progress...", 2)
        return
    end

    local video_ref = get_video_ref()
    mp.msg.info("[DEBUG] video_ref: " .. tostring(video_ref))

    if not video_ref then
        show_osd("No video loaded", 2)
        return
    end

    local sub_info = get_subtitle_info()
    mp.msg.info("[DEBUG] sub_info: " .. (sub_info and sub_info.path or "nil") .. " is_url: " .. tostring(sub_info and sub_info.is_url))

    if not sub_info then
        show_osd("No subtitle found", 2)
        return
    end

    -- Pause video during sync
    was_playing = not mp.get_property_bool("pause")
    if was_playing then
        mp.set_property_bool("pause", true)
    end

    syncing = true

    if sub_info.is_url then
        mp.msg.info("[DEBUG] URL subtitle detected, downloading...")
        download_and_sync(video_ref, sub_info.path)
    else
        mp.msg.info("[DEBUG] Local subtitle detected, syncing directly...")
        run_ffsubsync(video_ref, sub_info.path, false)
    end
end

-- Register keybinding
mp.add_key_binding("n", "subsync", sync_subtitles)

-- Optional: auto-sync on file load
if options.auto_sync then
    mp.register_event("file-loaded", function()
        mp.add_timeout(2, sync_subtitles)
    end)
end

mp.msg.info("subsync.lua loaded (press 'n' to sync)")
