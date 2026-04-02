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

  it("has_same_ingredient_names ignores order but rejects mismatches", function()
    local filters = {
      { value = { name = "iron-gear-wheel" } },
      { value = { name = "iron-plate" } },
    }
    local ingredients = {
      { name = "iron-plate" },
      { name = "iron-gear-wheel" },
    }

    assert.is_true(lib.has_same_ingredient_names(nil, nil, filters, ingredients))
    assert.is_false(lib.has_same_ingredient_names(nil, nil, filters, { { name = "iron-plate" } }))
  end)

  it("get_or_create_section reuses the single blank unnamed section", function()
    local blank = Support.make_section("", {})
    local point = {
      sections_count = 1,
      sections = { blank },
      add_section = function()
        error("should not add a new section")
      end,
    }
    local entity = {
      get_logistic_point = function()
        return point
      end,
    }

    local section = lib.get_or_create_section(nil, nil, entity, { ingredients = { { name = "iron-plate" } } })
    assert.equal(blank, section)
  end)

  it("get_or_create_section returns nil without a logistic point", function()
    local entity = {
      get_logistic_point = function()
        return nil
      end,
    }

    assert.is_nil(lib.get_or_create_section(nil, nil, entity, { ingredients = { { name = "iron-plate" } } }))
  end)

  it("get_or_create_section replaces matching unnamed sections", function()
    local matching = Support.make_section("", {
      { value = { name = "iron-plate" } },
      { value = { name = "iron-gear-wheel" } },
    })
    local added = Support.make_section("", {})
    local point = {}
    point.sections_count = 1
    point.sections = { matching }
    point.remove_section = function(idx)
      table.remove(point.sections, idx)
      point.sections_count = #point.sections
    end
    point.add_section = function()
      table.insert(point.sections, added)
      point.sections_count = #point.sections
      return added
    end
    local entity = {
      get_logistic_point = function()
        return point
      end,
    }

    local section = lib.get_or_create_section(nil, nil, entity, {
      ingredients = {
        { name = "iron-gear-wheel" },
        { name = "iron-plate" },
      },
    })

    assert.equal(added, section)
    assert.equal(1, point.sections_count)
    assert.equal(added, point.sections[1])
  end)

  it("get_or_create_section removes extra blank unnamed sections but preserves named ones", function()
    local named = Support.make_section("Keep me", {
      { value = { name = "copper-plate" } },
    })
    local blank_one = Support.make_section("", {})
    local blank_two = Support.make_section("", {})
    local added = Support.make_section("", {})
    local point = {}
    point.sections_count = 3
    point.sections = { named, blank_one, blank_two }
    point.remove_section = function(idx)
      table.remove(point.sections, idx)
      point.sections_count = #point.sections
    end
    point.add_section = function()
      table.insert(point.sections, added)
      point.sections_count = #point.sections
      return added
    end
    local entity = {
      get_logistic_point = function()
        return point
      end,
    }

    local section = lib.get_or_create_section(nil, nil, entity, {
      ingredients = {
        { name = "iron-plate" },
      },
    })

    assert.equal(2, point.sections_count)
    assert.equal(named, point.sections[1])
    assert.equal(added, section)
    assert.equal(added, point.sections[2])
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
    local chest_target = { type = "logistic-container" }
    local inserter_target = { type = "inserter" }

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
      pickup_target = requester,
      drop_target = target,
    }
    local output_inserter = {
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
    assert.equal("transport-belt", copied.name)
    assert.equal(3, copied.quality)
    assert.same({
      { name = "iron-plate", amount = 1, stack_size = 100, quality = 3 },
    }, copied.ingredients)
  end)
end)
