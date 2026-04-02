local lib = require("src.lib")

local function request_map(section)
  local requests = {}
  for _, filter in ipairs(section.filters) do
    if filter.value and filter.value.name then
      requests[filter.value.name] = filter
    end
  end
  return requests
end

local function create_transport_belt_cell(surface)
  local machine = surface.create_entity({
    name = "assembling-machine-2",
    position = { x = 30.5, y = 0.5 },
    force = "player",
  })
  machine.set_recipe("transport-belt")

  local requester = surface.create_entity({
    name = "requester-chest",
    position = { x = 27.5, y = 0.5 },
    force = "player",
  })
  local buffer = surface.create_entity({
    name = "buffer-chest",
    position = { x = 27.5, y = 2.5 },
    force = "player",
  })
  local output_inserter = surface.create_entity({
    name = "fast-inserter",
    position = { x = 32.5, y = 0.5 },
    direction = defines.direction.west,
    force = "player",
  })
  local storage = surface.create_entity({
    name = "storage-chest",
    position = { x = 33.5, y = 0.5 },
    force = "player",
  })

  return {
    machine = machine,
    requester = requester,
    buffer = buffer,
    output_inserter = output_inserter,
    storage = storage,
  }
end

local function transport_belt_cell(surface)
  return {
    machine = surface.find_entity("assembling-machine-2", { x = 30.5, y = 0.5 }),
    requester = surface.find_entity("requester-chest", { x = 27.5, y = 0.5 }),
    buffer = surface.find_entity("buffer-chest", { x = 27.5, y = 2.5 }),
    output_inserter = surface.find_entity("fast-inserter", { x = 32.5, y = 0.5 }),
    storage = surface.find_entity("storage-chest", { x = 33.5, y = 0.5 }),
  }
end

return {
  setup = {
    test = function(f, context)
      local cell = create_transport_belt_cell(context.game.surfaces[1])

      f:expect(cell.machine.valid, true)
      f:expect(cell.machine.get_recipe().name, "transport-belt")
      f:expect(cell.requester.valid, true)
      f:expect(cell.buffer.valid, true)
      f:expect(cell.output_inserter.valid, true)
      f:expect(cell.storage.valid, true)
    end,
  },

  requester_second_paste_reuses_section = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-request-size-type"] = "items",
        ["paste-logistic-settings-continued-request-size"] = 7,
      }, function(player)
        lib.paste_settings(context.game, player, cell.requester, data)
        lib.paste_settings(context.game, player, cell.requester, data)
      end)

      local point = cell.requester.get_logistic_point(0)
      local section = point.sections[1]
      local requests = request_map(section)

      f:expect(point.sections_count, 1)
      f:expect(requests["iron-plate"].min, 7)
      f:expect(requests["iron-gear-wheel"].min, 7)
    end,
  },

  buffer_chest_accepts_requests = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-request-size-type"] = "items",
        ["paste-logistic-settings-continued-request-size"] = 11,
      }, function(player)
        lib.paste_settings(context.game, player, cell.buffer, data)
      end)

      local point = cell.buffer.get_logistic_point(0)
      local section = point.sections[1]
      local requests = request_map(section)

      f:expect(point.sections_count, 1)
      f:expect(requests["iron-plate"].min, 11)
      f:expect(requests["iron-gear-wheel"].min, 11)
    end,
  },

  named_request_sections_are_preserved = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local point = cell.requester.get_logistic_point(0)
      local preserved = point.add_section()
      preserved.group = "Keep me"
      preserved.set_slot(1, {
        value = { name = "copper-plate", quality = "normal" },
        mode = "at-least",
        min = 3,
      })

      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-request-size-type"] = "items",
        ["paste-logistic-settings-continued-request-size"] = 5,
      }, function(player)
        lib.paste_settings(context.game, player, cell.requester, data)
      end)

      local kept_section = point.sections[1]
      local pasted_section = point.sections[2]
      local requests = request_map(pasted_section)

      f:expect(point.sections_count, 2)
      f:expect(kept_section.group, "Keep me")
      f:expect(kept_section.filters[1].value.name, "copper-plate")
      f:expect(pasted_section.group, "")
      f:expect(requests["iron-plate"].min, 5)
      f:expect(requests["iron-gear-wheel"].min, 5)
    end,
  },

  fluid_ingredients_paste_to_requester_without_duplication = {
    from = "setup",
    test = function(f, context)
      local requester = transport_belt_cell(context.game.surfaces[1]).requester
      local data = {
        ingredients = {
          { name = "iron-plate", amount = 1, quality = 1 },
          { name = "sulfur", amount = 5, quality = 1 },
          { name = "water", amount = 100, quality = 1 },
        },
      }

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-request-size-type"] = "items",
        ["paste-logistic-settings-continued-request-size"] = 6,
      }, function(player)
        lib.paste_settings(context.game, player, requester, data)
        lib.paste_settings(context.game, player, requester, data)
      end)

      local point = requester.get_logistic_point(0)
      local section = point.sections[1]
      local requests = request_map(section)

      f:expect(point.sections_count, 1)
      f:expect(requests["iron-plate"].min, 6)
      f:expect(requests["sulfur"].min, 6)
      f:expect(requests["water"] == nil, true)
    end,
  },

  repeated_inserter_paste_accumulates_limit = {
    from = "setup",
    test = function(f, context)
      local cell = transport_belt_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.machine)

      f:with_player_settings(context.player, {
        ["paste-logistic-settings-continued-output-limit-type"] = "stacks",
        ["paste-logistic-settings-continued-output-limit"] = 1,
      }, function(player)
        lib.paste_settings(context.game, player, cell.output_inserter, data)
        lib.paste_settings(context.game, player, cell.output_inserter, data)
      end)

      local condition = cell.output_inserter.get_or_create_control_behavior().logistic_condition

      f:expect(condition.constant, 200)
    end,
  },
}
