local Support = require("spec.support")
local lib = require("src.lib")

describe("lib", function()
  local restore_globals

  before_each(function()
    restore_globals = Support.with_mocked_factorio_globals()
  end)

  after_each(function()
    restore_globals()
  end)

  it("apply_inserter_settings configures a matching logistic condition", function()
    local behavior = {}
    local inserter = {
      get_or_create_control_behavior = function()
        return behavior
      end,
    }

    lib.apply_inserter_settings(nil, { index = 1 }, inserter, {
      item = true,
      name = "transport-belt",
      quality = 2,
    })

    assert.is_true(behavior.connect_to_logistic_network)
    assert.same({
      comparator = "<",
      first_signal = { type = "item", name = "transport-belt", quality = "rare" },
      constant = 13,
    }, behavior.logistic_condition)
  end)

  it("apply_inserter_settings accumulates matching existing limits", function()
    local behavior = {
      logistic_condition = {
        comparator = "<",
        first_signal = { name = "transport-belt" },
        constant = 9,
      },
    }
    local inserter = {
      get_or_create_control_behavior = function()
        return behavior
      end,
    }

    lib.apply_inserter_settings(nil, { index = 1 }, inserter, {
      item = true,
      name = "transport-belt",
      quality = 1,
    })

    assert.equal(22, behavior.logistic_condition.constant)
  end)

  it("apply_inserter_settings replaces matching existing limits when accumulation is disabled", function()
    _G.settings = Support.make_settings({
      ["paste-logistic-settings-continued-output-limit-type"] = { value = "items" },
      ["paste-logistic-settings-continued-output-limit"] = { value = 13 },
      ["paste-logistic-settings-continued-accumulate-inserter-output-limit"] = { value = false },
      ["paste-logistic-settings-continued-request-size-type"] = { value = "items" },
      ["paste-logistic-settings-continued-request-size"] = { value = 7 },
    })

    local behavior = {
      logistic_condition = {
        comparator = "<",
        first_signal = { name = "transport-belt" },
        constant = 9,
      },
    }
    local inserter = {
      get_or_create_control_behavior = function()
        return behavior
      end,
    }

    lib.apply_inserter_settings(nil, { index = 1 }, inserter, {
      item = true,
      name = "transport-belt",
      quality = 1,
    })

    assert.equal(13, behavior.logistic_condition.constant)
  end)

  -- Floating text for the applied output limit ------------------------------

  -- Builds an inserter feeding a chest, with settings tuned so the limit lands
  -- on a round "1 stack / 100 items" for legibility.
  local function make_output_limit_fixture(overrides)
    local values = {
      ["paste-logistic-settings-continued-output-limit-type"] = { value = "stacks" },
      ["paste-logistic-settings-continued-output-limit"] = { value = 1 },
      ["paste-logistic-settings-continued-accumulate-inserter-output-limit"] = { value = false },
      ["paste-logistic-settings-continued-show-output-limit-text"] = { value = true },
      ["paste-logistic-settings-continued-output-limit-text-stacks"] = { value = true },
      ["paste-logistic-settings-continued-output-limit-text-items"] = { value = true },
    }
    for key, value in pairs(overrides or {}) do
      values[key] = { value = value }
    end
    _G.settings = Support.make_settings(values)

    local shown = {}
    local chest = {
      valid = true,
      type = "logistic-container",
      position = { x = 5, y = 6 },
      surface = "nauvis",
    }
    local inserter = {
      valid = true,
      type = "inserter",
      position = { x = 1, y = 2 },
      surface = "nauvis",
      drop_target = chest,
      get_or_create_control_behavior = function()
        return {}
      end,
    }
    local player = {
      index = 1,
      create_local_flying_text = function(params)
        shown[#shown + 1] = params
      end,
    }

    return {
      shown = shown,
      chest = chest,
      inserter = inserter,
      player = player,
      paste = function()
        lib.apply_inserter_settings(nil, player, inserter, {
          item = true,
          name = "transport-belt",
          quality = 0,
        })
      end,
    }
  end

  it("shows the output limit as floating text over the chest the inserter feeds", function()
    local fixture = make_output_limit_fixture()

    fixture.paste()

    assert.equal(1, #fixture.shown)
    local shown = fixture.shown[1]
    -- Over the chest, not the inserter and not the player.
    assert.same({ x = 5, y = 6 }, shown.position)
    assert.equal("nauvis", shown.surface)
    assert.same({
      "",
      { "floating-text.paste-logistic-settings-continued-stacks", "1" },
      " / ",
      "100x [item=transport-belt]",
    }, shown.text)
  end)

  it("leaves speed and time_to_live unset so Factorio can pace long text", function()
    local fixture = make_output_limit_fixture()

    fixture.paste()

    assert.is_nil(fixture.shown[1].speed)
    assert.is_nil(fixture.shown[1].time_to_live)
  end)

  it("anchors the floating text to the inserter when it does not feed a chest", function()
    local fixture = make_output_limit_fixture()
    fixture.inserter.drop_target = { valid = true, type = "transport-belt", position = { x = 9, y = 9 } }

    fixture.paste()

    assert.equal(1, #fixture.shown)
    assert.same({ x = 1, y = 2 }, fixture.shown[1].position)
  end)

  it("shows no floating text when the feature is disabled", function()
    local fixture = make_output_limit_fixture({
      ["paste-logistic-settings-continued-show-output-limit-text"] = false,
    })

    fixture.paste()

    assert.equal(0, #fixture.shown)
  end)

  it("shows only the stack half when items are disabled", function()
    local fixture = make_output_limit_fixture({
      ["paste-logistic-settings-continued-output-limit-text-items"] = false,
    })

    fixture.paste()

    assert.same({ "floating-text.paste-logistic-settings-continued-stacks", "1" }, fixture.shown[1].text)
  end)

  it("shows only the item half when stacks are disabled", function()
    local fixture = make_output_limit_fixture({
      ["paste-logistic-settings-continued-output-limit-text-stacks"] = false,
    })

    fixture.paste()

    assert.same("100x [item=transport-belt]", fixture.shown[1].text)
  end)

  it("shows no floating text when both halves are disabled", function()
    local fixture = make_output_limit_fixture({
      ["paste-logistic-settings-continued-output-limit-text-stacks"] = false,
      ["paste-logistic-settings-continued-output-limit-text-items"] = false,
    })

    fixture.paste()

    assert.equal(0, #fixture.shown)
  end)

  it("reports the accumulated total rather than the increment", function()
    local fixture = make_output_limit_fixture({
      ["paste-logistic-settings-continued-accumulate-inserter-output-limit"] = true,
    })
    fixture.inserter.get_or_create_control_behavior = function()
      return {
        logistic_condition = {
          comparator = "<",
          first_signal = { name = "transport-belt" },
          constant = 100,
        },
      }
    end

    fixture.paste()

    assert.same({
      "",
      { "floating-text.paste-logistic-settings-continued-stacks", "2" },
      " / ",
      "200x [item=transport-belt]",
    }, fixture.shown[1].text)
  end)

  it("stays quiet for ghost inserters", function()
    local fixture = make_output_limit_fixture()
    fixture.inserter.type = "entity-ghost"
    fixture.inserter.ghost_type = "inserter"
    fixture.inserter.ghost_name = "fast-inserter"
    fixture.inserter.ghost_prototype = {}

    fixture.paste()

    assert.equal(0, #fixture.shown)
  end)

  it("apply_inserter_settings defaults missing accumulation setting to enabled", function()
    _G.settings = Support.make_settings({
      ["paste-logistic-settings-continued-output-limit-type"] = { value = "items" },
      ["paste-logistic-settings-continued-output-limit"] = { value = 13 },
      ["paste-logistic-settings-continued-request-size-type"] = { value = "items" },
      ["paste-logistic-settings-continued-request-size"] = { value = 7 },
    })

    local behavior = {
      logistic_condition = {
        comparator = "<",
        first_signal = { name = "transport-belt" },
        constant = 9,
      },
    }
    local inserter = {
      get_or_create_control_behavior = function()
        return behavior
      end,
    }

    lib.apply_inserter_settings(nil, { index = 1 }, inserter, {
      item = true,
      name = "transport-belt",
      quality = 1,
    })

    assert.equal(22, behavior.logistic_condition.constant)
  end)

  it("apply_inserter_settings does not accumulate non-matching conditions", function()
    local behavior = {
      logistic_condition = {
        comparator = "=",
        first_signal = { name = "transport-belt" },
        constant = 9,
      },
    }
    local inserter = {
      get_or_create_control_behavior = function()
        return behavior
      end,
    }

    lib.apply_inserter_settings(nil, { index = 1 }, inserter, {
      item = true,
      name = "transport-belt",
      quality = 1,
    })

    assert.equal(13, behavior.logistic_condition.constant)
  end)

  it("apply_inserter_settings no-ops for unsupported data", function()
    local behavior = {}
    local inserter = {
      get_or_create_control_behavior = function()
        return behavior
      end,
    }

    lib.apply_inserter_settings(nil, { index = 1 }, inserter, nil)
    assert.is_nil(behavior.logistic_condition)

    lib.apply_inserter_settings(nil, { index = 1 }, inserter, { item = false, name = "water" })
    assert.is_nil(behavior.logistic_condition)

    lib.apply_inserter_settings(nil, { index = 1 }, inserter, { item = true, name = "water" })
    assert.is_nil(behavior.logistic_condition)
  end)

  it("get_ghost_placement_layout places adjacent inserters on the configured face", function()
    local machine = {
      valid = true,
      position = { x = 10.5, y = 20.5 },
      prototype = { tile_width = 3, tile_height = 3 },
    }

    local layout = lib.get_ghost_placement_layout(machine, {
      face = "south",
      input_inserter = "bulk-inserter",
      output_inserter = "fast-inserter",
      output_chest = "storage-chest",
    })

    assert.same({
      role = "input_chest",
      name = "requester-chest",
      position = { x = 9.5, y = 23.5 },
    }, layout[1])
    assert.same({
      role = "input_inserter",
      name = "bulk-inserter",
      position = { x = 9.5, y = 22.5 },
      direction = defines.direction.south,
    }, layout[2])
    assert.same({
      role = "output_inserter",
      name = "fast-inserter",
      position = { x = 10.5, y = 22.5 },
      direction = defines.direction.north,
    }, layout[3])
    assert.same({
      role = "output_chest",
      name = "storage-chest",
      position = { x = 10.5, y = 23.5 },
    }, layout[4])
  end)

  it("ensure_ghost_layout fills only missing slots and configures compatible entities", function()
    local calls = {}
    local created = {}
    local original_paste_settings = lib.paste_settings
    local requester = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "requester" },
    }
    local surface = {
      find_entities_filtered = function(params)
        if params.position.x == 9.5 and params.position.y == 23.5 then
          return { requester }
        end
        return {}
      end,
      create_entity = function(params)
        local entity = {
          valid = true,
          name = "entity-ghost",
          type = "entity-ghost",
          ghost_name = params.inner_name,
          ghost_type = params.inner_name:find("inserter") and "inserter" or "logistic-container",
          ghost_prototype = params.inner_name == "storage-chest" and { logistic_mode = "storage" }
            or params.inner_name == "requester-chest" and { logistic_mode = "requester" }
            or {},
          direction = params.direction,
          position = params.position,
        }
        table.insert(created, params)
        return entity
      end,
    }
    local machine = {
      valid = true,
      position = { x = 10.5, y = 20.5 },
      force = "player",
      prototype = { tile_width = 3, tile_height = 3 },
      surface = surface,
    }
    local player = { index = 1 }
    _G.settings = Support.make_settings({
      ["paste-logistic-settings-continued-output-limit-type"] = { value = "items" },
      ["paste-logistic-settings-continued-output-limit"] = { value = 13 },
      ["paste-logistic-settings-continued-accumulate-inserter-output-limit"] = { value = true },
      ["paste-logistic-settings-continued-request-size-type"] = { value = "items" },
      ["paste-logistic-settings-continued-request-size"] = { value = 7 },
      ["paste-logistic-settings-continued-enable-ghost-placement"] = { value = true },
      ["paste-logistic-settings-continued-ghost-direction"] = { value = "south" },
      ["paste-logistic-settings-continued-ghost-input-inserter"] = { value = "bulk-inserter" },
      ["paste-logistic-settings-continued-ghost-output-inserter"] = { value = "fast-inserter" },
      ["paste-logistic-settings-continued-ghost-output-chest"] = { value = "storage-chest" },
    })

    lib.paste_settings = function(_, _, entity)
      table.insert(calls, entity)
    end

    local processed = lib.ensure_ghost_layout(nil, player, machine, { item = true, name = "transport-belt" })

    lib.paste_settings = original_paste_settings

    assert.equal(3, #created)
    assert.equal("bulk-inserter", created[1].inner_name)
    assert.equal("fast-inserter", created[2].inner_name)
    assert.equal("storage-chest", created[3].inner_name)
    assert.same({
      requester,
      {
        valid = true,
        name = "entity-ghost",
        type = "entity-ghost",
        ghost_name = "fast-inserter",
        ghost_type = "inserter",
        ghost_prototype = {},
        direction = defines.direction.north,
        position = { x = 10.5, y = 22.5 },
      },
      {
        valid = true,
        name = "entity-ghost",
        type = "entity-ghost",
        ghost_name = "storage-chest",
        ghost_type = "logistic-container",
        ghost_prototype = { logistic_mode = "storage" },
        position = { x = 10.5, y = 23.5 },
      },
    }, calls)
    assert.is_nil(processed[requester])
  end)

  it("ensure_ghost_layout does not reconfigure a placed requester ghost through paste_settings", function()
    local calls = {}
    local original_paste_settings = lib.paste_settings
    local surface = {
      find_entities_filtered = function()
        return {}
      end,
      create_entity = function(params)
        if params.name == "item-on-ground" then
          return {
            valid = false,
          }
        end
        return {
          valid = true,
          name = "entity-ghost",
          type = "entity-ghost",
          ghost_name = params.inner_name,
          ghost_type = params.inner_name:find("inserter") and "inserter" or "logistic-container",
          ghost_prototype = params.inner_name == "storage-chest" and { logistic_mode = "storage" }
            or params.inner_name == "requester-chest" and { logistic_mode = "requester" }
            or {},
          direction = params.direction,
          position = params.position,
        }
      end,
    }
    local machine = {
      valid = true,
      position = { x = 10.5, y = 20.5 },
      force = "player",
      prototype = { tile_width = 3, tile_height = 3 },
      surface = surface,
    }
    local player = { index = 1 }
    _G.settings = Support.make_settings({
      ["paste-logistic-settings-continued-output-limit-type"] = { value = "items" },
      ["paste-logistic-settings-continued-output-limit"] = { value = 13 },
      ["paste-logistic-settings-continued-accumulate-inserter-output-limit"] = { value = true },
      ["paste-logistic-settings-continued-request-size-type"] = { value = "items" },
      ["paste-logistic-settings-continued-request-size"] = { value = 7 },
      ["paste-logistic-settings-continued-enable-ghost-placement"] = { value = true },
      ["paste-logistic-settings-continued-ghost-direction"] = { value = "south" },
      ["paste-logistic-settings-continued-ghost-input-inserter"] = { value = "bulk-inserter" },
      ["paste-logistic-settings-continued-ghost-output-inserter"] = { value = "fast-inserter" },
      ["paste-logistic-settings-continued-ghost-output-chest"] = { value = "storage-chest" },
    })

    lib.paste_settings = function(_, _, entity)
      table.insert(calls, entity)
    end

    lib.ensure_ghost_layout(nil, player, machine, { item = true, name = "transport-belt" })

    lib.paste_settings = original_paste_settings

    assert.equal("fast-inserter", calls[1].ghost_name)
  end)

  it("apply_chest_settings configures storage filters and requester slots", function()
    local requester_section = Support.make_section("", {})
    local requester = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "requester" },
      get_logistic_point = function()
        return {
          sections_count = 1,
          sections = { requester_section },
          add_section = function()
            return requester_section
          end,
        }
      end,
    }
    local storage = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "storage" },
    }
    local data = {
      item = true,
      name = "transport-belt",
      quality = 1,
      ingredients = {
        { name = "iron-plate" },
        { name = "iron-gear-wheel" },
      },
    }

    lib.apply_chest_settings(nil, { index = 1 }, storage, data)
    lib.apply_chest_settings(nil, { index = 1 }, requester, data)

    assert.same({ name = "transport-belt", quality = "uncommon" }, storage.storage_filter)
    assert.equal("iron-plate", requester_section.filters[1].value.name)
    assert.equal("uncommon", requester_section.filters[1].value.quality)
    assert.equal(7, requester_section.filters[1].min)
    assert.equal("iron-gear-wheel", requester_section.filters[2].value.name)
  end)

  it("apply_chest_settings no-ops for unsupported data", function()
    local requester_section = Support.make_section("", {})
    local requester = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "requester" },
      get_logistic_point = function()
        return {
          sections_count = 1,
          sections = { requester_section },
          add_section = function()
            return requester_section
          end,
        }
      end,
    }
    local storage = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "storage" },
    }

    lib.apply_chest_settings(nil, { index = 1 }, storage, { item = false, name = "water" })
    lib.apply_chest_settings(nil, { index = 1 }, requester, {
      item = false,
      ingredients = {
        { name = "water" },
      },
    })

    assert.is_nil(storage.storage_filter)
    assert.same({}, requester_section.filters)
  end)

  it("paste_settings dispatches by target type", function()
    local calls = {}
    local original_apply_chest_settings = lib.apply_chest_settings
    local original_apply_inserter_settings = lib.apply_inserter_settings
    local chest_target = {
      valid = true,
      type = "entity-ghost",
      ghost_name = "requester-chest",
      ghost_type = "logistic-container",
      ghost_prototype = { logistic_mode = "requester" },
    }
    local inserter_target = {
      valid = true,
      type = "entity-ghost",
      ghost_name = "fast-inserter",
      ghost_type = "inserter",
      ghost_prototype = {},
    }

    lib.apply_chest_settings = function(_, _, target)
      table.insert(calls, { kind = "chest", target = target })
    end
    lib.apply_inserter_settings = function(_, _, target)
      table.insert(calls, { kind = "inserter", target = target })
    end

    lib.paste_settings(nil, nil, chest_target, {})
    lib.paste_settings(nil, nil, inserter_target, {})
    lib.paste_settings(nil, nil, { type = "lamp" }, {})

    lib.apply_chest_settings = original_apply_chest_settings
    lib.apply_inserter_settings = original_apply_inserter_settings

    assert.same({
      { kind = "chest", target = chest_target },
      { kind = "inserter", target = inserter_target },
    }, calls)
  end)

  it("autoconfigure_settings updates only correctly connected inserters and chests", function()
    local calls = {}
    local original_paste_settings = lib.paste_settings
    local requester = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "requester" },
    }
    local storage = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "storage" },
    }
    local target = {
      valid = true,
      force = "player",
      position = { x = 0, y = 0 },
      get_recipe = function()
        return { name = "transport-belt" }
      end,
      surface = {},
    }
    local input_inserter = {
      type = "inserter",
      pickup_target = requester,
      drop_target = target,
    }
    local output_inserter = {
      type = "inserter",
      pickup_target = target,
      drop_target = storage,
    }
    local unrelated_inserter = {
      pickup_target = { valid = true, type = "logistic-container", prototype = { logistic_mode = "passive-provider" } },
      drop_target = { valid = true, type = "lamp" },
    }
    target.surface.find_entities_filtered = function()
      return { input_inserter, output_inserter, unrelated_inserter }
    end

    lib.paste_settings = function(_, _, entity)
      table.insert(calls, entity)
    end

    lib.autoconfigure_settings(nil, { index = 1 }, target, { item = true, name = "transport-belt" })

    lib.paste_settings = original_paste_settings

    assert.same({ requester, output_inserter, storage }, calls)
  end)

  it("autoconfigure_settings includes ghost inserters and ghost storage targets", function()
    local calls = {}
    local original_paste_settings = lib.paste_settings
    local target = {
      valid = true,
      force = "player",
      position = { x = 0, y = 0 },
      get_recipe = function()
        return { name = "transport-belt" }
      end,
      surface = {},
    }
    local ghost_storage = {
      valid = true,
      type = "entity-ghost",
      ghost_type = "logistic-container",
      ghost_prototype = { logistic_mode = "storage" },
    }
    local ghost_output_inserter = {
      valid = true,
      type = "entity-ghost",
      ghost_type = "inserter",
      pickup_target = target,
      drop_target = ghost_storage,
    }
    target.surface.find_entities_filtered = function()
      return { ghost_output_inserter }
    end

    lib.paste_settings = function(_, _, entity)
      table.insert(calls, entity)
    end

    lib.autoconfigure_settings(nil, { index = 1 }, target, { item = true, name = "transport-belt" })

    lib.paste_settings = original_paste_settings

    assert.same({ ghost_output_inserter, ghost_storage }, calls)
  end)

  it("builds requester ghosts through a blueprint so request filters survive", function()
    local built = { valid = true, name = "entity-ghost" }
    local captured = {}
    local destroyed = false
    local stack = {
      set_stack = function() end,
      set_blueprint_entities = function(entities)
        captured.entities = entities
      end,
      is_blueprint_setup = function()
        return true
      end,
      build_blueprint = function(params)
        captured.build = params
        return { built }
      end,
    }
    local inventory = {
      valid = true,
      [1] = stack,
      destroy = function()
        destroyed = true
      end,
    }
    local game = {
      create_inventory = function()
        return inventory
      end,
    }
    local surface = {
      create_entity = function()
        error("fell back to a plain ghost instead of using the blueprint")
      end,
    }

    local entity = lib.create_ghost_entity(game, surface, "player", {
      role = "input_chest",
      name = "requester-chest",
      position = { x = 1, y = 2 },
    }, { index = 1 }, { ingredients = { { name = "iron-plate" } }, quality = 0 })

    assert.equal(built, entity)
    assert.is_true(destroyed)

    -- The filters are the whole point of the blueprint route: nothing else
    -- puts requests on a *ghost* requester, so losing this route loses them.
    local filters = captured.entities[1].request_filters.sections[1].filters
    assert.equal("iron-plate", filters[1].name)
    assert.equal("normal", filters[1].quality)
    assert.equal(7, filters[1].count)
  end)

  it("falls back to a plain ghost when the blueprint route fails", function()
    local created
    local game = {
      create_inventory = function()
        return nil
      end,
    }
    local surface = {
      create_entity = function(params)
        created = params
        return { valid = true }
      end,
    }

    lib.create_ghost_entity(game, surface, "player", {
      role = "input_chest",
      name = "requester-chest",
      position = { x = 1, y = 2 },
    }, { index = 1 }, { ingredients = { { name = "iron-plate" } } })

    -- Documented rather than desired: this ghost carries no request filters,
    -- and the fallback is silent. ghost_autoplace asserts on the filters
    -- in-game so a regression to this path fails loudly there.
    assert.equal("entity-ghost", created.name)
    assert.equal("requester-chest", created.inner_name)
  end)

  it("copy_settings returns nil without a recipe and filters fluid ingredients", function()
    local no_recipe_entity = {
      get_recipe = function()
        return nil
      end,
    }
    local recipe_entity = {
      get_recipe = function()
        return {
          products = {
            { name = "steam" },
            { name = "transport-belt" },
          },
          ingredients = {
            { name = "iron-plate", amount = 1 },
            { name = "water", amount = 10 },
          },
        }, { level = 3 }
      end,
    }

    assert.is_nil(lib.copy_settings(nil, nil, no_recipe_entity))

    local copied = lib.copy_settings(nil, nil, recipe_entity)
    assert.is_true(copied.item)
    assert.is_nil(copied.source_name)
    assert.is_nil(copied.source_type)
    assert.equal("transport-belt", copied.name)
    assert.equal(3, copied.quality)
    assert.same({
      { name = "iron-plate", amount = 1, stack_size = 100, quality = 3 },
    }, copied.ingredients)
  end)

  it("copy_settings stores effective source identity for ghost sources", function()
    local ghost_entity = {
      valid = true,
      name = "entity-ghost",
      type = "entity-ghost",
      prototype = {},
      ghost_name = "assembling-machine-2",
      ghost_type = "assembling-machine",
      ghost_prototype = {},
      get_recipe = function()
        return {
          products = {
            { name = "transport-belt" },
          },
          ingredients = {
            { name = "iron-plate", amount = 1 },
          },
        }, { level = 1 }
      end,
    }

    local copied = lib.copy_settings(nil, nil, ghost_entity)

    assert.equal("assembling-machine-2", copied.source_name)
    assert.equal("assembling-machine", copied.source_type)
  end)
end)
