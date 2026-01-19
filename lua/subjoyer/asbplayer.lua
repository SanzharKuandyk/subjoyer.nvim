-- asbplayer WebSocket server wrapper using Job API
local M = {}

local uv = vim.loop

-- State
M.job_id = nil
M.is_running = false
M.is_connected = false -- Track if asbplayer client is connected
M.message_counter = 0
M.pending_requests = {} -- Track pending requests by messageId

M.callbacks = {
  on_connected = nil,
  on_disconnected = nil,
  on_error = nil,
  on_ready = nil,
  on_response = nil,
}

-- Get script path
local function get_script_path()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local plugin_root = vim.fn.fnamemodify(source, ':h:h:h')
  return plugin_root .. '/scripts/ws_server_8766.py'
end

-- Log debug message
local function debug_log(msg, config)
  if config and config.asbplayer and config.asbplayer.debug then
    vim.notify('[subjoyer:asbplayer] ' .. msg, vim.log.levels.INFO)
  end
end

-- Show error
local function show_error(msg, config)
  if config and config.asbplayer and config.asbplayer.debug then
    vim.notify('[subjoyer:asbplayer] ' .. msg, vim.log.levels.ERROR)
  end
end

-- Generate unique message ID
local function generate_message_id()
  M.message_counter = M.message_counter + 1
  return 'nvim-' .. M.message_counter .. '-' .. vim.loop.now()
end

-- Parse JSON line
local function parse_json(line)
  local ok, data = pcall(vim.json.decode, line)
  if ok then
    return data
  else
    return nil, 'JSON parse error'
  end
end

-- Handle message from Python script
local function handle_message(data, config)
  if not data or not data.type then
    return
  end

  debug_log('Received: ' .. data.type, config)

  if data.type == 'asbplayer_server_ready' then
    M.is_running = true
    debug_log('Server ready at ' .. (data.url or 'ws://127.0.0.1:8766/ws'), config)
    if M.callbacks.on_ready then
      M.callbacks.on_ready(data)
    end

  elseif data.type == 'asbplayer_server_error' then
    M.is_running = false
    show_error(data.error or 'Unknown error', config)
    if M.callbacks.on_error then
      M.callbacks.on_error(data.error or 'Unknown error')
    end

  elseif data.type == 'asbplayer_connected' then
    M.is_connected = true
    debug_log('asbplayer client connected: ' .. (data.client or 'unknown'), config)
    if M.callbacks.on_connected then
      M.callbacks.on_connected(data)
    end

  elseif data.type == 'asbplayer_disconnected' then
    M.is_connected = false
    debug_log('asbplayer client disconnected', config)
    if M.callbacks.on_disconnected then
      M.callbacks.on_disconnected(data)
    end

  elseif data.type == 'asbplayer_response' then
    -- Handle response from asbplayer
    local response = data.data
    if response and response.messageId then
      local pending = M.pending_requests[response.messageId]
      if pending then
        -- Call callback with response
        if pending.callback then
          pending.callback(response)
        end
        -- Remove from pending
        M.pending_requests[response.messageId] = nil
      end
    end

    -- Also trigger general response callback
    if M.callbacks.on_response then
      M.callbacks.on_response(response)
    end

  elseif data.type == 'asbplayer_server_shutdown' then
    M.is_running = false
    M.is_connected = false
    debug_log('Server shutdown: ' .. (data.reason or 'unknown'), config)
  end
end

-- Send command to asbplayer via stdin
local function send_command(command, callback)
  if not M.job_id then
    if callback then
      callback({ error = 'Server not running' })
    end
    return nil
  end

  if not M.is_connected then
    if callback then
      callback({ error = 'asbplayer not connected' })
    end
    return nil
  end

  -- Generate message ID
  local message_id = generate_message_id()
  command.messageId = message_id

  -- Store pending request
  if callback then
    M.pending_requests[message_id] = {
      command = command.command,
      callback = callback,
      timestamp = vim.loop.now()
    }

    -- Timeout after 10 seconds
    vim.defer_fn(function()
      if M.pending_requests[message_id] then
        M.pending_requests[message_id] = nil
        callback({ error = 'Request timeout' })
      end
    end, 10000)
  end

  -- Send to Python process via stdin
  local json = vim.json.encode(command)
  local success = vim.fn.chansend(M.job_id, json .. '\n')

  if success == 0 then
    vim.notify('[subjoyer:asbplayer] ERROR: Failed to send command via stdin (chansend returned 0)', vim.log.levels.ERROR)
    if callback then
      M.pending_requests[message_id] = nil
      callback({ error = 'Failed to send command' })
    end
    return nil
  end

  vim.notify('[subjoyer:asbplayer] DEBUG: Sent command: ' .. json, vim.log.levels.INFO)

  return message_id
