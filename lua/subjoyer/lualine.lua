local M = {}

local config_mod = require("subjoyer.config")
local display_mod = require("subjoyer.display")

local function get_effective_setting(provider_val, global_val)
    if provider_val ~= nil then
        return provider_val
    end
    return global_val
end

-- Build subtitle text
local function build_text(items, cfg)
    local parts = {}
    local show_timestamp = get_effective_setting(cfg.lualine.show_timestamp, cfg.subtitle.show_timestamp)
    local show_track_label = get_effective_setting(cfg.lualine.track_label, cfg.subtitle.track_label)

    for i, item in ipairs(items) do
        if i > 1 then
            table.insert(parts, cfg.lualine.separator or " • ")
        end

        if show_timestamp and item.timestamp then
            table.insert(parts, item.timestamp .. " ")
        end

        if show_track_label and item.track_label then
            table.insert(parts, item.track_label .. " ")
        end

        table.insert(parts, item.text)
    end

    return table.concat(parts)
end

-- Get subtitle text (returns string or nil)
function M.get_subtitle()
    local cfg = config_mod.get()

    local state = display_mod.get_state()
    if not state or not state.subtitle then
        return nil
    end

    local raw_lines = state.subtitle.lines or {}
    if #raw_lines == 0 and state.subtitle.text and state.subtitle.text ~= "" then
        raw_lines = { { text = state.subtitle.text, track = 0 } }
    end

    if #raw_lines == 0 then
        return nil
    end

    -- Build items with timestamp/track_label
    local items = {}
    for _, line in ipairs(raw_lines) do
        local track_num = line.track_num or line.track or 0
        local text = line.text or ""

        if cfg.subtitle.trim then
            text = text:gsub("^%s*(.-)%s*$", "%1")
        end

        local item = { text = text }

        local show_timestamp = get_effective_setting(cfg.lualine.show_timestamp, cfg.subtitle.show_timestamp)
        local show_track_label = get_effective_setting(cfg.lualine.track_label, cfg.subtitle.track_label)

        if show_timestamp and state.video and state.video.currentTime then
            local minutes = math.floor(state.video.currentTime / 60)
            local secs = math.floor(state.video.currentTime % 60)
            item.timestamp = string.format("[%02d:%02d]", minutes, secs)
        end

        if show_track_label then
            item.track_label = string.format("Track %d:", track_num)
        end

        table.insert(items, item)
    end

    if #items == 0 then
        return nil
    end

    local text = build_text(items, cfg)

    -- Truncate
    local max_len = cfg.lualine.max_length or 80
    if #text > max_len then
        text = text:sub(1, max_len - 3) .. "..."
    end

    -- Icon
    if cfg.lualine.show_icon and cfg.lualine.icon then
        text = cfg.lualine.icon .. " " .. text
    end

    return text
end

-- Lualine component factory
function M.component()
    return {
        function()
            return M.get_subtitle() or ""
        end,
        cond = function()
            local subjoyer = require("subjoyer")
            local state = display_mod.get_state()
            return subjoyer.is_started
                and state
                and state.subtitle
                and (state.subtitle.lines and #state.subtitle.lines > 0 or state.subtitle.text ~= "")
        end,
    }
end

return M
