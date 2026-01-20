local M = {}

local display
local config_mod = require("subjoyer.config")

-- Setup
function M.setup()
    local ok = pcall(require, "lualine")
    if not ok then
        return false, "lualine.nvim not found"
    end

    display = require("subjoyer.display")
    return true
end

-- Build subtitle text (provider-agnostic)
local function build_text(lines, cfg)
    local parts = {}

    for i, line in ipairs(lines) do
        if i > 1 then
            table.insert(parts, cfg.lualine.separator or " • ")
        end

        if line.timestamp and cfg.lualine.show_timestamp then
            table.insert(parts, line.timestamp .. " ")
        end

        if line.track_label and cfg.lualine.show_track_label then
            table.insert(parts, line.track_label .. " ")
        end

        table.insert(parts, line.text)
    end

    return table.concat(parts)
end

-- Public: lualine component
function M.get_subtitle()
    if not display then
        display = require("subjoyer.display")
    end

    local state = display.get_state()
    if not state or not state.lines or #state.lines == 0 then
        return ""
    end

    local cfg = config_mod.get()
    local text = build_text(state.lines, cfg)

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
            return M.get_subtitle()
        end,
        cond = function()
            local subjoyer = require("subjoyer")
            local state = display and display.get_state() or nil
            return subjoyer.is_started and state and state.lines and #state.lines > 0
        end,
    }
end

-- Inject into existing lualine config
function M.inject_into_lualine(section)
    local ok, lualine = pcall(require, "lualine")
    if not ok then
        vim.notify("[subjoyer] lualine.nvim not found", vim.log.levels.ERROR)
        return false
    end

    local current = lualine.get_config()
    section = section or "c"

    current.sections = current.sections or {}
    local key = "lualine_" .. section
    current.sections[key] = current.sections[key] or {}

    table.insert(current.sections[key], M.component())

    lualine.setup(current)

    vim.notify("[subjoyer] Subtitle added to lualine section " .. section, vim.log.levels.INFO)

    return true
end

return M
