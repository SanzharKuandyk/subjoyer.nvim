# Quick Start Guide

Get up and running with subjoyer.nvim + incline.nvim in 5 minutes.

## 1. Install Dependencies

```bash
pip install websockets
```

## 2. Add to Neovim Config

Add to your `init.lua` or plugin manager:

```lua
-- With lazy.nvim
{
  'SanzharKuandyk/subjoyer.nvim',
  dependencies = {
    'b0o/incline.nvim', -- Required!
  },
  config = function()
    require('subjoyer').setup()
  end,
}
```

## 3. Configure asbplayer-streamer Extension

1. Open extension settings in Chrome
2. Set transport to **WebSocket**
3. Set URL to `ws://localhost:8767`
4. Click "Save Settings"
5. Click "Test Connection" (should turn green)

## 4. Start Plugin

In Neovim:

```vim
:SubjoyerStart
```

## 5. Play Video

1. Navigate to a video site (Netflix, YouTube, etc.)
2. Activate asbplayer and load subtitles
3. Play the video
4. Subtitles appear as a bar at the bottom of Neovim!

## What You'll See

A full-width subtitle bar appears at the bottom (below your statusline):

```
┌────────────────────────────────────────────────────────┐
│ 📺 [01:23] Track 0: Hello, world! • Track 1: こんにちは │
└────────────────────────────────────────────────────────┘
```

## Common Commands

```vim
:SubjoyerStart          " Start receiving subtitles
:SubjoyerStop           " Stop
:SubjoyerStatus         " Check connection status
:SubjoyerSetTrack 0     " Show only track 0
:SubjoyerSetTrack all   " Show all tracks
:SubjoyerSetPosition top  " Move above statusline
```

## Customization Examples

### Show only one track, no labels

```lua
require('subjoyer').setup({
  subtitle = {
    tracks = 0,  -- Show track 0 only
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
          vertical = 'top',  -- Above statusline
        },
      },
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
  },
})
```

## Troubleshooting

### Extension won't connect

1. Check Python is installed: `python3 --version`
2. Check websockets installed: `pip list | grep websockets`
3. Run `:SubjoyerStatus` in Neovim
4. Enable debug: `:SubjoyerDebug`

### incline.nvim not found

Make sure incline.nvim is installed as a dependency in your plugin manager.

### Port conflict

If port 8767 is in use, change it:

```lua
require('subjoyer').setup({
  connection = {
    port = 9999,  -- Use different port
  },
})
```

Then update extension settings to match.

## Next Steps

- Read [README.md](README.md) for full configuration options
- Customize colors to match your theme
- Set up keybindings for commands
- Try different track configurations

Enjoy your subtitles in Neovim! 📺✨
