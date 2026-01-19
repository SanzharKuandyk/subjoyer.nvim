-- Subtitle rendering and formatting
local M = {}

-- Format timestamp from seconds
local function format_timestamp(seconds, format)
  if not seconds then
    return ''
  end

  local minutes = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)

  -- Simple format replacement
  format = format:gsub('%%M', string.format('%02d', minutes))
  format = format:gsub('%%S', string.format('%02d', secs))

  return format
end

-- Trim whitespace
local function trim(s)
  return s:match('^%s*(.-)%s*$')
end

-- Filter subtitle lines based on track config
local function filter_tracks(subtitle_data, track_config)
  if not subtitle_data or not subtitle_data.lines then
    -- Fallback to old format (subtitle.text)
    return nil
  end

  local lines = subtitle_data.lines
  local filtered = {}

  -- Handle 'all' - show all tracks
  if track_config == 'all' then
    return lines
  end

  -- Handle single track number
  if type(track_config) == 'number' then
    for _, line in ipairs(lines) do
      if line.track == track_config then
        table.insert(filtered, line)
      end
    end
    return filtered
  end

  -- Handle array of track numbers
  if type(track_config) == 'table' then
    for _, line in ipairs(lines) do
      if vim.tbl_contains(track_config, line.track) then
        table.insert(filtered, line)
      end
    end
    return filtered
  end

  -- Default: return all lines
  return lines
end

-- Render subtitle data for incline display
function M.render(data, config)
  if not data or not data.subtitle then
    return {}
  end

  local subtitle = data.subtitle
  local video = data.video or {}
  local lines = {}

  -- Filter tracks
  local filtered_lines = filter_tracks(subtitle, config.subtitle.tracks)

  -- Fallback to subtitle.text if no lines
  if not filtered_lines or #filtered_lines == 0 then
    if subtitle.text and subtitle.text ~= '' then
      filtered_lines = {{ text = subtitle.text, track = 0 }}
    else
      return {}
    end
  end

  -- Build output lines as structured data
  for _, line_data in ipairs(filtered_lines) do
    local text = line_data.text or ''

    -- Trim whitespace
    if config.subtitle.trim then
      text = trim(text)
    end

    -- Skip empty lines
    if text == '' then
      goto continue
    end

    -- Truncate long text
    if config.incline.max_text_length and #text > config.incline.max_text_length then
      text = string.sub(text, 1, config.incline.max_text_length) .. '...'
    end

    -- Get track number
    local track_num = line_data.track or 0

    local line_obj = {
      text = text,
      track_num = track_num,  -- Pass track number for color selection
    }

    -- Add timestamp if enabled
    if config.incline.show_timestamp and video.currentTime then
      line_obj.timestamp = format_timestamp(video.currentTime, config.subtitle.timestamp_format)
    end

    -- Add track label if enabled
    if config.incline.show_track_label then
      line_obj.track_label = string.format('Track %d:', track_num)
    end

    table.insert(lines, line_obj)

    ::continue::
  end

  return lines
end


return M
