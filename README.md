# subjoyer.nvim

Display live subtitles from [asbplayer-streamer](https://github.com/SanzharKuandyk/asbplayer-subtitle-streamer) as a sleek statusline bar in Neovim using [incline.nvim](https://github.com/b0o/incline.nvim). Perfect for language learning, watching videos while coding, or any workflow where you want subtitles visible in your editor.

## Features

- **✨ Statusline Bar Display** - Full-width subtitle bar using incline.nvim
- **🎯 Highly Configurable** - Position, colors, tracks, formatting
- **🔄 Multi-track Support** - Show one or multiple subtitle tracks
- **🔌 Auto-reconnect** - Handles connection drops gracefully
- **⚡ Non-blocking** - Python WebSocket server runs in background
- **🎨 Customizable Colors** - Match your colorscheme
- **📺 Minimal Dependencies** - Just Python 3.7+, websockets, and incline.nvim

## Requirements

- Neovim 0.8+
- Python 3.7+
- `websockets` library: `pip install websockets`
- **[incline.nvim](https://github.com/b0o/incline.nvim)** (required)
- [asbplayer-streamer](https://github.com/SanzharKuandyk/asbplayer-subtitle-streamer) Chrome extension

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'SanzharKuandyk/subjoyer.nvim',
  dependencies = {
    'b0o/incline.nvim', -- Required dependency
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
    'b0o/incline.nvim', -- Required
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

### 2. Install incline.nvim

Make sure incline.nvim is installed (see installation above).

### 3. Install asbplayer-streamer extension

Follow the instructions at [asbplayer-streamer](https://github.com/SanzharKuandyk/asbplayer-subtitle-streamer).

Configure the extension to use **WebSocket** transport on **port 8767** (default).

### 4. Configure Neovim

#### Minimal setup (use defaults)

```lua
require('subjoyer').setup()
```

The subtitle bar will appear at the bottom (below your statusline) when subtitles are received.

#### Custom configuration

```lua
require('subjoyer').setup({
  -- Connection settings
  connection = {
    host = 'localhost',
    port = 8767,
    reconnect = true,
    reconnect_delay = 3000,
    max_reconnects = 3,
  },

  -- Display settings
  display = {
    enabled = true,
  },

  -- Subtitle settings
  subtitle = {
    tracks = 0,              -- Show track 0 only (or 'all', or {0,1})
    show_timestamp = true,
    track_label = true,
    trim = true,
  },

  -- Colors (customize to match your theme)
  colors = {
    bg = '#1e1e2e',
    subtitle_fg = '#cdd6f4',
    timestamp_fg = '#89b4fa',
    track_label_fg = '#f9e2af',
    separator_fg = '#585b70',
    prefix_fg = '#a6e3a1',
  },

  -- Incline.nvim bar options
  incline = {
    prefix = '📺 ',
    separator = ' • ',
    show_timestamp = true,
    show_track_label = true,
    max_text_length = 100,

    -- Position: 'top' = above statusline, 'bottom' = below statusline
    options = {
      window = {
        placement = {
          horizontal = 'center', -- 'left', 'center', 'right'
          vertical = 'bottom',   -- 'top' or 'bottom'
        },
        margin = { horizontal = 0, vertical = 1 },
        padding = { left = 2, right = 2 },
      },
    },
  },

  -- Behavior
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
:SubjoyerShow            " Show subtitle bar
:SubjoyerHide            " Hide subtitle bar
:SubjoyerStatus          " Show connection status
:SubjoyerReconnect       " Force reconnect
:SubjoyerSetTrack <n>    " Change track filter (0, 1, 'all')
:SubjoyerSetPosition <p> " Change position (top, bottom)
:SubjoyerDebug           " Toggle debug mode
```

### Workflow

1. Start Neovim
2. Run `:SubjoyerStart`
3. Play a video with asbplayer in Chrome
4. Subtitles appear in the bar at bottom/top of your editor
5. Use `:SubjoyerSetTrack 1` to switch tracks
6. Use `:SubjoyerSetPosition top` to move above statusline

## Configuration Examples

### Show multiple tracks

```lua
require('subjoyer').setup({
  subtitle = {
    tracks = {0, 1},       -- Show both track 0 and track 1
    track_label = true,    -- Show "Track 0:", "Track 1:"
  },
  incline = {
    separator = ' | ',     -- Separate tracks with " | "
  },
})
```

### Clean minimal display (no labels, no timestamp)

```lua
require('subjoyer').setup({
  subtitle = {
    tracks = 0,
  },
  incline = {
    prefix = '',
    show_timestamp = false,
    show_track_label = false,
  },
})
```

### Position at top (above statusline)

```lua
require('subjoyer').setup({
  incline = {
    options = {
      window = {
        placement = {
          vertical = 'top', -- Above statusline
        },
      },
    },
  },
})
```

### Custom colors (match your theme)

```lua
require('subjoyer').setup({
  colors = {
    bg = '#282c34',           -- Background
    subtitle_fg = '#abb2bf',  -- Subtitle text
    timestamp_fg = '#61afef', -- Timestamp [MM:SS]
    track_label_fg = '#e5c07b', -- Track labels
    separator_fg = '#5c6370', -- Separator between tracks
    prefix_fg = '#98c379',    -- Prefix icon
  },
})
```

### Auto-start on launch

```lua
require('subjoyer').setup({
  behavior = {
    auto_start = true,  -- Starts automatically when you open Neovim
  },
})
```

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

### `subtitle`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `tracks` | number/string/table | `0` | Track filter: 0, 'all', or {0,1,2} |
| `max_lines` | number | `5` | Max subtitle lines to display |
| `show_timestamp` | boolean | `true` | Show [MM:SS] prefix |
| `timestamp_format` | string | `'[%M:%S]'` | Timestamp format |
| `track_label` | boolean | `true` | Show "Track 0:", "Track 1:", etc. |
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

### `incline`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prefix` | string | `'📺 '` | Prefix before subtitles |
| `suffix` | string | `''` | Suffix after subtitles |
| `separator` | string | `' • '` | Separator between tracks |
| `show_timestamp` | boolean | `true` | Show timestamps |
| `show_track_label` | boolean | `true` | Show track labels |
| `max_text_length` | number | `100` | Truncate long subtitles |
| `text_style.bold` | boolean | `false` | Bold subtitle text |
| `text_style.italic` | boolean | `false` | Italic subtitle text |
| `text_style.underline` | boolean | `false` | Underline subtitle text |
| `options.window.placement.horizontal` | string | `'center'` | 'left', 'center', 'right' |
| `options.window.placement.vertical` | string | `'bottom'` | 'top' or 'bottom' |

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
incline.nvim (Subtitle Bar)
```

**Non-blocking**: Python server runs as background job, Neovim remains fully responsive.

## Troubleshooting

### "incline.nvim not found" error

Install incline.nvim as a dependency (see Installation section).

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
3. Try `:SubjoyerReconnect`
4. Enable debug mode: `:SubjoyerDebug`

### Wrong track showing

Use `:SubjoyerSetTrack` to change:

```vim
:SubjoyerSetTrack 0     " Show track 0
:SubjoyerSetTrack 1     " Show track 1
:SubjoyerSetTrack all   " Show all tracks
```

### Bar not visible

Check incline.nvim is installed and working. The bar only appears when subtitles are received.

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

- Written by Claude (Anthropic) and examined by a human
- Built for use with [asbplayer-streamer](https://github.com/SanzharKuandyk/asbplayer-subtitle-streamer)
- Uses [incline.nvim](https://github.com/b0o/incline.nvim) for statusline integration
