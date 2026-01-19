-- subjoyer.nvim - Main plugin module
local M = {}

local config = require('subjoyer.config')
local websocket = require('subjoyer.websocket')
local display = require('subjoyer.display')
local renderer = require('subjoyer.renderer')
local asbplayer = require('subjoyer.asbplayer')

-- Plugin state
M.is_started = false
M.asbplayer_started = false
M.current_subtitle = nil -- Store current subtitle for mining
M.subtitle_history = {} -- Store recent subtitles for context

-- Setup plugin with user configuration
function M.setup(user_config)
  -- Initialize configuration
  config.setup(user_config or {})
  local cfg = config.get()

  -- Setup incline display
  local ok = display.setup(cfg)
  if not ok then
    vim.notify('[subjoyer] Failed to setup incline.nvim integration', vim.log.levels.ERROR)
    return
  end

  -- Setup callbacks
  M.setup_callbacks()
  M.setup_asbplayer_callbacks()

  -- Setup autocommands
  M.setup_autocommands()

  -- Auto-start if configured (this will also start asbplayer if enabled)
  if cfg.behavior.auto_start then
    vim.defer_fn(function()
      M.start()
    end, 100)
  end
end

-- Setup WebSocket callbacks
function M.setup_callbacks()
  local cfg = config.get()

  -- Server ready (silent unless debug)
  websocket.on('ready', function(data)
    if cfg.behavior.debug then
      vim.notify(
        string.format('[subjoyer] Server ready on %s:%d', data.host, data.port),
        vim.log.levels.INFO
      )
    end
  end)

  -- Extension connected (silent unless debug)
  websocket.on('connected', function(data)
    if cfg.behavior.debug then
      vim.notify(
        string.format('[subjoyer] Extension connected (v%s)', data.version or 'unknown'),
        vim.log.levels.INFO
      )
    end
  end)

  -- Extension disconnected (silent - not an error)
  websocket.on('disconnected', function(_)
    -- Disconnection is normal, only log in debug mode
    if cfg.behavior.debug then
      vim.notify('[subjoyer] Extension disconnected', vim.log.levels.INFO)
    end
  end)

  -- Error occurred (only show critical errors)
  websocket.on('error', function(error_msg)
    -- Only show if debug mode (websocket.lua already filtered it)
    if cfg.behavior.debug then
      vim.notify('[subjoyer] Error: ' .. error_msg, vim.log.levels.ERROR)
    end
  end)

  -- Subtitle received (silent - just update display)
  websocket.on('subtitle', function(data)
    M.handle_subtitle(data)
  end)
end

-- Setup asbplayer callbacks
function M.setup_asbplayer_callbacks()
  local cfg = config.get()

  asbplayer.on('ready', function(data)
    if cfg.asbplayer and cfg.asbplayer.debug then
      vim.notify('[subjoyer:asbplayer] Server ready at ' .. (data.url or 'ws://127.0.0.1:8766/ws'), vim.log.levels.INFO)
    end
  end)

  asbplayer.on('connected', function(data)
    if cfg.asbplayer and cfg.asbplayer.debug then
      vim.notify('[subjoyer:asbplayer] asbplayer connected: ' .. (data.client or 'unknown'), vim.log.levels.INFO)
    end
  end)

  asbplayer.on('disconnected', function(_)
    if cfg.asbplayer and cfg.asbplayer.debug then
      vim.notify('[subjoyer:asbplayer] asbplayer disconnected', vim.log.levels.INFO)
    end
  end)

  asbplayer.on('error', function(error_msg)
    if cfg.asbplayer and cfg.asbplayer.debug then
      vim.notify('[subjoyer:asbplayer] Error: ' .. error_msg, vim.log.levels.ERROR)
    end
  end)

  asbplayer.on('response', function(response)
    if cfg.asbplayer and cfg.asbplayer.debug then
      vim.notify('[subjoyer:asbplayer] Response: ' .. vim.inspect(response), vim.log.levels.INFO)
    end
  end)
end

-- Setup autocommands
function M.setup_autocommands()
  local cfg = config.get()

  -- Create augroup
  local group = vim.api.nvim_create_augroup('Subjoyer', { clear = true })

  -- Hide on insert mode
  if cfg.behavior.hide_on_insert then
    vim.api.nvim_create_autocmd('InsertEnter', {
      group = group,
      callback = function()
        display.hide()
      end,
    })

    vim.api.nvim_create_autocmd('InsertLeave', {
      group = group,
      callback = function()
        if M.is_started then
          display.show(cfg)
        end
      end,
    })
  end

  -- Cleanup on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      M.stop()
    end,
  })
