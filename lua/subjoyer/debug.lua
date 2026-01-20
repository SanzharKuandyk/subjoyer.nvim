-- Debug utilities for subjoyer.nvim
local M = {}

-- Force verbose logging
function M.enable_verbose()
    local config = require("subjoyer.config")
    config.update({
        behavior = {
            debug = true,
        },
    })
    vim.notify("[subjoyer] Verbose debug enabled", vim.log.levels.INFO)
end

-- Test if incline is available
function M.test_incline()
    local ok, incline = pcall(require, "incline")
    if not ok then
        vim.notify("[subjoyer] ❌ incline.nvim NOT FOUND! Install it as dependency.", vim.log.levels.ERROR)
        return false
    end
    vim.notify("[subjoyer] ✅ incline.nvim is installed", vim.log.levels.INFO)
    return true
end

-- Test renderer
function M.test_renderer()
    local renderer = require("subjoyer.renderer")
    local config = require("subjoyer.config").get()

    local test_data = {
        subtitle = {
            text = "Test subtitle",
            lines = { { text = "Test subtitle", track = 0 } },
        },
        video = {
            currentTime = 60.5,
        },
    }

    local result = renderer.render(test_data, config)
    vim.notify("[subjoyer] Renderer test result:", vim.log.levels.INFO)
    print(vim.inspect(result))
    return result
end

-- Test display
function M.test_display()
    local display = require("subjoyer.display")
    local config = require("subjoyer.config").get()

    -- Create test subtitle
    local test_lines = {
        {
            text = "Test subtitle from debug",
            timestamp = "[01:00]",
            track_label = "Track 0:",
        },
    }

    display.update(test_lines, config)
    vim.notify("[subjoyer] Display updated with test subtitle", vim.log.levels.INFO)
    vim.notify('[subjoyer] Check if incline bar shows: "Test subtitle from debug"', vim.log.levels.INFO)
end

-- Full diagnostic
function M.diagnose()
    vim.notify("=== subjoyer.nvim Diagnostic ===", vim.log.levels.INFO)

    -- Check incline
    local has_incline = M.test_incline()
    if not has_incline then
        return
    end

    -- Check status
    local status = require("subjoyer").status()
    vim.notify(string.format("[subjoyer] Status: %s", vim.inspect(status)), vim.log.levels.INFO)

    -- Test renderer
    M.test_renderer()

    -- Test display
    vim.schedule(function()
        M.test_display()
    end)
end

return M
