-- WebSocket client wrapper using Job API
local M = {}

local uv = vim.loop

-- State
M.job_id = nil
M.is_running = false
M.reconnect_count = 0
M.reconnect_timer = nil
M.last_error = nil
M.last_error_time = 0
M.error_shown = false -- Track if we've shown connection error

M.callbacks = {
    on_subtitle = nil,
    on_connected = nil,
    on_disconnected = nil,
    on_error = nil,
    on_ready = nil,
}

-- Get script path
local function get_script_path()
    local source = debug.getinfo(1, "S").source:sub(2)
    local plugin_root = vim.fn.fnamemodify(source, ":h:h:h")
    return plugin_root .. "/scripts/ws_client.py"
end

-- Log debug message
local function debug_log(msg)
    local config = require("subjoyer.config").get()
    if config.behavior and config.behavior.debug then
        vim.notify("[subjoyer] " .. msg, vim.log.levels.INFO)
    end
end

-- Show error with deduplication (prevent spam)
local function show_error(msg, force)
    local config = require("subjoyer.config").get()
    -- Deduplicate: don't show same error within 5 seconds
    local now = vim.loop.now()
    if M.last_error == msg and (now - M.last_error_time) < 5000 and not force then
        return
    end

    M.last_error = msg
    M.last_error_time = now

    -- Only show if debug mode OR it's a critical error
    if config.behavior.debug or force then
        vim.notify("[subjoyer] " .. msg, vim.log.levels.ERROR)
    end
end

-- Parse JSON line
local function parse_json(line)
    local ok, data = pcall(vim.json.decode, line)
    if ok then
        return data
    else
        return nil, "JSON parse error"
    end
end

-- Handle message from Python script
local function handle_message(data)
    if not data or not data.type then
        return
    end

    debug_log("Received: " .. data.type)

    if data.type == "server_ready" then
        M.is_running = true
        M.reconnect_count = 0
        M.error_shown = false -- Reset error flag on success
        if M.callbacks.on_ready then
            M.callbacks.on_ready(data)
        end
    elseif data.type == "server_error" then
        M.is_running = false

        -- Only show error once (not on every reconnect)
        if not M.error_shown then
            if M.callbacks.on_error then
                M.callbacks.on_error(data.error or "Unknown error")
            end
            M.error_shown = true
        end
    elseif data.type == "connected" then
        M.error_shown = false -- Reset on successful connection
        if M.callbacks.on_connected then
            M.callbacks.on_connected(data)
        end
    elseif data.type == "disconnected" or data.type == "client_disconnected" then
        -- Only log disconnect in debug mode (not an error)
        debug_log("Client disconnected")
        if M.callbacks.on_disconnected then
            M.callbacks.on_disconnected(data)
        end
    elseif data.type == "subtitle" then
        if M.callbacks.on_subtitle then
            M.callbacks.on_subtitle(data)
        end
    elseif data.type == "heartbeat" then
        -- Silently ignore heartbeats (unless debug)
        debug_log("Heartbeat received")
    end
end

-- Start WebSocket server
function M.start(config)
    if M.is_running then
        debug_log("Already running")
        return
    end

    local script_path = get_script_path()

    -- Check if script exists
    if vim.fn.filereadable(script_path) ~= 1 then
        if M.callbacks.on_error then
            M.callbacks.on_error("Python script not found: " .. script_path)
        end
        return
    end

    -- Check if python3 is available
    if vim.fn.executable("python3") ~= 1 and vim.fn.executable("python") ~= 1 then
        if M.callbacks.on_error then
            M.callbacks.on_error("Python not found. Please install Python 3.7+")
        end
        return
    end

    local python_cmd = vim.fn.executable("python3") == 1 and "python3" or "python"

    -- Build command
    local cmd = {
        python_cmd,
        script_path,
        "--host",
        config.connection.host,
        "--port",
        tostring(config.connection.port),
    }

    debug_log("Starting: " .. table.concat(cmd, " "))

    -- Start job
    M.job_id = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
            for _, line in ipairs(data) do
                if line and line ~= "" then
                    local parsed, err = parse_json(line)
                    if parsed then
                        handle_message(parsed)
                    else
                        -- Only show parse errors in debug mode
                        debug_log("Parse error: " .. err)
                    end
                end
            end
        end,

        on_stderr = function(_, data, _)
            -- Collect stderr output but only show in debug mode
            for _, line in ipairs(data) do
                if line and line ~= "" then
                    debug_log("stderr: " .. line)
                end
            end
        end,

        on_exit = function(_, exit_code, _)
            M.is_running = false
            M.job_id = nil

            -- Only log exit in debug mode (reconnect will handle it silently)
            debug_log("Server exited with code: " .. exit_code)

            -- Handle reconnection silently
            if config.connection.reconnect and exit_code ~= 0 then
                M.schedule_reconnect(config)
            end
        end,
    })

    if M.job_id <= 0 then
        M.job_id = nil
        M.is_running = false

        -- Show this error (critical - job failed to start)
        show_error("Failed to start WebSocket server job", true)

        if M.callbacks.on_error then
            M.callbacks.on_error("Failed to start job")
        end
    end
end

-- Stop WebSocket server
function M.stop()
    -- Cancel reconnect timer
    if M.reconnect_timer then
        M.reconnect_timer:stop()
        M.reconnect_timer:close()
        M.reconnect_timer = nil
    end

    -- Stop job
    if M.job_id then
        vim.fn.jobstop(M.job_id)
        M.job_id = nil
    end

    M.is_running = false
    M.reconnect_count = 0
    M.error_shown = false
end

-- Schedule reconnection
function M.schedule_reconnect(config)
    if M.reconnect_timer then
        return -- Already scheduled
    end

    local max_reconnects = config.connection.max_reconnects

    -- Check if we've exceeded max attempts
    if max_reconnects > 0 and M.reconnect_count >= max_reconnects then
        -- Only show this message once
        if not M.error_shown then
            debug_log(
                string.format(
                    "Max reconnection attempts (%d) reached. Use :SubjoyerReconnect to retry.",
                    max_reconnects
                )
            )
            M.error_shown = true
        end
        return
    end

    M.reconnect_count = M.reconnect_count + 1
    local delay = config.connection.reconnect_delay

    -- Only log reconnect attempts in debug mode
    debug_log(
        string.format(
            "Reconnecting in %dms (attempt %d/%d)",
            delay,
            M.reconnect_count,
            max_reconnects > 0 and max_reconnects or "∞"
        )
    )

    -- Create timer
    M.reconnect_timer = uv.new_timer()
    M.reconnect_timer:start(delay, 0, function()
        M.reconnect_timer:stop()
        M.reconnect_timer:close()
        M.reconnect_timer = nil

        -- Restart
        vim.schedule(function()
            M.start(config)
        end)
    end)
end

-- Set callbacks
function M.on(event, callback)
    if event == "subtitle" then
        M.callbacks.on_subtitle = callback
    elseif event == "connected" then
        M.callbacks.on_connected = callback
    elseif event == "disconnected" then
        M.callbacks.on_disconnected = callback
    elseif event == "error" then
        M.callbacks.on_error = callback
    elseif event == "ready" then
        M.callbacks.on_ready = callback
    end
end

-- Get status
function M.status()
    return {
        is_running = M.is_running,
        job_id = M.job_id,
        reconnect_count = M.reconnect_count,
    }
end

return M