end

-- Handle subtitle data
function M.handle_subtitle(data)
  local cfg = config.get()

  -- Store current subtitle for mining
  M.current_subtitle = data

  -- Store in history for context (keep last 10)
  table.insert(M.subtitle_history, 1, data)
  if #M.subtitle_history > 10 then
    table.remove(M.subtitle_history)
  end

  -- Check if updates should be paused
  if cfg.video.pause_updates and data.video and data.video.paused then
    return
  end

  -- Render subtitle
  local formatted_lines = renderer.render(data, cfg)

  -- Update display
  display.update(formatted_lines, cfg)
end

-- Start receiving subtitles
function M.start()
  if M.is_started then
    return
  end

  local cfg = config.get()

  -- Start WebSocket server for subtitle reception
  websocket.start(cfg)

  -- Start asbplayer server if enabled
  if cfg.asbplayer and cfg.asbplayer.enabled then
    M.start_asbplayer()
  end

  -- Show display
  if cfg.display.enabled then
    display.show(cfg)
  end

  M.is_started = true
end

-- Stop receiving subtitles
function M.stop()
  if not M.is_started then
    return
  end

  -- Stop WebSocket server
  websocket.stop()

  -- Stop asbplayer server if running
  if M.asbplayer_started then
    M.stop_asbplayer()
  end

  -- Hide display
  display.hide()

  M.is_started = false
end

-- Toggle plugin on/off
function M.toggle()
  if M.is_started then
    M.stop()
  else
    M.start()
  end
end

-- Show display bar
function M.show()
  local cfg = config.get()
  display.show(cfg)
end

-- Hide display bar
function M.hide()
  display.hide()
end

-- Toggle display visibility
function M.toggle_display()
  local cfg = config.get()
  display.toggle(cfg)
end

-- Get connection status
function M.status()
  local ws_status = websocket.status()
  return {
    plugin_started = M.is_started,
    server_running = ws_status.is_running,
    display_visible = display.is_visible_func(),
    job_id = ws_status.job_id,
    reconnect_count = ws_status.reconnect_count,
  }
end

-- Print status (includes asbplayer if enabled)
function M.print_status()
  local status = M.status()
  local cfg = config.get()

  local lines = {
    'subjoyer.nvim Status:',
    '  Plugin: ' .. (status.plugin_started and 'Running' or 'Stopped'),
    '  Server: ' .. (status.server_running and 'Running' or 'Stopped'),
    '  Display: ' .. (status.display_visible and 'Visible' or 'Hidden'),
    '  Connection: ' .. cfg.connection.host .. ':' .. cfg.connection.port,
  }

  -- Add asbplayer status if enabled
  if cfg.asbplayer and cfg.asbplayer.enabled then
    local asp_status = M.asbplayer_status()
    table.insert(lines, '')
    table.insert(lines, 'asbplayer Integration:')
    table.insert(lines, '  Server: ' .. (asp_status.server_running and 'Running' or 'Stopped'))
    table.insert(lines, '  Client: ' .. (asp_status.client_connected and 'Connected' or 'Disconnected'))
    if asp_status.pending_requests > 0 then
      table.insert(lines, '  Pending: ' .. asp_status.pending_requests)
    end
  end

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

-- Reconnect
function M.reconnect()
  websocket.stop()
  vim.defer_fn(function()
    local cfg = config.get()
    websocket.start(cfg)
  end, 100)
end

-- Set track filter
function M.set_track(track)
  -- Parse track input
  local parsed_track
  if track == 'all' then
    parsed_track = 'all'
  elseif tonumber(track) then
    parsed_track = tonumber(track)
  else
    -- Try to parse as JSON array
    local ok, result = pcall(vim.json.decode, track)
    if ok and type(result) == 'table' then
      parsed_track = result
    else
      vim.notify('[subjoyer] Invalid track: ' .. track, vim.log.levels.ERROR)
      return
    end
  end

  -- Update config
  config.update({
    subtitle = {
      tracks = parsed_track,
    },
  })

  -- Refresh display
  display.refresh()

  vim.notify('[subjoyer] Track set to: ' .. vim.inspect(parsed_track), vim.log.levels.INFO)
end

-- Set position (vertical placement)
function M.set_position(position)
  local valid_positions = { 'top', 'bottom' }
  if not vim.tbl_contains(valid_positions, position) then
    vim.notify('[subjoyer] Invalid position: ' .. position .. ' (use: top, bottom)', vim.log.levels.ERROR)
    return
  end

  -- Update config
  config.update({
    incline = {
      options = {
        window = {
          placement = {
            vertical = position,
          },
        },
      },
    },
  })

  -- Need to reload incline for position change
  vim.notify('[subjoyer] Position set to: ' .. position .. ' (restart plugin for effect)', vim.log.levels.INFO)
