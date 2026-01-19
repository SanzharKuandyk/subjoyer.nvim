# Debug Guide

## Step-by-step debugging

### 1. Enable debug mode

```vim
:lua require('subjoyer').setup({behavior = {debug = true}})
```

### 2. Check if plugin loaded

```vim
:lua print(vim.inspect(require('subjoyer').status()))
```

Should show:
```lua
{
  plugin_started = false,
  server_running = false,
  display_visible = false,
  job_id = nil,
  reconnect_count = 0
}
```

### 3. Start the plugin

```vim
:SubjoyerStart
```

You should see notifications:
- `[subjoyer] Server ready on localhost:8766`
- `[subjoyer] Extension connected (v1.0.0)`

### 4. Check status again

```vim
:SubjoyerStatus
```

Should show:
- Plugin: Running
- Server: Running
- Job ID: (some number)

### 5. Check incline setup

```vim
:lua print(pcall(require, 'incline'))
```

Should print: `true	table: 0x...`

If `false`, incline.nvim is not installed!

### 6. Manually test subtitle rendering

```lua
:lua local renderer = require('subjoyer.renderer')
:lua local config = require('subjoyer.config').get()
:lua local test_data = {subtitle = {text = "Test", lines = {{text = "Test", track = 0}}}, video = {currentTime = 60}}
:lua print(vim.inspect(renderer.render(test_data, config)))
```

Should print structured subtitle data.

### 7. Check if job is actually running

```vim
:lua print(vim.inspect(require('subjoyer.websocket').status()))
```

### 8. Read job output manually

If job is running but not processing, check raw stdout:

```vim
:messages
```

Look for any error messages.

## Common Issues

### Issue: "incline.nvim not found"

**Solution:** Install incline.nvim as dependency

```lua
-- lazy.nvim
{
  'your-username/subjoyer.nvim',
  dependencies = {
    'b0o/incline.nvim',
  },
  config = function()
    require('subjoyer').setup()
  end,
}
```

### Issue: No notifications when starting

**Cause:** Debug mode is off, errors are silent

**Solution:** Enable debug:

```vim
:lua require('subjoyer').setup({behavior = {debug = true}})
:SubjoyerStart
```

### Issue: Job starts but doesn't receive messages

**Cause:** stdout parsing issue or JSON decode error

**Solution:** Check for parse errors in debug mode (stderr will show them)

### Issue: Subtitles received but not displayed

**Cause:** incline.nvim not refreshing or render function returning nil

**Solution:**
1. Check incline is installed
2. Manually trigger refresh: `:lua require('incline').refresh()`
3. Check display.lua render function
