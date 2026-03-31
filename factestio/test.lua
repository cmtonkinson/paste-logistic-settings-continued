local function require_plsc_module(module_name)
  if _G.script == nil then
    return require("src." .. module_name)
  end
  return require("__paste-logistic-settings-continued__.src." .. module_name)
end

local lib = require_plsc_module("lib")

local function with_mocked_player_settings(overrides, fn)
  local real_settings = settings
  local values = {
    ["paste-logistic-settings-continued-output-limit-type"] = {
      value = overrides.output_limit_type or "stacks",
    },
    ["paste-logistic-settings-continued-output-limit"] = {
      value = overrides.output_limit or 1,
    },
    ["paste-logistic-settings-continued-request-size-type"] = {
      value = overrides.request_size_type or "stacks",
    },
    ["paste-logistic-settings-continued-request-size"] = {
      value = overrides.request_size or 1,
    },
  }

  settings = {
    get_player_settings = function(player_index)
      assert(player_index == 1, "expected mocked player index 1")
      return values
    end,
  }

  local ok, err = pcall(fn, { index = 1 })
  settings = real_settings
  if not ok then
    error(err, 0)
  end
end

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
    position = { x = 0, y = 0 },
    force = "player",
  })
  machine.set_recipe("transport-belt")

  local requester = surface.create_entity({
    name = "logistic-chest-requester",
    position = { x = -3, y = 0 },
    force = "player",
  })
  local input_inserter = surface.create_entity({
    name = "fast-inserter",
    position = { x = -2, y = 0 },
    direction = defines.direction.east,
    force = "player",
  })
  local output_inserter = surface.create_entity({
    name = "fast-inserter",
    position = { x = 2, y = 0 },
    direction = defines.direction.east,
    force = "player",
  })
  local storage = surface.create_entity({
    name = "logistic-chest-storage",
    position = { x = 3, y = 0 },
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
    machine = surface.find_entity("assembling-machine-2", { x = 0, y = 0 }),
    requester = surface.find_entity("logistic-chest-requester", { x = -3, y = 0 }),
    input_inserter = surface.find_entity("fast-inserter", { x = -2, y = 0 }),
    output_inserter = surface.find_entity("fast-inserter", { x = 2, y = 0 }),
    storage = surface.find_entity("logistic-chest-storage", { x = 3, y = 0 }),
  }
end

local function create_fluid_recipe_cell(surface)
  local plant = surface.create_entity({
    name = "chemical-plant",
    position = { x = 10, y = 0 },
    force = "player",
  })
  plant.set_recipe("sulfuric-acid")

  local storage = surface.create_entity({
    name = "logistic-chest-storage",
    position = { x = 13, y = 0 },
    force = "player",
  })

  return {
    plant = plant,
    storage = storage,
  }
end

local function fluid_recipe_cell(surface)
  return {
    plant = surface.find_entity("chemical-plant", { x = 10, y = 0 }),
    storage = surface.find_entity("logistic-chest-storage", { x = 13, y = 0 }),
  }
end

return {
  transport_belt_setup = {
    test = function(f, context)
      local cell = create_transport_belt_cell(context.game.surfaces[1])

      f:expect(cell.machine.valid, true)
      f:expect(cell.machine.get_recipe().name, "transport-belt")
      f:expect(cell.requester.valid, true)
      f:expect(cell.storage.valid, true)
      f:expect(cell.input_inserter.drop_target, cell.machine)
      f:expect(cell.input_inserter.pickup_target, cell.requester)
      f:expect(cell.output_inserter.pickup_target, cell.machine)
      f:expect(cell.output_inserter.drop_target, cell.storage)
      f:expect(cell.requester.get_logistic_point(0).sections_count, 0)
    end,
  },

  copy_settings_extracts_recipe_data = {
    from = "transport_belt_setup",
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
    from = "transport_belt_setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      lib.paste_settings(context.game, { index = 1 }, cell.storage, data)

      f:expect(cell.storage.storage_filter.name, "transport-belt")
    end,
  },

  paste_to_requester_sets_item_requests = {
    from = "transport_belt_setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      with_mocked_player_settings({
        request_size_type = "items",
        request_size = 7,
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
    from = "transport_belt_setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      with_mocked_player_settings({
        output_limit_type = "items",
        output_limit = 13,
      }, function(player)
        lib.paste_settings(context.game, player, cell.output_inserter, data)
      end)

      local behavior = cell.output_inserter.get_or_create_control_behavior()
      local condition = behavior.logistic_condition

      f:expect(behavior.connect_to_logistic_network, true)
      f:expect(condition.comparator, "<")
      f:expect(condition.first_signal.type, "item")
      f:expect(condition.first_signal.name, "transport-belt")
      f:expect(condition.constant, 13)
    end,
  },

  autoconfigure_updates_connected_logistics = {
    from = "transport_belt_setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      with_mocked_player_settings({
        output_limit_type = "items",
        output_limit = 9,
        request_size_type = "items",
        request_size = 5,
      }, function(player)
        lib.autoconfigure_settings(context.game, player, cell.machine, data)
      end)

      local output_behavior = cell.output_inserter.get_or_create_control_behavior()
      local requester_section = cell.requester.get_logistic_point(0).sections[1]
      local requests = request_map(requester_section)

      f:expect(cell.storage.storage_filter.name, "transport-belt")
      f:expect(output_behavior.logistic_condition.constant, 9)
      f:expect(requests["iron-plate"], 5)
      f:expect(requests["iron-gear-wheel"], 5)
    end,
  },

  fluid_recipe_setup = {
    test = function(f, context)
      local cell = create_fluid_recipe_cell(context.game.surfaces[1])

      f:expect(cell.plant.valid, true)
      f:expect(cell.plant.get_recipe().name, "sulfuric-acid")
      f:expect(cell.storage.valid, true)
    end,
  },

  copy_settings_ignores_fluid_outputs = {
    from = "fluid_recipe_setup",
    test = function(f, context)
      local cell = fluid_recipe_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.plant)
      local ingredients = ingredient_map(data.ingredients)

      f:expect(data.item == nil, true)
      f:expect(data.name == nil, true)
      f:expect(ingredients["iron-plate"].amount, 1)
      f:expect(ingredients["sulfur"].amount, 5)
      f:expect(ingredients["water"] == nil, true)
    end,
  },

  paste_to_storage_skips_fluid_outputs = {
    from = "fluid_recipe_setup",
    test = function(f, context)
      local cell = fluid_recipe_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.plant)

      lib.paste_settings(context.game, { index = 1 }, cell.storage, data)

      f:expect(cell.storage.storage_filter == nil, true)
    end,
  },
}
