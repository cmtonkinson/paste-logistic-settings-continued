local lib = require("src.lib")

local function request_map(section)
  local requests = {}
  for _, filter in ipairs(section.filters) do
    if filter.value and filter.value.name then
      requests[filter.value.name] = filter.min
    end
  end
  return requests
end

local function ingredient_map(ingredients)
  local mapped = {}
  for _, ingredient in ipairs(ingredients) do
    mapped[ingredient.name] = ingredient
  end
  return mapped
end

local function create_transport_belt_cell(surface)
  local machine = surface.create_entity({
    name = "assembling-machine-2",
    position = { x = 0.5, y = 0.5 },
    force = "player",
  })
  machine.set_recipe("transport-belt")

  local requester = surface.create_entity({
    name = "requester-chest",
    position = { x = -2.5, y = 0.5 },
    force = "player",
  })
  local input_inserter = surface.create_entity({
    name = "fast-inserter",
    position = { x = -1.5, y = 0.5 },
    direction = defines.direction.west,
    force = "player",
  })
  local output_inserter = surface.create_entity({
    name = "fast-inserter",
    position = { x = 2.5, y = 0.5 },
    direction = defines.direction.west,
    force = "player",
  })
  local storage = surface.create_entity({
    name = "storage-chest",
    position = { x = 3.5, y = 0.5 },
    force = "player",
  })

  return {
    machine = machine,
    requester = requester,
    input_inserter = input_inserter,
    output_inserter = output_inserter,
    storage = storage,
  }
end

local function transport_belt_cell(surface)
  return {
    machine = surface.find_entity("assembling-machine-2", { x = 0.5, y = 0.5 }),
    requester = surface.find_entity("requester-chest", { x = -2.5, y = 0.5 }),
    input_inserter = surface.find_entity("fast-inserter", { x = -1.5, y = 0.5 }),
    output_inserter = surface.find_entity("fast-inserter", { x = 2.5, y = 0.5 }),
    storage = surface.find_entity("storage-chest", { x = 3.5, y = 0.5 }),
  }
end

return {
  setup = {
    test = function(f, context)
      local cell = create_transport_belt_cell(context.game.surfaces[1])

      f:expect(cell.machine.valid, true)
      f:expect(cell.machine.get_recipe().name, "transport-belt")
      f:expect(cell.requester.valid, true)
      f:expect(cell.storage.valid, true)
      f:expect(cell.input_inserter.valid, true)
      f:expect(cell.output_inserter.valid, true)
      f:expect(cell.requester.get_logistic_point(0).sections_count, 1)
    end,
  },

  fixture_resolves_targets = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])

      f:expect(cell.input_inserter.drop_target.name, "assembling-machine-2")
      f:expect(cell.input_inserter.pickup_target.name, "requester-chest")
      f:expect(cell.output_inserter.pickup_target.name, "assembling-machine-2")
      f:expect(cell.output_inserter.drop_target.name, "storage-chest")
    end,
  },

  copy_settings_extracts_recipe_data = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)
      local ingredients = ingredient_map(data.ingredients)

      f:expect(data.item, true)
      f:expect(data.name, "transport-belt")
      f:expect(#data.ingredients, 2)
      f:expect(ingredients["iron-plate"].amount, 1)
      f:expect(ingredients["iron-gear-wheel"].amount, 1)
    end,
  },

  paste_to_storage_sets_output_filter = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      lib.paste_settings(context.game, { index = 1 }, cell.storage, data)

      f:expect(cell.storage.storage_filter.name, prototypes.item["transport-belt"])
    end,
  },

  paste_to_requester_sets_item_requests = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-request-size-type"] = "items",
        ["paste-logistic-settings-continued-request-size"] = 7,
      }, function(player)
        lib.paste_settings(context.game, player, cell.requester, data)
      end)

      local point = cell.requester.get_logistic_point(0)
      local section = point.sections[1]
      local requests = request_map(section)

      f:expect(point.sections_count, 1)
      f:expect(section.group, "")
      f:expect(requests["iron-plate"], 7)
      f:expect(requests["iron-gear-wheel"], 7)
    end,
  },

  paste_to_output_inserter_sets_logistic_condition = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-output-limit-type"] = "items",
        ["paste-logistic-settings-continued-output-limit"] = 13,
      }, function(player)
        lib.paste_settings(context.game, player, cell.output_inserter, data)
      end)

      local behavior = cell.output_inserter.get_or_create_control_behavior()
      local condition = behavior.logistic_condition
      local signal = condition.first_signal.signal or condition.first_signal

      f:expect(behavior.connect_to_logistic_network, true)
      f:expect(condition.comparator, "<")
      f:expect(signal.name, "transport-belt")
      f:expect(condition.constant, 13)
    end,
  },
}
