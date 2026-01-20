-- Display module using provider from config
local M = {}

M.current_subtitle = nil
M.is_visible = true
M.nui_popup = nil

function M.build_model(config)
    if not M.is_visible or not config.display.enabled then
        return nil
    end

    local subtitle = M.current_subtitle
    if not subtitle or not subtitle.lines or #subtitle.lines == 0 then
        if config.subtitle.empty_placeholder ~= "" then
            return {
                {
                    text = config.subtitle.empty_placeholder,
                    track_num = 0,
                },
            }
        end
        return nil
    end

    local items = {}
    for _, line in ipairs(subtitle.lines) do
        table.insert(items, {
            timestamp = line.timestamp,
            track_label = line.track_label,
            text = line.text,
            track_num = line.track_num or 0,
        })
    end

    return items
end

function M.format_subtitle(config, model)
    if not model then
        return nil
    end

    local parts = {}

    if config.nui.subtitle.prefix ~= "" then
        table.insert(parts, config.nui.subtitle.prefix)
    end

    for i, item in ipairs(model) do
        if i > 1 then
            table.insert(parts, config.nui.subtitle.separator)
        end

        if item.timestamp and config.subtitle.show_timestamp then
            table.insert(parts, item.timestamp)
        end

        if item.track_label and config.subtitle.track_label then
            table.insert(parts, "Track " .. item.track_num .. ":")
        end

        table.insert(parts, item.text)
    end

    if config.nui.subtitle.suffix ~= "" then
        table.insert(parts, config.nui.subtitle.suffix)
    end

    return parts
end

function M.get_position(config)
    local row
    if config.nui.window.placement.vertical == "top" then
        row = config.nui.window.margin.vertical
    else
        row = vim.o.lines - vim.o.cmdheight - config.nui.window.height - config.nui.window.margin.vertical
    end
    return row
end

function M.calculate_size(config)
    local width
    if type(config.nui.window.width) == "number" then
        width = config.nui.window.width
    elseif type(config.nui.window.width) == "string" and config.nui.window.width:match("%%") then
        local pct = tonumber(config.nui.window.width:gsub("%%", "")) or 80
        width = math.floor(vim.o.columns * pct / 100)
    else
        width = math.floor(vim.o.columns * 0.8)
    end

    local col
    if config.nui.window.placement.horizontal == "left" then
        col = config.nui.window.margin.horizontal
    elseif config.nui.window.placement.horizontal == "right" then
        col = vim.o.columns - width - config.nui.window.margin.horizontal
    else
        col = math.floor((vim.o.columns - width) / 2)
    end

    return width, col
end

function M.create_nui_popup(config)
    local Popup = require("nui.popup")

    vim.cmd("hi SubjoyerNormal guifg=#cdd6f4 guibg=#1e1e2e")

    local position = M.get_position(config)
    local width, col = M.calculate_size(config)

    M.nui_popup = Popup({
        enter = false,
        focusable = false,
        relative = "editor",
        position = {
            row = position,
            col = col,
        },
        size = {
            width = width,
            height = config.nui.window.height,
        },
        border = "none",
        zindex = config.nui.window.zindex,
        win_options = {
            wrap = true,
            winhighlight = "Normal:SubjoyerNormal",
        },
    })

    M.nui_popup:mount()
end

function M.update_nui_popup(config)
    if not M.nui_popup or not M.nui_popup.bufnr then
        return
    end

    local model = M.build_model(config)
    local parts = M.format_subtitle(config, model)

    if not parts or not M.is_visible or #parts == 0 then
        M.nui_popup:hide()
        return
    end

    local text = table.concat(parts, " ")

    vim.api.nvim_buf_set_lines(M.nui_popup.bufnr, 0, -1, false, { text })
    M.nui_popup:show()
end

-- Incline renderer
function M.render_incline(config)
    return function()
        local model = M.build_model(config)
        if not model then
            return nil
        end

        local parts = {}

        -- Left padding
        table.insert(parts, { " ", guibg = config.colors.bg })

        -- Prefix
        if config.incline.prefix ~= "" then
            table.insert(parts, {
                config.incline.prefix,
                guifg = config.colors.prefix_fg,
                guibg = config.colors.bg,
            })
        end

        for i, item in ipairs(model) do
            if i > 1 then
                table.insert(parts, {
                    config.incline.separator,
                    guifg = config.colors.separator_fg,
                    guibg = config.colors.bg,
                })
            end

            -- Timestamp
            if item.timestamp and config.incline.show_timestamp then
                table.insert(parts, {
                    item.timestamp .. " ",
                    guifg = config.colors.timestamp_fg,
                    guibg = config.colors.bg,
                })
            end

            -- Track label
            if item.track_label and config.incline.show_track_label then
                local label_fg = config.colors["track_" .. item.track_num .. "_label_fg"]
                    or config.colors.track_label_fg

                table.insert(parts, {
                    item.track_label .. " ",
                    guifg = label_fg,
                    guibg = config.colors.bg,
                })
            end

            -- Subtitle text
            local subtitle_fg = config.colors["track_" .. item.track_num .. "_fg"] or config.colors.subtitle_fg

            local text_part = {
                item.text,
                guifg = subtitle_fg,
                guibg = config.colors.bg,
            }

            local styles = {}
            for style, enabled in pairs(config.incline.text_style) do
                if enabled then
                    table.insert(styles, style)
                end
            end
            if #styles > 0 then
                text_part.gui = table.concat(styles, ",")
            end

            table.insert(parts, text_part)
        end

        -- Right padding
        table.insert(parts, { " ", guibg = config.colors.bg })

        return parts
    end
end

function M.update(formatted_lines, config)
    M.current_subtitle = { lines = formatted_lines or {} }

    if config.display.provider.incline then
        M.refresh()
    end

    if config.display.provider.nui then
        M.update_nui_popup(config)
    end
end

function M.refresh()
    local ok, incline = pcall(require, "incline")
    if ok and incline and incline.refresh then
        vim.schedule(function()
            pcall(incline.refresh)
        end)
    end
end

function M.show()
    M.is_visible = true

    if M.nui_popup then
        M.update_nui_popup(require("subjoyer.config").get())
    end

    M.refresh()
end

function M.hide(config)
    M.is_visible = false
    config = config or require("subjoyer.config").get()

    if M.nui_popup then
        M.nui_popup:hide()
    end

    M.refresh()
end

function M.toggle(config)
    M.is_visible = not M.is_visible
    config = config or require("subjoyer.config").get()

    if not M.is_visible and M.nui_popup then
        M.nui_popup:hide()
    elseif M.is_visible and M.nui_popup then
        M.update_nui_popup(config)
    end

    M.refresh()
end

function M.get_state()
    return M.current_subtitle
end

function M.setup(config)
    -- Incline setup
    if config.display.provider.incline then
        local ok, incline = pcall(require, "incline")
        if not ok then
            vim.notify("[subjoyer] incline.nvim not found", vim.log.levels.ERROR)
            return false
        end

        incline.setup(vim.tbl_deep_extend("force", config.incline.options, {
            render = M.render_incline(config),
        }))
    end

    -- NUI setup
    if config.display.provider.nui then
        local ok, _ = pcall(require, "nui.popup")
        if not ok then
            vim.notify("[subjoyer] nui.popup not found", vim.log.levels.ERROR)
            return false
        end

        M.create_nui_popup(config)
        M.update_nui_popup(config)
    end

    -- Keep display refreshed on UI changes
    vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "CmdlineLeave", "VimResized" }, {
        callback = function()
            if M.is_visible then
                M.refresh()
            end
        end,
    })

    return true
end

return M
