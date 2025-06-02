local helpers = require("__paste-logistic-settings-continued__.src.helpers")
local lib = require("__paste-logistic-settings-continued__.src.lib")

-- Prefix all events to avoid conflicts.
local EVENT_NAMESPACE = "paste-logistic-settings-continued"

-----------------------------------------------------------------------------
-- Copy hotkey
script.on_event(EVENT_NAMESPACE .. "-copy", function(event)
  local player = game.players[event.player_index]
  local target = player.selected
  if not helpers.is_valid_source(game, target) then return end

  global = global or {}
  global.paste_data = global.paste_data or {}

  global.paste_data[event.player_index] = lib.copy_settings(game, player, target)
end)

-----------------------------------------------------------------------------
-- Paste hotkey
script.on_event(EVENT_NAMESPACE .. "-paste", function(event)
  local player = game.players[event.player_index]
  local target = player.selected
  if not target or not target.valid then return end
  if not helpers.is_valid_target(game, target) then return end

  global = global or {}
  global.paste_data = global.paste_data or {}
  local data = global.paste_data[event.player_index]
  if not data or not data.source then return end

  -- Are we pasting onto the source entity* and autoconfiguring?
  -- *More specficially, are we pasting onto an entity /with the same name
  -- as the/ source entity? This allows us to copy from one CraftingMachine
  -- and autoconfigure to many others.
  if target.name == data.source.name then
    lib.autoconfigure_settings(game, player, target, data)
  -- Nope, just pasting to an inserter or chest.
  else
    lib.paste_settings(game, player, target, data)
  end
end)

-----------------------------------------------------------------------------
-- Migrations
script.on_configuration_changed(function(data)
  -- Migrations to 1.3.0
  for _,player in pairs(game.players) do
    local ps = settings.get_player_settings(player)

    local output_limit = ps["paste-logistic-settings-continued-output-limit"]
    local request_size = ps["paste-logistic-settings-continued-request-size"]

    if output_limit and output_limit.value < 1 then
      player.print({"msg.paste-logistic-settings-continued-output-limit-migration"})
    end
    if request_size and request_size.value < 1 then
      player.print({"msg.paste-logistic-settings-continued-request-size-migration"})
    end
  end
end)

