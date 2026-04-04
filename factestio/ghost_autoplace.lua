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

local function find_ghost(surface, inner_name, position)
  local entities = surface.find_entities_filtered({
    area = {
      { position.x - 0.1, position.y - 0.1 },
      { position.x + 0.1, position.y + 0.1 },
    },
  })

  for _, entity in ipairs(entities) do
    if entity.name == "entity-ghost" and entity.ghost_name == inner_name then
      return entity
    end
  end
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
    { position.x - 4, position.y - 4 },
    { position.x + 4, position.y + 4 },
  })
  local machine = surface.create_entity({
    name = "assembling-machine-2",
    position = position,
    force = "player",
  })
  machine.set_recipe("transport-belt")
  return machine
end

return {
  setup = {
    test = function(f, context)
      local surface = context.game.surfaces[1]
      f:expect(surface.valid, true)
    end,
  },

  places_missing_ghosts_on_configured_face = {
    from = "setup",
    test = function(f, context)
      local surface = context.game.surfaces[1]
      local machine = create_empty_transport_belt_machine(surface, { x = 40.5, y = 0.5 })
      local data = lib.copy_settings(context.game, { index = 1 }, machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-enable-ghost-placement"] = true,
        ["paste-logistic-settings-continued-ghost-direction"] = "south",
        ["paste-logistic-settings-continued-ghost-input-inserter"] = "bulk-inserter",
        ["paste-logistic-settings-continued-ghost-output-inserter"] = "fast-inserter",
        ["paste-logistic-settings-continued-ghost-output-chest"] = "storage-chest",
        ["paste-logistic-settings-continued-output-limit-type"] = "items",
        ["paste-logistic-settings-continued-output-limit"] = 9,
        ["paste-logistic-settings-continued-request-size-type"] = "items",
        ["paste-logistic-settings-continued-request-size"] = 5,
      }, function(player)
        lib.autoconfigure_settings(context.game, player, machine, data)
      end)

      local south_face_area = {
        { 38.5, 1.5 },
        { 42.5, 4.5 },
      }
      local requester = find_ghost_in_area(surface, "requester-chest", south_face_area)
      local input_inserter = find_ghost_in_area(surface, "bulk-inserter", south_face_area)
      local output_inserter = find_ghost_in_area(surface, "fast-inserter", south_face_area)
      local storage = find_ghost_in_area(surface, "storage-chest", south_face_area)
      local requests = request_map(requester.get_logistic_point(0).sections[1])
      local output_condition = output_inserter.get_or_create_control_behavior().logistic_condition

      f:expect(requester.valid, true)
      f:expect(requester.position.y > machine.position.y, true)
      f:expect(input_inserter.valid, true)
      f:expect(input_inserter.direction, defines.direction.south)
      f:expect(input_inserter.position.y > machine.position.y, true)
      f:expect(output_inserter.valid, true)
      f:expect(output_inserter.direction, defines.direction.north)
      f:expect(output_inserter.position.y > machine.position.y, true)
      f:expect(storage.valid, true)
      f:expect(storage.position.y > machine.position.y, true)
      f:expect(requests["iron-plate"], 5)
      f:expect(requests["iron-gear-wheel"], 5)
      f:expect(output_condition.constant, 9)
    end,
  },

  fills_only_missing_ghosts_in_partial_layout = {
    from = "setup",
    test = function(f, context)
      local surface = context.game.surfaces[1]
      local machine = create_empty_transport_belt_machine(surface, { x = 50.5, y = 0.5 })
      local requester = surface.create_entity({
        name = "requester-chest",
        position = { x = 49.5, y = 3.5 },
        force = "player",
      })
      local data = lib.copy_settings(context.game, { index = 1 }, machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-enable-ghost-placement"] = true,
        ["paste-logistic-settings-continued-ghost-direction"] = "south",
        ["paste-logistic-settings-continued-ghost-input-inserter"] = "bulk-inserter",
        ["paste-logistic-settings-continued-ghost-output-inserter"] = "fast-inserter",
        ["paste-logistic-settings-continued-ghost-output-chest"] = "storage-chest",
        ["paste-logistic-settings-continued-output-limit-type"] = "items",
        ["paste-logistic-settings-continued-output-limit"] = 9,
        ["paste-logistic-settings-continued-request-size-type"] = "items",
        ["paste-logistic-settings-continued-request-size"] = 5,
      }, function(player)
        lib.autoconfigure_settings(context.game, player, machine, data)
      end)

      local south_face_area = {
        { 48.5, 1.5 },
        { 52.5, 4.5 },
      }
      local input_inserter = find_ghost_in_area(surface, "bulk-inserter", south_face_area)
      local output_inserter = find_ghost_in_area(surface, "fast-inserter", south_face_area)
      local output_chest = find_ghost_in_area(surface, "storage-chest", south_face_area)
      local requests = request_map(requester.get_logistic_point(0).sections[1])
      local output_condition = output_inserter.get_or_create_control_behavior().logistic_condition

      f:expect(requester.valid, true)
      f:expect(find_ghost(surface, "requester-chest", { x = 49.5, y = 3.5 }) == nil, true)
      f:expect(input_inserter.valid, true)
      f:expect(output_inserter.valid, true)
      f:expect(output_chest.valid, true)
      f:expect(requests["iron-plate"], 5)
      f:expect(requests["iron-gear-wheel"], 5)
      f:expect(output_condition.constant, 9)
    end,
  },

  output_chest_setting_controls_ghost_type = {
    from = "setup",
    test = function(f, context)
      local surface = context.game.surfaces[1]
      local machine = create_empty_transport_belt_machine(surface, { x = 60.5, y = 0.5 })
      local requester = surface.create_entity({
        name = "requester-chest",
        position = { x = 59.5, y = 3.5 },
        force = "player",
      })
      local data = lib.copy_settings(context.game, { index = 1 }, machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-enable-ghost-placement"] = true,
        ["paste-logistic-settings-continued-ghost-direction"] = "south",
        ["paste-logistic-settings-continued-ghost-input-inserter"] = "bulk-inserter",
        ["paste-logistic-settings-continued-ghost-output-inserter"] = "fast-inserter",
        ["paste-logistic-settings-continued-ghost-output-chest"] = "active-provider-chest",
        ["paste-logistic-settings-continued-output-limit-type"] = "items",
        ["paste-logistic-settings-continued-output-limit"] = 9,
        ["paste-logistic-settings-continued-request-size-type"] = "items",
        ["paste-logistic-settings-continued-request-size"] = 5,
      }, function(player)
        lib.autoconfigure_settings(context.game, player, machine, data)
      end)

      local south_face_area = {
        { 58.5, 1.5 },
        { 62.5, 4.5 },
      }
      local output_chest = find_ghost_in_area(surface, "active-provider-chest", south_face_area)
      local requests = request_map(requester.get_logistic_point(0).sections[1])

      f:expect(output_chest.valid, true)
      f:expect(requests["iron-plate"], 5)
      f:expect(requests["iron-gear-wheel"], 5)
    end,
  },
}
