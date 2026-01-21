# subjoyer.nvim

Display live subtitles from [asbplayer-streamer](https://github.com/SanzharKuandyk/asbplayer-subtitle-streamer) as a sleek floating bar in Neovim. Perfect for language learning, watching videos while coding, or any workflow where you want subtitles visible in your editor.

## Features

- **✨ Floating Bar Display** - Full-width subtitle bar using nui.nvim (persistent across editor)
- **📊 Lualine Integration** - Show subtitles in your statusline
- **🎯 Highly Configurable** - Position, size, colors, tracks, formatting
- **🔄 Multi-track Support** - Show one or multiple subtitle tracks
- **🔌 Auto-reconnect** - Handles connection drops gracefully
- **⚡ Non-blocking** - Python WebSocket server runs in background
- **🎨 Customizable Colors** - Match your colorscheme
- **📺 Minimal Dependencies** - Just Python 3.7+, websockets, and nui.nvim

## Display Providers

subjoyer supports multiple display options:

| Provider | Persistence | Default Position | Behavior |
|----------|-------------|------------------|----------|
| **nui** | Persistent | bottom-center | Floating window stays visible across all buffers and windows |
| **incline** | Per-buffer | top-right | Only shows when a buffer/window is present |
| **lualine** | Per-buffer | - | Add subtitle to your lualine statusline |

Both nui and incline can be enabled simultaneously - they use different positions by default to avoid overlap.

Lualine is configured separately in your lualine config.

## Requirements

- Neovim 0.8+
- Python 3.7+
- `websockets` library: `pip install websockets`
- **[nui.nvim](https://github.com/MunifTanjim/nui.nvim)** (required for nui display)
- [asbplayer-streamer](https://github.com/SanzharKuandyk/asbplayer-subtitle-streamer) Chrome extension

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua {
  'SanzharKuandyk/subjoyer.nvim',
  dependencies = {
    'MunifTanjim/nui.nvim', -- Required for nui display (default)
    'b0o/incline.nvim',     -- Optional: for incline display
    'nvim-lualine/lualine.nvim', -- Optional: for lualine integration
  },
  config = function()
    require('subjoyer').setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'SanzharKuandyk/subjoyer.nvim',
  requires = {
    'MunifTanjim/nui.nvim', -- Required for nui display (default)
    'b0o/incline.nvim',     -- Optional: for incline display
    'nvim-lualine/lualine.nvim', -- Optional: for lualine integration
  },
  config = function()
    require('subjoyer').setup()
  end,
}
```

## Setup

### 1. Install dependencies

```bash
pip install websockets
```

### 2. Install nui.nvim

Make sure nui.nvim is installed (see installation above).

### 3. Install asbplayer-streamer extension

Follow the instructions at [asbplayer-streamer](https://github.com/SanzharKuandyk/asbplayer-subtitle-streamer).

Configure the extension to use **WebSocket** transport on **port 8767** (default).

### 4. Configure Neovim

#### Minimal setup (use defaults)

```lua
require('subjoyer').setup()
```

The nui subtitle bar will appear at the bottom-center when subtitles are received.

#### Custom configuration

```lua
require('subjoyer').setup({
  connection = {
    host = 'localhost',
    port = 8767,
    reconnect = true,
    reconnect_delay = 3000,
    max_reconnects = 3,
  },

  display = {
    enabled = true,
    provider = { nui = true, incline = false },
  },

  subtitle = {
    tracks = 0,              -- Show track 0 only (or 'all', or {0,1})
    show_timestamp = true,   -- Show [MM:SS] prefix
    track_label = true,      -- Show "Track 0:", "Track 1:", etc.
    trim = true,
  },

  colors = {
    bg = '#1e1e2e',
    subtitle_fg = '#cdd6f4',
    timestamp_fg = '#89b4fa',
    track_label_fg = '#f9e2af',
    separator_fg = '#585b70',
    prefix_fg = '#a6e3a1',
  },

  nui = {
    prefix = '📺 ',
    suffix = '',
    separator = ' • ',

    window = {
      placement = {
        horizontal = 'center',
        vertical = 'bottom',
      },
      width = 80,            -- columns or "80%" of screen width
      height = 2,            -- default height (when auto_resize is false)
      auto_resize = true,    -- auto-adjust height based on wrapped text
      min_height = 1,        -- minimum height in lines
      max_height = 5,        -- maximum height in lines
      margin = { horizontal = 0, vertical = 1 },
      zindex = 100,
    },
  },

  behavior = {
    auto_start = false,
    hide_on_insert = false,
    debug = false,
  },
})
```

## Usage

### Commands

```vim
:SubjoyerStart           " Start receiving subtitles
:SubjoyerStop            " Stop and cleanup
:SubjoyerToggle          " Toggle on/off
:SubjoyerStatus          " Show connection status
:SubjoyerMineAnki        " Mine this line via absplayer's AnkiConnect
```

### Workflow

1. Start Neovim
2. Run `:SubjoyerStart`
3. Play a video with asbplayer in Chrome
4. Subtitles appear in the bar at bottom/top of your editor

## Configuration Examples

### Enable both providers

```lua
require('subjoyer').setup({
  display = {
    provider = { nui = true, incline = true },
  },
  nui = {
    window = {
      placement = { vertical = 'bottom' },  -- nui stays at bottom
    },
  },
  incline = {
    window = {
      placement = { horizontal = 'right', vertical = 'top' },  -- incline at top-right
    },
  },
})
```

### Different timestamp settings per provider

```lua
require('subjoyer').setup({
  subtitle = { show_timestamp = true },  -- global default
  nui = { show_timestamp = true },       -- nui shows timestamp
  incline = { show_timestamp = false },  -- incline hides timestamp
})
```

### Auto-resize height configuration

```lua
require('subjoyer').setup({
  nui = {
    window = {
      auto_resize = true,
      min_height = 1,
      max_height = 10,  -- allow taller windows for long subtitles
    },
  },
})
```

### Custom colors

```lua
require('subjoyer').setup({
  colors = {
    bg = '#282c34',
    subtitle_fg = '#abb2bf',
    timestamp_fg = '#61afef',
    track_label_fg = '#e5c07b',
    separator_fg = '#5c6370',
    prefix_fg = '#98c379',
  },
})
```

### Position nui at top

```lua
require('subjoyer').setup({
  nui = {
    window = {
      placement = {
        vertical = 'top',
        horizontal = 'center',
      },
    },
  },
})
```

### Left-aligned compact bar

```lua
require('subjoyer').setup({
  nui = {
    prefix = '',
    window = {
      placement = {
        horizontal = 'left',
        vertical = 'bottom',
      },
      width = 60,
      margin = { horizontal = 0, vertical = 0 },
    },
  },
})
```

### Lualine integration

```lua
require('lualine').setup({
  sections = {
    lualine_c = {
      require('subjoyer.lualine').component(),
    },
  },
})
```

Or with custom options:
## Configuration Reference

### `connection`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `host` | string | `'localhost'` | WebSocket server host |
| `port` | number | `8767` | WebSocket server port |
| `reconnect` | boolean | `true` | Auto-reconnect on disconnect |
| `reconnect_delay` | number | `3000` | Delay before reconnect (ms) |
| `max_reconnects` | number | `3` | Max reconnection attempts (0 = unlimited) |

### `display`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `true` | Show subtitle bar |
| `provider.nui` | boolean | `true` | Use nui (persistent floating window) |
| `provider.incline` | boolean | `false` | Use incline (per-buffer statusline) |

### `subtitle` (global)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `tracks` | number/string/table | `0` | Track filter: 0, 'all', or {0,1,2} |
| `show_timestamp` | boolean | `true` | Show [MM:SS] prefix |
| `track_label` | boolean | `true` | Show "Track 0:", etc. |
| `trim` | boolean | `true` | Trim whitespace |
| `empty_placeholder` | string | `''` | Text when no subtitle active |

### `colors`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `bg` | string | `'#1e1e2e'` | Background color |
| `subtitle_fg` | string | `'#cdd6f4'` | Subtitle text color |
| `timestamp_fg` | string | `'#89b4fa'` | Timestamp color |
| `track_label_fg` | string | `'#f9e2af'` | Track label color |
| `separator_fg` | string | `'#585b70'` | Separator color |
| `prefix_fg` | string | `'#a6e3a1'` | Prefix icon color |
| `suffix_fg` | string | `'#585b70'` | Suffix color |
| `empty_fg` | string | `'#6c7086'` | Empty state color |
| `error_fg` | string | `'#f38ba8'` | Error message color |

### `nui`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prefix` | string | `'📺 '` | Prefix before subtitles |
| `suffix` | string | `''` | Suffix after subtitles |
| `separator` | string | `' • '` | Separator between tracks |
| `subtitle.show_timestamp` | boolean/nil | `nil` | Override global `show_timestamp` |
| `subtitle.track_label` | boolean/nil | `nil` | Override global `track_label` |
| `subtitle.max_text_length` | number/nil | `nil` | Truncate text (nil = no limit) |
| `window.placement.horizontal` | string | `'center'` | 'left', 'center', 'right' |
| `window.placement.vertical` | string | `'bottom'` | 'top' or 'bottom' |
| `window.width` | number/string | `80` | Width in columns or "80%" |
| `window.height` | number | `2` | Default height in lines |
| `window.auto_resize` | boolean | `true` | Auto-adjust height based on text |
| `window.min_height` | number | `1` | Minimum height in lines |
| `window.max_height` | number | `5` | Maximum height in lines |
| `window.margin.horizontal` | number | `0` | Horizontal margin |
| `window.margin.vertical` | number | `1` | Vertical margin |
| `window.zindex` | number | `100` | Window z-index |

### `incline`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prefix` | string | `'📺 '` | Prefix before subtitles |
| `suffix` | string | `''` | Suffix after subtitles |
| `separator` | string | `' • '` | Separator between tracks |
| `show_timestamp` | boolean/nil | `nil` | Override global `show_timestamp` |
| `track_label` | boolean/nil | `nil` | Override global `track_label` |
| `max_text_length` | number/nil | `nil` | Truncate text (nil = no limit) |
| `window.placement.horizontal` | string | `'right'` | 'left', 'center', 'right' |
| `window.placement.vertical` | string | `'top'` | 'top' or 'bottom' |
| `window.margin.horizontal` | number | `0` | Horizontal margin |
| `window.margin.vertical` | number | `1` | Vertical margin |
| `window.zindex` | number | `50` | Window z-index |

### `lualine`

Lualine integration - add subtitle component to your lualine config.

```lua
require('lualine').setup({
  sections = {
    lualine_c = {
      require('subjoyer.lualine').component(),
    },
  },
})
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max_length` | number | `80` | Max text length (truncates with "...") |
| `show_icon` | boolean | `true` | Show icon prefix |
| `icon` | string | `'📺 '` | Icon to display |
| `show_timestamp` | boolean/nil | `nil` | Override global `show_timestamp` |
| `track_label` | boolean/nil | `nil` | Override global `track_label` |
| `separator` | string | `' • '` | Separator between tracks |

### `behavior`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `auto_start` | boolean | `false` | Start on nvim launch |
| `hide_on_insert` | boolean | `false` | Hide bar in insert mode |
| `debug` | boolean | `false` | Enable debug logging |

## How It Works

```
asbplayer (Chrome Extension)
    ↓ WebSocket
Python Server (ws_client.py) - Started by Neovim as background job
    ↓ stdout (JSON)
Neovim Lua Plugin
    ↓ Render & Display
nui.nvim (Persistent Floating Bar)
```

**Non-blocking**: Python server runs as background job, Neovim remains fully responsive.

**nui provider**: Creates a persistent floating window that stays visible across all buffers and windows in your editor session.

**incline provider**: Creates per-buffer statusline bars that only exist while a buffer/window is present.

## Troubleshooting

### "nui.popup not found" error

Install nui.nvim as a dependency (see Installation section).

### "Python not found" error

Make sure Python 3.7+ is installed and in your PATH:

```bash
python3 --version  # or python --version
```

### "websockets not found" error

Install the websockets library:

```bash
pip install websockets
```

### Extension not connecting

1. Check extension is configured for WebSocket transport
2. Verify port is 8767 (default)
3. Run `:SubjoyerStatus` to check server status
4. Run `:SubjoyerDebug` to enable debug logging
5. Check for port conflicts: `netstat -an | grep 8767`

### Subtitles not appearing

1. Verify asbplayer is active and subtitles are loaded
2. Run `:SubjoyerStatus` to check connection

### Bar not visible

Check nui.nvim is installed and working. The bar only appears when subtitles are received. If using nui, the window is persistent and should stay visible even when switching buffers.

If the bar was visible but disappeared:
1. Check if the window was accidentally closed
2. Run `:SubjoyerToggle` to show/hide
3. Run `:SubjoyerStart` to restart the plugin

## Testing

Test the WebSocket server independently:

```bash
cd ~/.local/share/nvim/site/pack/plugins/start/subjoyer.nvim
python scripts/test_server.py
```

Then configure extension to connect. You should see subtitles print in terminal.

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT

## Credits

- Built for use with [asbplayer-streamer](https://github.com/SanzharKuandyk/asbplayer-subtitle-streamer)
- Uses [nui.nvim](https://github.com/MunifTanjim/nui.nvim) for persistent subtitle bar display
