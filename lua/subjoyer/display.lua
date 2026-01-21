-- Display module using provider from config
local M = {}

M.current_subtitle = nil
M.is_visible = true
M.nui_popup = nil

local function build_model_from_data(data, config)
    if not data or not data.subtitle then
        return nil
    end

    local subtitle = data.subtitle
    local items = {}

    local raw_lines = subtitle.lines or {}
    if #raw_lines == 0 and subtitle.text and subtitle.text ~= "" then
        raw_lines = { { text = subtitle.text, track = 0 } }
    end

    if #raw_lines == 0 then
        return nil
    end

    for _, line in ipairs(raw_lines) do
        local track_num = line.track_num or line.track or 0
        local text = line.text or ""

        if config.subtitle.trim then
            text = text:gsub("^%s*(.-)%s*$", "%1")
        end

        if text ~= "" then
            table.insert(items, {
                text = text,
                track_num = track_num,
            })
        end
    end

    if #items == 0 then
        return nil
    end

    return items
end

function M.format_nui(data, config)
    local model = build_model_from_data(data, config)
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
        table.insert(parts, item.text)
    end

    if config.nui.subtitle.suffix ~= "" then
        table.insert(parts, config.nui.subtitle.suffix)
    end

    return table.concat(parts, " ")
end

function M.format_incline(data, config)
    local model = build_model_from_data(data, config)
    if not model then
        return nil
    end

    local parts = {}

    for i, item in ipairs(model) do
        if i > 1 then
            table.insert(parts, config.incline.separator)
        end

        local text = item.text
        if config.incline.max_text_length and #text > config.incline.max_text_length then
            text = text:sub(1, config.incline.max_text_length) .. "..."
        end
        table.insert(parts, text)
    end

    return parts
end

function M.get_position(config, height)
    local row
    local win_height = height or config.nui.window.height
    if config.nui.window.placement.vertical == "top" then
        row = config.nui.window.margin.vertical
    else
        row = vim.o.lines - vim.o.cmdheight - win_height - config.nui.window.margin.vertical
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

local function calculate_wrapped_lines(text, window_width)
    if not text or #text == 0 then
        return 1
    end
    local text_width = vim.api.nvim_strwidth(text)
    local available_width = math.max(window_width - 2, 1)
    return math.ceil(text_width / available_width)
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

    local text = M.format_nui(M.current_subtitle, config)

    if not text or not M.is_visible or #text == 0 then
        M.nui_popup:hide()
        return
    end

    vim.api.nvim_buf_set_lines(M.nui_popup.bufnr, 0, -1, false, { text })
    M.nui_popup:show()

    local resize_opts = {}

    if config.nui.window.auto_resize then
        local width, _ = M.calculate_size(config)
        local wrapped_lines = calculate_wrapped_lines(text, width)
        local height = math.min(math.max(wrapped_lines, config.nui.window.min_height), config.nui.window.max_height)

        resize_opts.height = height

        if config.nui.window.placement.vertical == "bottom" then
            local new_row = vim.o.lines - vim.o.cmdheight - height - config.nui.window.margin.vertical
            resize_opts.row = new_row
        end
    end

    if next(resize_opts) ~= nil then
        local _, col = M.calculate_size(config)
        local full_opts = {
            relative = "editor",
            col = col,
            height = resize_opts.height,
            row = resize_opts.row,
        }
        local ok, err = pcall(vim.api.nvim_win_set_config, M.nui_popup.winid, full_opts)
        if not ok then
            vim.notify("[subjoyer] Failed to resize window: " .. err, vim.log.levels.WARN)
        end
    end
end

-- Incline renderer
function M.render_incline(config)
    return function()
        local parts = M.format_incline(M.current_subtitle, config)
        if not parts then
            return nil
        end

        local result = {}

        table.insert(result, { " ", guibg = config.colors.bg })

        if config.incline.prefix ~= "" then
            table.insert(result, {
                config.incline.prefix,
                guifg = config.colors.prefix_fg,
                guibg = config.colors.bg,
            })
        end

        for i, text in ipairs(parts) do
            if i > 1 then
                table.insert(result, {
                    config.incline.separator,
                    guifg = config.colors.separator_fg,
                    guibg = config.colors.bg,
                })
            end

            table.insert(result, {
                text,
                guifg = config.colors.subtitle_fg,
                guibg = config.colors.bg,
            })
        end

        table.insert(result, { " ", guibg = config.colors.bg })

        return result
    end
end

function M.update(data, config)
    M.current_subtitle = data

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
