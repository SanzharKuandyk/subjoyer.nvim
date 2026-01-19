-- lualine integration for subjoyer.nvim
local M = {}

-- Get the renderer to access current subtitle state
local renderer = require('subjoyer.renderer')

-- Store reference to display module
local display = nil

-- Setup lualine component
function M.setup(config)
  -- Check if lualine is available
  local ok, lualine = pcall(require, 'lualine')
  if not ok then
    return false, 'lualine.nvim not found'
  end

  -- Get display module reference
  display = require('subjoyer.display')

  return true
end

-- Get current subtitle text for lualine
function M.get_subtitle()
  if not display then
    display = require('subjoyer.display')
  end

  -- Get current subtitle state from display module
  local subtitle_state = display.get_state()
  if not subtitle_state or not subtitle_state.lines or #subtitle_state.lines == 0 then
    return ''
  end

  local config = require('subjoyer.config').get()
  local lualine_cfg = config.lualine

  -- Build text from lines
  local text_parts = {}
  for _, line in ipairs(subtitle_state.lines) do
    if type(line) == 'table' then
      -- Extract text from highlight groups
      local line_text = ''
      for _, segment in ipairs(line) do
        if type(segment) == 'table' and segment[1] then
          line_text = line_text .. segment[1]
        elseif type(segment) == 'string' then
          line_text = line_text .. segment
        end
      end
      table.insert(text_parts, line_text)
    elseif type(line) == 'string' then
      table.insert(text_parts, line)
    end
  end

  local text = table.concat(text_parts, ' ')

  -- Truncate if too long
  local max_length = lualine_cfg.max_length or 80
  if #text > max_length then
    text = text:sub(1, max_length - 3) .. '...'
  end

  -- Add icon if configured
  if lualine_cfg.show_icon and lualine_cfg.icon then
    text = lualine_cfg.icon .. ' ' .. text
  end

  return text
end

-- Create lualine component function
function M.component()
  return {
    M.get_subtitle,
    cond = function()
      -- Only show if plugin is started and there's content
      local subjoyer = require('subjoyer')
      return subjoyer.is_started and M.get_subtitle() ~= ''
    end,
  }
end

-- Helper function to inject into lualine config
function M.inject_into_lualine(section)
  local ok, lualine_config = pcall(require, 'lualine')
  if not ok then
    vim.notify('[subjoyer] lualine.nvim not found', vim.log.levels.ERROR)
    return false
  end

  -- Get current lualine config
  local current_config = lualine_config.get_config()

  -- Determine section (default to 'c')
  section = section or 'c'
  local section_key = 'lualine_' .. section

  -- Initialize section if needed
  if not current_config.sections then
    current_config.sections = {}
  end
  if not current_config.sections[section_key] then
    current_config.sections[section_key] = {}
  end

  -- Add our component
  table.insert(current_config.sections[section_key], M.component())

  -- Update lualine
  lualine_config.setup(current_config)

  vim.notify('[subjoyer] Added to lualine section ' .. section, vim.log.levels.INFO)
  return true
end

return M