end

-- Start WebSocket server
function M.start(config)
  if M.is_running then
    debug_log('Already running', config)
    return
  end

  local script_path = get_script_path()

  -- Check if script exists
  if vim.fn.filereadable(script_path) ~= 1 then
    show_error('Python script not found: ' .. script_path, config)
    if M.callbacks.on_error then
      M.callbacks.on_error('Python script not found: ' .. script_path)
    end
    return
  end

  -- Check if python is available
  if vim.fn.executable('python3') ~= 1 and vim.fn.executable('python') ~= 1 then
    show_error('Python not found. Please install Python 3.7+', config)
    if M.callbacks.on_error then
      M.callbacks.on_error('Python not found. Please install Python 3.7+')
    end
    return
  end

  local python_cmd = vim.fn.executable('python3') == 1 and 'python3' or 'python'

  -- Build command
  local cmd = {
    python_cmd,
    script_path,
    '--host', config.asbplayer.host,
    '--port', tostring(config.asbplayer.port),
  }

  debug_log('Starting: ' .. table.concat(cmd, ' '), config)

  -- Start job
  M.job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line and line ~= '' then
          local parsed, err = parse_json(line)
          if parsed then
            handle_message(parsed, config)
          elseif config.asbplayer and config.asbplayer.debug then
            debug_log('Parse error: ' .. (err or 'unknown'), config)
          end
        end
      end
    end,

    on_stderr = function(_, data, _)
      -- Collect stderr output but only show in debug mode
      for _, line in ipairs(data) do
        if line and line ~= '' then
          debug_log('stderr: ' .. line, config)
        end
      end
    end,

    on_exit = function(_, exit_code, _)
      M.is_running = false
      M.is_connected = false
      M.job_id = nil
      debug_log('Server exited with code: ' .. exit_code, config)
    end,

    -- Enable stdin for sending commands
    stdin = 'pipe',
  })

  if M.job_id <= 0 then
    M.job_id = nil
    M.is_running = false
    show_error('Failed to start asbplayer server job', config)
    if M.callbacks.on_error then
      M.callbacks.on_error('Failed to start job')
    end
  end
end

-- Stop WebSocket server
function M.stop()
  if M.job_id then
    vim.fn.jobstop(M.job_id)
    M.job_id = nil
  end

  M.is_running = false
  M.is_connected = false
  M.pending_requests = {}
end

-- Mine subtitle (create Anki note)
function M.mine_subtitle(fields, post_mine_action, callback)
  local command = {
    command = 'mine-subtitle',
    body = {
      fields = fields,
      postMineAction = post_mine_action or 0, -- 0=continue, 1=pause, 2=rewind
    }
  }

  return send_command(command, callback)
end

-- Load subtitles
function M.load_subtitles(files, callback)
  local command = {
    command = 'load-subtitles',
    body = {
      files = files,
    }
  }

  return send_command(command, callback)
end

-- Seek to timestamp
function M.seek_timestamp(timestamp_ms, callback)
  local command = {
    command = 'seek-timestamp',
    body = {
      timestamp = timestamp_ms,
    }
  }

  return send_command(command, callback)
end

-- Set callbacks
function M.on(event, callback)
  if event == 'connected' then
    M.callbacks.on_connected = callback
  elseif event == 'disconnected' then
    M.callbacks.on_disconnected = callback
  elseif event == 'error' then
    M.callbacks.on_error = callback
  elseif event == 'ready' then
    M.callbacks.on_ready = callback
  elseif event == 'response' then
    M.callbacks.on_response = callback
  end
end

-- Get status
function M.status()
  return {
    is_running = M.is_running,
    is_connected = M.is_connected,
    job_id = M.job_id,
    pending_count = vim.tbl_count(M.pending_requests),
  }
end

return M
