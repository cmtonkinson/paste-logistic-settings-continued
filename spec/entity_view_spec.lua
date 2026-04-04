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

    assert.is_true(EntityView.same_effective_name(built, ghost))
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
end)
