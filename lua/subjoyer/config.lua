-- Configuration management for subjoyer.nvim
local M = {}

-- Default configuration
M.defaults = {
    -- Connection settings
    connection = {
        host = "localhost",
        port = 8767,
        reconnect = true,
        reconnect_delay = 3000, -- ms
        max_reconnects = 3, -- 0 = unlimited
    },

    -- Display settings
    display = {
        enabled = true,
        provider = { nui = true, incline = false }, -- display providers
        position = "bottom", -- in case couple providers enabled can override this inside provider's own config
    },

    -- Subtitle filtering and formatting
    subtitle = {
        -- Track selection
        -- Tracks are just numbers (0, 1, 2...) - no inherent meaning
        tracks = 0, -- 0, 'all', or array {0, 1, 2}
        max_lines = 5,

        -- Formatting
        show_timestamp = true,
        timestamp_format = "[%M:%S]", -- MM:SS format
        separator = "\n", -- separator between multiple tracks
        track_label = true, -- show "Track 0:", "Track 1:", etc.

        -- Text processing
        trim = true,
        empty_placeholder = "",
    },

    -- Colors (for incline.nvim display)
    colors = {
        bg = "#1e1e2e",

        -- Default colors (fallback)
        subtitle_fg = "#cdd6f4",
        timestamp_fg = "#89b4fa",
        track_label_fg = "#f9e2af",
        separator_fg = "#585b70",
        prefix_fg = "#a6e3a1",
        suffix_fg = "#585b70",
        empty_fg = "#6c7086",
        error_fg = "#f38ba8",

        -- Track-specific colors (override default subtitle_fg and track_label_fg per track)
        -- Track 0: Blue/Lavender theme
        track_0_fg = "#89dceb", -- Catppuccin Sky
        track_0_label_fg = "#89b4fa", -- Catppuccin Blue

        -- Track 1: Green theme
        track_1_fg = "#a6e3a1", -- Catppuccin Green
        track_1_label_fg = "#94e2d5", -- Catppuccin Teal

        -- Track 2: Pink/Mauve theme
        track_2_fg = "#f5c2e7", -- Catppuccin Pink
        track_2_label_fg = "#cba6f7", -- Catppuccin Mauve

        -- Track 3: Yellow theme
        track_3_fg = "#f9e2af", -- Catppuccin Yellow
        track_3_label_fg = "#fab387", -- Catppuccin Peach

        -- Track 4+: Falls back to default subtitle_fg/track_label_fg
    },

    -- nui.nvim integration
    nui = {
        -- Subtitle bar configuration
        subtitle = {
            prefix = "📺 ",
            suffix = "",
            separator = " • ",
            max_text_length = nil, -- nil = no truncation, text will wrap

            text_style = {
                bold = false,
                italic = false,
                underline = false,
            },
        },

        -- Window options
        window = {
            placement = {
                horizontal = "center", -- "left" | "center" | "right"
                vertical = "bottom", -- "top" | "bottom"
            },
            width = 80, -- width in columns or percentage (e.g., 80 or "80%")
            height = 2, -- height in lines
            margin = { horizontal = 0, vertical = 1 },
            padding = { left = 2, right = 2 },
            zindex = 100,
        },

        -- nui Popup options
        popup = {
            enter = false,
            focusable = false,
            relative = "editor",
            border = "none",
            win_options = {
                wrap = true,
                winhighlight = "Normal:SubjoyerNormal,FloatBorder:SubjoyerBorder",
            },
        },
    },

    -- Incline.nvim integration
    incline = {
        -- Display options
        prefix = "📺 ",
        suffix = "",
        separator = " • ",
        show_timestamp = true,
        show_track_label = true,
        max_text_length = nil, -- nil = no truncation, text will wrap

        -- Text styling
        text_style = {
            bold = false,
            italic = false,
            underline = false,
        },

        -- Incline.nvim window options
        options = {
            window = {
                placement = {
                    horizontal = "center",
                    vertical = "bottom", -- 'top' = above statusline, 'bottom' = below statusline
                },
                margin = { horizontal = 0, vertical = 1 },
                padding = { left = 2, right = 2 },
                zindex = 50,
            },
            ignore = {
                buftypes = {},
                filetypes = {},
                wintypes = "special",
            },
        },
    },

    -- Behavior
    behavior = {
        auto_start = false,
        hide_on_insert = false,
        follow_focus = true,
        debug = false,
    },

    -- Video context
    video = {
        show_url = false,
        show_time = false,
        pause_updates = false,
    },

    -- asbplayer integration
    asbplayer = {
        enabled = false, -- Enable asbplayer WebSocket server
        host = "127.0.0.1",
        port = 8766,
        debug = false,

        -- Anki note creation
        anki = {
            fields = {
                ["Sentence"] = "{text}", -- Current subtitle text
                ["Context"] = "{context}", -- Surrounding lines
                ["Source"] = "subjoyer", -- Source name
            },
            post_mine_action = 0, -- 0=continue, 1=pause, 2=rewind
            context_lines_before = 1, -- Number of lines before for context
            context_lines_after = 1, -- Number of lines after for context
        },
    },

    -- lualine integration (alternative to incline.nvim)
    lualine = {
        enabled = false, -- Enable lualine component
        section = "c", -- Which section to use (a, b, c, x, y, z)
        format = "{text}", -- Format string
        max_length = 80, -- Max text length
        show_icon = true, -- Show icon prefix
        icon = "📺", -- Icon to use
    },
}

