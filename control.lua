local helpers = require("__paste-logistic-settings-continued__.src.helpers")
local lib = require("__paste-logistic-settings-continued__.src.lib")
local EntityView = require("__paste-logistic-settings-continued__.src.entity_view")

local EVENT_NAMESPACE = "paste-logistic-settings-continued"

-----------------------------------------------------------------------------
-- Keep state on `storage`: Factorio saves and synchronises only that table.
script.on_init(function()
  storage.paste_data = {}
end)

-----------------------------------------------------------------------------
-- Copy hotkey
script.on_event(EVENT_NAMESPACE .. "-copy", function(event)
  local player = game.players[event.player_index]
  local target = player.selected
  local target_view = EntityView.resolve(target)
  if helpers.is_holding_anything(player) then
    return
  end
  if not target_view:is_valid_source() then
    return
  end

  storage.paste_data = storage.paste_data or {}
  storage.paste_data[event.player_index] = lib.copy_settings(player, target)
end)

-----------------------------------------------------------------------------
-- Paste hotkey
script.on_event(EVENT_NAMESPACE .. "-paste", function(event)
  local player = game.players[event.player_index]
  local target = player.selected
  local target_view = EntityView.resolve(target)
  if not target or not target.valid then
    return
  end
  if helpers.is_holding_anything(player) then
    return
  end
  if not target_view:is_valid_target() then
    return
  end

  storage.paste_data = storage.paste_data or {}
  local data = storage.paste_data[event.player_index]
  if not data or not data.source then
    return
  end

  -- Pasting onto any entity with the source's name autoconfigures it, so one
  -- copy can configure many crafting machines. Compare the saved name: the
  -- source entity may be gone, e.g. a ghost the bots have since built.
  if target_view:get_name() == data.source_name then
    lib.autoconfigure_settings(player, target, data)
  else
    lib.paste_settings(player, target, data)
  end
end)

-----------------------------------------------------------------------------
-- Migrations
script.on_configuration_changed(function()
  storage.paste_data = storage.paste_data or {}
end)
