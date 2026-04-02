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

local function create_transport_belt_cell(surface)
  local machine = surface.create_entity({
    name = "assembling-machine-2",
    position = { x = 20.5, y = 0.5 },
    force = "player",
  })
  machine.set_recipe("transport-belt")

  local requester = surface.create_entity({
    name = "requester-chest",
    position = { x = 17.5, y = 0.5 },
    force = "player",
  })
  local input_inserter = surface.create_entity({
    name = "fast-inserter",
    position = { x = 18.5, y = 0.5 },
    direction = defines.direction.west,
    force = "player",
  })
  local output_inserter = surface.create_entity({
    name = "fast-inserter",
    position = { x = 22.5, y = 0.5 },
    direction = defines.direction.west,
    force = "player",
  })
  local storage = surface.create_entity({
    name = "storage-chest",
    position = { x = 23.5, y = 0.5 },
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
    machine = surface.find_entity("assembling-machine-2", { x = 20.5, y = 0.5 }),
    requester = surface.find_entity("requester-chest", { x = 17.5, y = 0.5 }),
    input_inserter = surface.find_entity("fast-inserter", { x = 18.5, y = 0.5 }),
    output_inserter = surface.find_entity("fast-inserter", { x = 22.5, y = 0.5 }),
    storage = surface.find_entity("storage-chest", { x = 23.5, y = 0.5 }),
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
    end,
  },

  updates_connected_logistics = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-output-limit-type"] = "items",
        ["paste-logistic-settings-continued-output-limit"] = 9,
        ["paste-logistic-settings-continued-request-size-type"] = "items",
        ["paste-logistic-settings-continued-request-size"] = 5,
      }, function(player)
        lib.autoconfigure_settings(context.game, player, cell.machine, data)
      end)

      local output_behavior = cell.output_inserter.get_or_create_control_behavior()
      local requester_section = cell.requester.get_logistic_point(0).sections[1]
      local requests = request_map(requester_section)

      f:expect(cell.storage.storage_filter.name, prototypes.item["transport-belt"])
      f:expect(output_behavior.logistic_condition.constant, 9)
      f:expect(requests["iron-plate"], 5)
      f:expect(requests["iron-gear-wheel"], 5)
    end,
  },
}