-- Current active configuration
M.config = vim.deepcopy(M.defaults)

-- Deep merge tables
local function deep_merge(base, override)
    local result = vim.deepcopy(base)

    for key, value in pairs(override) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = deep_merge(result[key], value)
        else
            result[key] = value
        end
    end

    return result
end

-- Validate configuration
local function validate_config(config)
    -- Validate position
    local valid_positions = { "top", "bottom", "left", "right", "center" }
    if not vim.tbl_contains(valid_positions, config.display.position) then
        vim.notify(string.format('Invalid position: %s. Using "bottom".', config.display.position), vim.log.levels.WARN)
        config.display.position = "bottom"
    end

    -- Validate relative
    local valid_relative = { "editor", "win", "cursor" }
    if not vim.tbl_contains(valid_relative, config.display.relative) then
        config.display.relative = "editor"
    end

    -- Validate border
    local valid_borders = { "none", "single", "double", "rounded", "solid", "shadow" }
    if not vim.tbl_contains(valid_borders, config.display.border) then
        config.display.border = "rounded"
    end

    -- Validate tracks (must be number, string 'all', or table)
    local tracks = config.subtitle.tracks
    if type(tracks) ~= "number" and type(tracks) ~= "table" and tracks ~= "all" then
        vim.notify(string.format("Invalid tracks config: %s. Using 0.", vim.inspect(tracks)), vim.log.levels.WARN)
        config.subtitle.tracks = 0
    end

    -- Validate port
    if config.connection.port < 1 or config.connection.port > 65535 then
        vim.notify(string.format("Invalid port: %d. Using 8767.", config.connection.port), vim.log.levels.WARN)
        config.connection.port = 8767
    end

    return config
end

-- Setup configuration
function M.setup(user_config)
    user_config = user_config or {}

    -- Merge with defaults
    M.config = deep_merge(M.defaults, user_config)

    -- Validate
    M.config = validate_config(M.config)

    return M.config
end

-- Get current config
function M.get()
    return M.config
end

-- Update config at runtime
function M.update(updates)
    M.config = deep_merge(M.config, updates)
    M.config = validate_config(M.config)
    return M.config
end

-- Reset to defaults
function M.reset()
    M.config = vim.deepcopy(M.defaults)
    return M.config
end

return M