end

-- Toggle debug mode
function M.toggle_debug()
  local cfg = config.get()
  local new_debug = not cfg.behavior.debug

  config.update({
    behavior = {
      debug = new_debug,
    },
  })

  vim.notify('[subjoyer] Debug: ' .. (new_debug and 'ON' or 'OFF'), vim.log.levels.INFO)
end

-- Start asbplayer WebSocket server
function M.start_asbplayer()
  if M.asbplayer_started then
    return
  end

  local cfg = config.get()

  if not cfg.asbplayer or not cfg.asbplayer.enabled then
    vim.notify('[subjoyer] asbplayer integration not enabled in config', vim.log.levels.WARN)
    return
  end

  -- Start asbplayer server
  asbplayer.start(cfg)
  M.asbplayer_started = true
end

-- Stop asbplayer WebSocket server
function M.stop_asbplayer()
  if not M.asbplayer_started then
    return
  end

  asbplayer.stop()
  M.asbplayer_started = false
end

-- Build Anki fields from subtitle data
local function build_anki_fields(subtitle_data, cfg)
  if not subtitle_data or not subtitle_data.subtitle then
    return nil
  end

  local fields = {}
  local template_fields = cfg.asbplayer.anki.fields or {}

  -- Get current subtitle text
  local text = subtitle_data.subtitle.text or ''

  -- Build context from history
  local context_before = cfg.asbplayer.anki.context_lines_before or 1
  local context_after = cfg.asbplayer.anki.context_lines_after or 1
  local context_lines = {}

  -- Add lines before (from history)
  for i = 2, math.min(context_before + 1, #M.subtitle_history) do
    local prev = M.subtitle_history[i]
    if prev and prev.subtitle and prev.subtitle.text then
      table.insert(context_lines, 1, prev.subtitle.text)
    end
  end

  -- Add current line
  table.insert(context_lines, '>> ' .. text .. ' <<')

  -- Note: context_after would require future subtitles (not available yet)

  local context = table.concat(context_lines, '\n')

  -- Process each field template
  for field_name, field_template in pairs(template_fields) do
    local value = field_template
    -- Replace template variables
    value = value:gsub('{text}', text)
    value = value:gsub('{context}', context)
    -- Add more template variables as needed
    fields[field_name] = value
  end

  return fields
end

-- Mine current subtitle to Anki
function M.mine_anki()
  local cfg = config.get()

  -- Check if asbplayer is enabled and running
  if not cfg.asbplayer or not cfg.asbplayer.enabled then
    vim.notify('[subjoyer] asbplayer integration not enabled', vim.log.levels.ERROR)
    return
  end

  if not M.asbplayer_started then
    vim.notify('[subjoyer] asbplayer server not running. Use :SubjoyerStartAsbplayer', vim.log.levels.ERROR)
    return
  end

  local status = asbplayer.status()
  if not status.is_connected then
    vim.notify('[subjoyer] asbplayer not connected. Enable WebSocket client in asbplayer extension settings.', vim.log.levels.ERROR)
    return
  end

  -- Check if we have a current subtitle
  if not M.current_subtitle then
    vim.notify('[subjoyer] No subtitle to mine', vim.log.levels.WARN)
    return
  end

  -- Build Anki fields
  local fields = build_anki_fields(M.current_subtitle, cfg)
  if not fields then
    vim.notify('[subjoyer] Failed to build Anki fields', vim.log.levels.ERROR)
    return
  end

  -- Get post-mine action
  local post_mine_action = cfg.asbplayer.anki.post_mine_action or 0

  -- Send mine-subtitle command
  vim.notify('[subjoyer] Mining to Anki...', vim.log.levels.INFO)
  asbplayer.mine_subtitle(fields, post_mine_action, function(response)
    if response.error then
      vim.notify('[subjoyer] Anki mining failed: ' .. response.error, vim.log.levels.ERROR)
    elseif response.body and response.body.published then
      vim.notify('[subjoyer] Anki note created successfully!', vim.log.levels.INFO)
    else
      vim.notify('[subjoyer] Anki note created (status unknown)', vim.log.levels.INFO)
    end
  end)
end

-- Get asbplayer status
function M.asbplayer_status()
  local status = asbplayer.status()
  return {
    server_started = M.asbplayer_started,
    server_running = status.is_running,
    client_connected = status.is_connected,
    pending_requests = status.pending_count,
  }
end

return M
