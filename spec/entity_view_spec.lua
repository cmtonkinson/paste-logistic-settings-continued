local Support = require("spec.support")
local EntityView = require("src.entity_view")

describe("entity_view", function()
  local restore_globals

  before_each(function()
    restore_globals = Support.with_mocked_factorio_globals()
  end)

  after_each(function()
    restore_globals()
  end)

  it("resolves built entity identity directly", function()
    local entity = {
      valid = true,
      name = "requester-chest",
      type = "logistic-container",
      prototype = { logistic_mode = "requester" },
    }

    local view = EntityView.resolve(entity)

    assert.is_false(view.is_ghost)
    assert.equal("requester-chest", view:get_name())
    assert.equal("logistic-container", view:get_type())
    assert.equal("requester", view:get_logistic_mode())
    assert.is_true(view:is_requester_chest())
  end)

  it("resolves ghost identity from the contained entity", function()
    local ghost = {
      valid = true,
      name = "entity-ghost",
      type = "entity-ghost",
      prototype = { logistic_mode = nil },
      ghost_name = "storage-chest",
      ghost_type = "logistic-container",
      ghost_prototype = { logistic_mode = "storage" },
    }

    local view = EntityView.resolve(ghost)

    assert.is_true(view.is_ghost)
    assert.equal("entity-ghost", view.outer_name)
    assert.equal("entity-ghost", view.outer_type)
    assert.equal("storage-chest", view:get_name())
    assert.equal("logistic-container", view:get_type())
    assert.equal("storage", view:get_logistic_mode())
    assert.is_true(view:is_storage_chest())
  end)

  it("matches effective names across built and ghost entities", function()
    local built = {
      valid = true,
      name = "assembling-machine-2",
      type = "assembling-machine",
      prototype = {},
    }
    local ghost = {
      valid = true,
      name = "entity-ghost",
      type = "entity-ghost",
      prototype = {},
      ghost_name = "assembling-machine-2",
      ghost_type = "assembling-machine",
      ghost_prototype = {},
    }

    assert.is_true(EntityView.resolve(built):same_effective_name(ghost))
  end)

  it("compares raw entities without treating them like resolved views", function()
    local source = {
      valid = true,
      name = "assembling-machine-3",
      type = "assembling-machine",
      prototype = {},
    }
    local target = {
      valid = true,
      name = "assembling-machine-3",
      type = "assembling-machine",
      prototype = {},
    }

    assert.is_true(EntityView.resolve(target):same_effective_name(source))
  end)

  it("treats ghost crafting machines as valid sources when get_recipe works", function()
    local ghost = {
      valid = true,
      name = "entity-ghost",
      type = "entity-ghost",
      prototype = {},
      ghost_name = "assembling-machine-2",
      ghost_type = "assembling-machine",
      ghost_prototype = {},
      get_recipe = function()
        return { name = "transport-belt" }, { level = 2 }
      end,
    }

    local view = EntityView.resolve(ghost)

    assert.is_true(view:is_crafting_machine())
    assert.is_true(view:is_valid_source())
  end)

  it("applies inserter settings through a ghost inserter", function()
    local behavior = {}
    local ghost = {
      valid = true,
      name = "entity-ghost",
      type = "entity-ghost",
      prototype = {},
      ghost_name = "fast-inserter",
      ghost_type = "inserter",
      ghost_prototype = {},
      get_or_create_control_behavior = function()
        return behavior
      end,
    }

    local result = EntityView.resolve(ghost):apply_inserter_settings(nil, { index = 1 }, {
      item = true,
      name = "transport-belt",
      quality = 2,
    })

    assert.is_true(result.ok)
    assert.is_true(behavior.connect_to_logistic_network)
    assert.equal("transport-belt", behavior.logistic_condition.first_signal.name)
    assert.equal("rare", behavior.logistic_condition.first_signal.quality)
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

    assert.is_true(EntityView.has_same_ingredient_names(filters, ingredients))
    assert.is_false(EntityView.has_same_ingredient_names(filters, { { name = "iron-plate" } }))
  end)

  it("get_or_create_request_section reuses the single blank unnamed section", function()
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

    local section = EntityView.resolve(entity)
      :get_or_create_request_section({ ingredients = { { name = "iron-plate" } } })
    assert.equal(blank, section)
  end)

  it("get_or_create_request_section returns nil without a logistic point", function()
    local entity = {
      get_logistic_point = function()
        return nil
      end,
    }

    assert.is_nil(
      EntityView.resolve(entity):get_or_create_request_section({ ingredients = { { name = "iron-plate" } } })
    )
  end)

  it("get_or_create_request_section falls back to sections owners after nil candidates", function()
    local added = Support.make_section("", {})
    local requester_sections = {
      sections_count = 0,
      sections = {},
      add_section = function()
        return added
      end,
    }
    local entity = {
      get_logistic_sections = function()
        return nil
      end,
      get_requester_point = function()
        return {
          sections = requester_sections,
        }
      end,
      get_logistic_point = function()
        return nil
      end,
    }

    local section = EntityView.resolve(entity)
      :get_or_create_request_section({ ingredients = { { name = "iron-plate" } } })

    assert.equal(added, section)
  end)

  it("get_or_create_request_section replaces matching unnamed sections", function()
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

    local section = EntityView.resolve(entity):get_or_create_request_section({
      ingredients = {
        { name = "iron-gear-wheel" },
        { name = "iron-plate" },
      },
    })

    assert.equal(added, section)
    assert.equal(1, point.sections_count)
    assert.equal(added, point.sections[1])
  end)

  it("get_or_create_request_section removes extra blank unnamed sections but preserves named ones", function()
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

    local section = EntityView.resolve(entity):get_or_create_request_section({
      ingredients = {
        { name = "iron-plate" },
      },
    })

    assert.equal(2, point.sections_count)
    assert.equal(named, point.sections[1])
    assert.equal(added, section)
    assert.equal(added, point.sections[2])
  end)
end)
