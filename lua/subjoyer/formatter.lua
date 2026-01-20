local M = {}

-- Helpers
local function format_timestamp(seconds, format)
    if not seconds then
        return nil
    end

    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)

    format = format:gsub("%%M", string.format("%02d", minutes))
    format = format:gsub("%%S", string.format("%02d", secs))

    return format
end

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function normalize_track(line)
    return line.track_num or line.track or 0
end

-- Track filtering
local function filter_tracks(lines, track_config)
    if not lines then
        return {}
    end

    -- all tracks
    if track_config == "all" then
        return lines
    end

    -- single track
    if type(track_config) == "number" then
        local out = {}
        for _, line in ipairs(lines) do
            if normalize_track(line) == track_config then
                table.insert(out, line)
            end
        end
        return out
    end

    -- multiple tracks
    if type(track_config) == "table" then
        local out = {}
        for _, line in ipairs(lines) do
            if vim.tbl_contains(track_config, normalize_track(line)) then
                table.insert(out, line)
            end
        end
        return out
    end

    -- fallback
    return lines
end

-- Main formatter (provider-agnostic)
function M.format(data, config)
    if not data or not data.subtitle then
        return {}
    end

    local subtitle = data.subtitle
    local video = data.video or {}

    local raw_lines = subtitle.lines or {}

    -- Fallback to legacy subtitle.text
    if #raw_lines == 0 and subtitle.text and subtitle.text ~= "" then
        raw_lines = {
            { text = subtitle.text, track = 0 },
        }
    end

    -- Filter tracks
    local filtered = filter_tracks(raw_lines, config.subtitle.tracks)
    if #filtered == 0 then
        return {}
    end

    local result = {}

    for _, line in ipairs(filtered) do
        local text = line.text or ""

        if config.subtitle.trim then
            text = trim(text)
        end

        if text ~= "" then
            if config.incline.max_text_length and #text > config.incline.max_text_length then
                text = text:sub(1, config.incline.max_text_length) .. "..."
            end

            local track_num = normalize_track(line)

            local item = {
                text = text,
                track_num = track_num,
            }

            if config.incline.show_timestamp and video.currentTime then
                item.timestamp = format_timestamp(video.currentTime, config.subtitle.timestamp_format)
            end

            if config.incline.show_track_label then
                item.track_label = string.format("Track %d:", track_num)
            end

            table.insert(result, item)
        end
    end

    return result
end

return M
