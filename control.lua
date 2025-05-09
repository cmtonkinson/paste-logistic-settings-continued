local helpers = require("__paste-logistic-settings-continued__.scripts.helpers")
local lib = require("__paste-logistic-settings-continued__.scripts.lib")

-- Prefix all events to avoid conflicts.
local EVENT_NAMESPACE = "paste-logistic-settings-continued"

-----------------------------------------------------------------------------
-- Copy hotkey
script.on_event(EVENT_NAMESPACE .. "-copy", function(event)
  local player = game.players[event.player_index]
  local selected = player.selected
  if not helpers.is_valid_source(game, selected) then return end

  global = global or {}
  global.paste_data = global.paste_data or {}

  global.paste_data[event.player_index] = lib.copy_settings(game, selected)
end)

-----------------------------------------------------------------------------
-- Paste hotkey
script.on_event(EVENT_NAMESPACE .. "-paste", function(event)
  local player = game.players[event.player_index]
  local selected = player.selected
  if not helpers.is_valid_target(game, selected) then return end

  global = global or {}
  global.paste_data = global.paste_data or {}
  local data = global.paste_data[event.player_index]
  if not data then return end

  -- Are we pasting onto the source entity and autoconfiguring?
  if selected.name == data.source.name then
    lib.autoconfigure_settings(game, event.player_index, selected)
  -- Nope, just pasting to a specific other entity.
  else
    lib.paste_settings(game, event.player_index, data, selected)
  end
end)
