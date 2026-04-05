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

local function find_ghost_in_area(surface, inner_name, area)
  local entities = surface.find_entities_filtered({
    area = area,
    name = "entity-ghost",
  })

  for _, entity in ipairs(entities) do
    if entity.ghost_name == inner_name then
      return entity
    end
  end
end

local function find_ghost(surface, inner_name, position)
  local entities = surface.find_entities_filtered({
    area = {
      { position.x - 0.1, position.y - 0.1 },
      { position.x + 0.1, position.y + 0.1 },
    },
    name = "entity-ghost",
  })

  for _, entity in ipairs(entities) do
    if entity.ghost_name == inner_name then
      return entity
    end
  end
end

local function condition_signal_name(condition)
  local first_signal = condition and condition.first_signal
  local signal = first_signal and (first_signal.signal or first_signal)
  return signal and signal.name or nil
end

local function face_area(machine, face)
  if face == "north" then
    return {
      { machine.position.x - 2, machine.position.y - 4 },
      { machine.position.x + 2, machine.position.y - 1 },
    }
  elseif face == "south" then
    return {
      { machine.position.x - 2, machine.position.y + 1 },
      { machine.position.x + 2, machine.position.y + 4 },
    }
  elseif face == "east" then
    return {
      { machine.position.x + 1, machine.position.y - 2 },
      { machine.position.x + 4, machine.position.y + 2 },
    }
  end

  return {
    { machine.position.x - 4, machine.position.y - 2 },
    { machine.position.x - 1, machine.position.y + 2 },
  }
end

local function clear_area(surface, area)
  local entities = surface.find_entities_filtered({ area = area })
  for _, entity in ipairs(entities) do
    if entity.valid and entity.force and entity.force.name ~= "player" then
      entity.destroy()
    elseif entity.valid and entity.force == nil then
      entity.destroy()
    end
  end
end

local function create_empty_transport_belt_machine(surface, position)
  clear_area(surface, {
    { position.x - 5, position.y - 5 },
    { position.x + 5, position.y + 5 },
  })
  local machine = surface.create_entity({
    name = "assembling-machine-2",
    position = position,
    force = "player",
  })
  machine.set_recipe("transport-belt")
  return machine
end

local function normalize_expected_inserter(name)
  if name == "stack-inserter" then
    return "bulk-inserter"
  end
  return name
end

