# Track-Specific Colors Guide

## Overview

Each subtitle track can have its own color scheme! This is perfect for:
- **Language learning** - Different colors for native vs target language
- **Multiple subtitle tracks** - Easy visual distinction
- **Accessibility** - Color-code tracks by importance

## Default Colors (Catppuccin Theme)

- **Track 0**: Blue/Sky theme (`#89dceb` / `#89b4fa`)
- **Track 1**: Green/Teal theme (`#a6e3a1` / `#94e2d5`)
- **Track 2**: Pink/Mauve theme (`#f5c2e7` / `#cba6f7`)
- **Track 3**: Yellow/Peach theme (`#f9e2af` / `#fab387`)
- **Track 4+**: Falls back to default colors

## Configuration

### Hide "Track 0:" label

```lua
require('subjoyer').setup({
  incline = {
    show_track_label = false,
  },
})
```

### Customize track colors

```lua
require('subjoyer').setup({
  colors = {
    -- Track 0: Your native language (e.g., English)
    track_0_fg = '#89dceb',        -- Sky blue
    track_0_label_fg = '#89b4fa',  -- Blue

    -- Track 1: Your target language (e.g., Japanese)
    track_1_fg = '#a6e3a1',        -- Green
    track_1_label_fg = '#94e2d5',  -- Teal

    -- Track 2: Additional track
    track_2_fg = '#f5c2e7',        -- Pink
    track_2_label_fg = '#cba6f7',  -- Mauve
  },
})
```

### Add more tracks

Just follow the pattern `track_N_fg` and `track_N_label_fg`:

```lua
colors = {
  track_4_fg = '#f38ba8',      -- Red
  track_4_label_fg = '#eba0ac', -- Light red

  track_5_fg = '#fab387',      -- Peach
  track_5_label_fg = '#f9e2af', -- Yellow
}
```

## Examples

### Language Learning: Native Blue, Target Green

```lua
require('subjoyer').setup({
  subtitle = {
    tracks = {0, 1},  -- Show both tracks
  },
  incline = {
    show_track_label = true,
    separator = ' | ',
  },
  colors = {
    track_0_fg = '#89b4fa',  -- Blue for English
    track_1_fg = '#a6e3a1',  -- Green for Japanese
  },
})
```

**Result:**
```
📺 [01:23] Track 0: Hello world | Track 1: こんにちは
           ^^^^^^^^ (blue)              ^^^^^^^^ (green)
```

### Minimal: Single track, no label, custom color

```lua
require('subjoyer').setup({
  subtitle = {
    tracks = 0,  -- Only track 0
  },
  incline = {
    prefix = '',
    show_track_label = false,
    show_timestamp = false,
  },
  colors = {
    track_0_fg = '#cba6f7',  -- Mauve
  },
})
```

**Result:**
```
めっちゃ綺麗ですよね
```

### High Contrast: Bright colors

```lua
require('subjoyer').setup({
  colors = {
    bg = '#000000',           -- Pure black background
    track_0_fg = '#00ffff',   -- Cyan
    track_1_fg = '#ffff00',   -- Yellow
    track_2_fg = '#ff00ff',   -- Magenta
  },
})
```

### Match Your Theme

#### Gruvbox
```lua
colors = {
  bg = '#282828',
  track_0_fg = '#83a598',  -- Blue
  track_1_fg = '#b8bb26',  -- Green
  track_2_fg = '#fb4934',  -- Red
}
```

#### Tokyo Night
```lua
colors = {
  bg = '#1a1b26',
  track_0_fg = '#7aa2f7',  -- Blue
  track_1_fg = '#9ece6a',  -- Green
  track_2_fg = '#bb9af7',  -- Purple
}
```

#### Nord
```lua
colors = {
  bg = '#2e3440',
  track_0_fg = '#88c0d0',  -- Frost
  track_1_fg = '#a3be8c',  -- Green
  track_2_fg = '#b48ead',  -- Purple
}
```

## Tips

1. **Use contrasting colors** for multiple tracks so they're easy to distinguish
2. **Match your Neovim theme** for visual consistency
3. **Test in your actual lighting** - colors look different in bright vs dark rooms
4. **Accessibility** - Ensure sufficient contrast against background
5. **Track labels help** when first learning colors, disable later when familiar

## Color Tools

- **Catppuccin palette**: https://github.com/catppuccin/catppuccin
- **Color contrast checker**: https://webaim.org/resources/contrastchecker/
- **Palette generator**: https://coolors.co/
