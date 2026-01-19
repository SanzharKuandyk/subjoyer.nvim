-- Display module using incline.nvim
local M = {}

-- Current subtitle state
M.current_subtitle = nil
M.is_visible = true

-- Create render function for incline.nvim
function M.create_render(config)
  return function(props)
    local ok, result = pcall(function()
      -- Hide if not visible
      if not M.is_visible or not config.display.enabled then
        return nil
      end

      -- No subtitle yet
      if not M.current_subtitle then
        if config.subtitle.empty_placeholder ~= '' then
          return {
            { " ", guibg = config.colors.bg },
            { config.subtitle.empty_placeholder, guifg = config.colors.empty_fg, guibg = config.colors.bg },
            { " ", guibg = config.colors.bg },
          }
        end
        return nil
      end

      -- Build subtitle display parts
      local parts = {}
      local lines = M.current_subtitle.lines or {}

      -- Add padding
      table.insert(parts, { " ", guibg = config.colors.bg })

      -- Add prefix if configured
      if config.incline.prefix and config.incline.prefix ~= '' then
        table.insert(parts, {
          config.incline.prefix,
          guifg = config.colors.prefix_fg,
          guibg = config.colors.bg,
        })
      end

      -- Build subtitle text from lines
      local shown_lines = 0
      for i, line in ipairs(lines) do
        if shown_lines > 0 then
          -- Add separator between lines
          table.insert(parts, {
            config.incline.separator,
            guifg = config.colors.separator_fg,
            guibg = config.colors.bg,
          })
        end

        -- Get track number for color selection
        local track_num = line.track_num or 0

        -- Select colors based on track (with fallback to defaults)
        local track_fg_key = 'track_' .. track_num .. '_fg'
        local track_label_fg_key = 'track_' .. track_num .. '_label_fg'

        local subtitle_color = config.colors[track_fg_key] or config.colors.subtitle_fg
        local label_color = config.colors[track_label_fg_key] or config.colors.track_label_fg

        -- Timestamp (same for all tracks)
        if line.timestamp and config.incline.show_timestamp then
          table.insert(parts, {
            line.timestamp,
            guifg = config.colors.timestamp_fg,
            guibg = config.colors.bg,
          })
          table.insert(parts, { " ", guibg = config.colors.bg })
        end

        -- Track label (with track-specific color)
        if line.track_label and config.incline.show_track_label then
          table.insert(parts, {
            line.track_label,
            guifg = label_color,
            guibg = config.colors.bg,
          })
          table.insert(parts, { " ", guibg = config.colors.bg })
        end

        -- Subtitle text (with track-specific color)
        local text_part = {
          line.text,
          guifg = subtitle_color,
          guibg = config.colors.bg,
        }

        -- Apply text styling
        local styles = {}
        if config.incline.text_style.bold then
          table.insert(styles, "bold")
        end
        if config.incline.text_style.italic then
          table.insert(styles, "italic")
        end
        if config.incline.text_style.underline then
          table.insert(styles, "underline")
        end
        if #styles > 0 then
          text_part.gui = table.concat(styles, ",")
        end

        table.insert(parts, text_part)
        shown_lines = shown_lines + 1
      end

      -- Fallback if no lines shown
      if shown_lines == 0 and config.subtitle.empty_placeholder ~= '' then
        table.insert(parts, {
          config.subtitle.empty_placeholder,
          guifg = config.colors.empty_fg,
          guibg = config.colors.bg,
        })
      end

      -- Add suffix if configured
      if config.incline.suffix and config.incline.suffix ~= '' then
        table.insert(parts, {
          config.incline.suffix,
          guifg = config.colors.suffix_fg,
          guibg = config.colors.bg,
        })
      end

      -- Add padding
      table.insert(parts, { " ", guibg = config.colors.bg })

      return parts
    end)

    if not ok then
      -- Render failed, return error state
      return {
        { " ", guibg = config.colors.bg },
        { "Render Error", guifg = config.colors.error_fg, guibg = config.colors.bg },
        { " ", guibg = config.colors.bg },
      }
    end

    return result
  end
end

-- Update subtitle content
function M.update(formatted_lines, config)
  -- Store the formatted subtitle data
  M.current_subtitle = {
    lines = formatted_lines or {},
  }

  -- Refresh incline
  M.refresh()
end

-- Refresh incline display
function M.refresh()
  local ok, incline = pcall(require, 'incline')
  if ok and incline and incline.refresh then
    -- Schedule refresh to avoid issues during events
    vim.schedule(function()
      pcall(incline.refresh)
    end)
  end
end

-- Show subtitle bar
function M.show(config)
  M.is_visible = true
  M.refresh()
end

-- Hide subtitle bar
function M.hide()
  M.is_visible = false
  M.refresh()
end

-- Toggle visibility
function M.toggle(config)
  M.is_visible = not M.is_visible
  M.refresh()
end

-- Check if visible
function M.is_visible_func()
  return M.is_visible
end

-- Get current subtitle state (for lualine integration)
function M.get_state()
  return M.current_subtitle
end

-- Setup incline.nvim integration
function M.setup(config)
  local ok, incline = pcall(require, 'incline')
  if not ok then
    vim.notify(
      '[subjoyer] incline.nvim not found. Please install it: https://github.com/b0o/incline.nvim',
      vim.log.levels.ERROR
    )
    return false
  end

  -- Build incline config
  local incline_config = vim.tbl_deep_extend('force', config.incline.options, {
    render = M.create_render(config),
  })

  -- Setup incline
  incline.setup(incline_config)

  -- Setup autocommands to keep incline visible
  vim.api.nvim_create_autocmd(
    { 'CmdlineLeave', 'CmdlineEnter', 'WinEnter', 'BufEnter' },
    {
      callback = function()
        vim.defer_fn(function()
          if M.is_visible then
            M.refresh()
          end
        end, 50)
      end,
    }
  )

  -- Periodic refresh to keep window visible (every 5 seconds)
  vim.fn.timer_start(5000, function()
    if M.is_visible then
      M.refresh()
    end
  end, { ['repeat'] = -1 })

  return true
end

return M