local function run_autoplace(f, context, position, overrides)
  local surface = context.game.surfaces[1]
  local machine = create_empty_transport_belt_machine(surface, position)
  local data = lib.copy_settings(context.game, { index = 1 }, machine)
  local settings = {
    ["paste-logistic-settings-continued-enable-ghost-placement"] = true,
    ["paste-logistic-settings-continued-ghost-direction"] = "south",
    ["paste-logistic-settings-continued-ghost-input-inserter"] = "bulk-inserter",
    ["paste-logistic-settings-continued-ghost-output-inserter"] = "fast-inserter",
    ["paste-logistic-settings-continued-ghost-output-chest"] = "storage-chest",
    ["paste-logistic-settings-continued-output-limit-type"] = "items",
    ["paste-logistic-settings-continued-output-limit"] = 9,
    ["paste-logistic-settings-continued-request-size-type"] = "items",
    ["paste-logistic-settings-continued-request-size"] = 5,
  }

  for key, value in pairs(overrides or {}) do
    settings[key] = value
  end

  f:with_player_settings(context.player, settings, function(player)
    lib.autoconfigure_settings(context.game, player, machine, data)
  end)

  return surface, machine, data
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

  places_ghosts_on_all_cardinal_faces = {
    from = "setup",
    test = function(f, context)
      local directions = {
        {
          face = "north",
          position = { x = 40.5, y = 0.5 },
          input_dir = defines.direction.north,
          output_dir = defines.direction.south,
        },
        {
          face = "east",
          position = { x = 60.5, y = 0.5 },
          input_dir = defines.direction.east,
          output_dir = defines.direction.west,
        },
        {
          face = "south",
          position = { x = 80.5, y = 0.5 },
          input_dir = defines.direction.south,
          output_dir = defines.direction.north,
        },
        {
          face = "west",
          position = { x = 100.5, y = 0.5 },
          input_dir = defines.direction.west,
          output_dir = defines.direction.east,
        },
      }

      for _, case in ipairs(directions) do
        local surface, machine = run_autoplace(f, context, case.position, {
          ["paste-logistic-settings-continued-ghost-direction"] = case.face,
        })
        local area = face_area(machine, case.face)
        local requester = find_ghost_in_area(surface, "requester-chest", area)
        local input_inserter = find_ghost_in_area(surface, "bulk-inserter", area)
        local output_inserter = find_ghost_in_area(surface, "fast-inserter", area)
        local output_chest = find_ghost_in_area(surface, "storage-chest", area)

        f:expect(requester.valid, true)
        f:expect(input_inserter.valid, true)
        f:expect(input_inserter.direction, case.input_dir)
        f:expect(output_inserter.valid, true)
        f:expect(output_inserter.direction, case.output_dir)
        f:expect(output_chest.valid, true)

        if case.face == "north" then
          f:expect(requester.position.y < machine.position.y, true)
          f:expect(output_chest.position.y < machine.position.y, true)
        elseif case.face == "south" then
          f:expect(requester.position.y > machine.position.y, true)
          f:expect(output_chest.position.y > machine.position.y, true)
        elseif case.face == "east" then
          f:expect(requester.position.x > machine.position.x, true)
          f:expect(output_chest.position.x > machine.position.x, true)
        else
          f:expect(requester.position.x < machine.position.x, true)
          f:expect(output_chest.position.x < machine.position.x, true)
        end
      end
    end,
  },

  supports_all_input_inserter_options = {
    from = "setup",
    test = function(f, context)
      local input_inserters = {
        "burner-inserter",
        "inserter",
        "fast-inserter",
        "long-handed-inserter",
        "stack-inserter",
        "bulk-inserter",
      }

      for index, inserter_name in ipairs(input_inserters) do
        local surface, machine = run_autoplace(f, context, { x = 140.5 + (index * 20), y = 0.5 }, {
          ["paste-logistic-settings-continued-ghost-direction"] = "south",
          ["paste-logistic-settings-continued-ghost-input-inserter"] = inserter_name,
        })
        local area = face_area(machine, "south")
        local input_inserter = find_ghost_in_area(surface, normalize_expected_inserter(inserter_name), area)

        f:expect(input_inserter.valid, true)
        f:expect(input_inserter.direction, defines.direction.south)
      end
    end,
  },

  supports_all_output_inserter_options = {
    from = "setup",
    test = function(f, context)
      local output_inserters = {
        "burner-inserter",
        "inserter",
        "fast-inserter",
        "long-handed-inserter",
        "stack-inserter",
        "bulk-inserter",
      }

      for index, inserter_name in ipairs(output_inserters) do
        local surface, machine = run_autoplace(f, context, { x = 300.5 + (index * 20), y = 0.5 }, {
          ["paste-logistic-settings-continued-ghost-direction"] = "south",
          ["paste-logistic-settings-continued-ghost-output-inserter"] = inserter_name,
          ["paste-logistic-settings-continued-output-limit"] = 11,
        })
        local output_inserter = find_ghost(surface, normalize_expected_inserter(inserter_name), {
          x = machine.position.x,
          y = machine.position.y + 2,
        })
        local condition = output_inserter.get_or_create_control_behavior().logistic_condition

        f:expect(output_inserter.valid, true)
        f:expect(output_inserter.direction, defines.direction.north)
        f:expect(condition_signal_name(condition), "transport-belt")
        f:expect(condition.constant, 11)
      end
    end,
  },

  supports_all_output_chest_options = {
    from = "setup",
    test = function(f, context)
      local output_chests = {
        "storage-chest",
        "passive-provider-chest",
        "active-provider-chest",
      }

      for index, chest_name in ipairs(output_chests) do
        local position = { x = 460.5 + (index * 20), y = 0.5 }
        local surface = context.game.surfaces[1]
        local machine
        local output_chest

        if chest_name == "storage-chest" then
          machine = create_empty_transport_belt_machine(surface, position)
          surface.create_entity({
            name = "requester-chest",
            position = { x = position.x - 1, y = position.y + 3 },
            force = "player",
          })
          output_chest = surface.create_entity({
            name = "storage-chest",
            position = { x = position.x, y = position.y + 3 },
            force = "player",
          })
          local data = lib.copy_settings(context.game, { index = 1 }, machine)

          f:with_player_settings(context.player, {
            ["paste-logistic-settings-continued-enable-ghost-placement"] = true,
            ["paste-logistic-settings-continued-ghost-direction"] = "south",
            ["paste-logistic-settings-continued-ghost-input-inserter"] = "bulk-inserter",
            ["paste-logistic-settings-continued-ghost-output-inserter"] = "fast-inserter",
            ["paste-logistic-settings-continued-ghost-output-chest"] = chest_name,
            ["paste-logistic-settings-continued-output-limit-type"] = "items",
            ["paste-logistic-settings-continued-output-limit"] = 9,
            ["paste-logistic-settings-continued-request-size-type"] = "items",
            ["paste-logistic-settings-continued-request-size"] = 5,
          }, function(player)
            lib.autoconfigure_settings(context.game, player, machine, data)
          end)

          f:expect(output_chest.storage_filter.name, prototypes.item["transport-belt"])
        else
          surface, machine = run_autoplace(f, context, position, {
            ["paste-logistic-settings-continued-ghost-direction"] = "south",
            ["paste-logistic-settings-continued-ghost-output-chest"] = chest_name,
          })
          local area = face_area(machine, "south")
          output_chest = find_ghost_in_area(surface, chest_name, area)
          f:expect(output_chest.valid, true)
        end
      end
    end,
  },
}
