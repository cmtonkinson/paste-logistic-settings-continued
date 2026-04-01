local helpers = require("src.helpers")

describe("helpers", function()
  it("pluck extracts the requested key", function()
    local rows = {
      { name = "a", val = 1 },
      { name = "b", val = 2 },
      { name = "c", val = 3 },
    }

    assert.same({ "a", "b", "c" }, helpers.pluck(rows, "name"))
    assert.same({ 1, 2, 3 }, helpers.pluck(rows, "val"))
  end)

  it("pluck_set extracts the requested key as a set", function()
    local rows = {
      { name = "a", val = 1 },
      { name = "b", val = 2 },
      { name = "c", val = 3 },
    }

    assert.same({ a = true, b = true, c = true }, helpers.pluck_set(rows, "name"))
    assert.same({ [1] = true, [2] = true, [3] = true }, helpers.pluck_set(rows, "val"))
  end)

  it("get_area returns a bounding box around a valid entity", function()
    local entity = {
      valid = true,
      position = { x = 1, y = 2 },
    }

    assert.same({ { -2, -1 }, { 4, 5 } }, helpers.get_area(nil, entity, 3))
    assert.is_nil(helpers.get_area(nil, nil, 3))
    assert.same({ { 1, 2 }, { 1, 2 } }, helpers.get_area(nil, entity, -99))
  end)

  it("detects crafting machines via get_recipe", function()
    local machine = {
      valid = true,
      get_recipe = function()
        return { name = "transport-belt" }
      end,
    }
    local not_machine = {
      valid = true,
      get_recipe = function()
        error("no recipe")
      end,
    }

    assert.is_true(helpers.is_crafting_machine(nil, machine))
    assert.is_false(helpers.is_crafting_machine(nil, not_machine))
    assert.is_false(helpers.is_crafting_machine(nil, nil))
  end)

  it("detects valid copy sources", function()
    local machine = {
      valid = true,
      get_recipe = function()
        return { name = "transport-belt" }
      end,
    }
    local empty_machine = {
      valid = true,
      get_recipe = function()
        return nil
      end,
    }

    assert.is_true(helpers.is_valid_source(nil, machine))
    assert.is_false(helpers.is_valid_source(nil, empty_machine))
  end)

  it("detects valid paste targets", function()
    local machine = {
      valid = true,
      get_recipe = function()
        return { name = "transport-belt" }
      end,
    }
    local logistic_container = {
      valid = true,
      type = "logistic-container",
    }
    local inserter = {
      valid = true,
      type = "inserter",
      get_or_create_control_behavior = function() end,
    }
    local lamp = {
      valid = true,
      type = "lamp",
    }

    assert.is_truthy(helpers.is_valid_target(nil, machine))
    assert.is_truthy(helpers.is_valid_target(nil, logistic_container))
    assert.is_truthy(helpers.is_valid_target(nil, inserter))
    assert.is_falsy(helpers.is_valid_target(nil, lamp))
    assert.is_falsy(helpers.is_valid_target(nil, nil))
  end)

  it("detects storage and requester chest modes", function()
    local storage = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "storage" },
    }
    local requester = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "requester" },
    }
    local buffer = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "buffer" },
    }
    local passive = {
      valid = true,
      type = "logistic-container",
      prototype = { logistic_mode = "passive-provider" },
    }

    assert.is_true(helpers.is_storage_chest(nil, storage))
    assert.is_false(helpers.is_storage_chest(nil, requester))
    assert.is_true(helpers.is_requester_chest(nil, requester))
    assert.is_true(helpers.is_requester_chest(nil, buffer))
    assert.is_false(helpers.is_requester_chest(nil, passive))
  end)

  it("calculates item limits from stacks or items", function()
    local proto = { stack_size = 100 }

    assert.equal(300, helpers.get_limit(nil, proto, "stacks", 3))
    assert.equal(7, helpers.get_limit(nil, proto, "items", 7))
    assert.equal(0, helpers.get_limit(nil, proto, "weird", 7))
  end)

  it("maps quality ids to Factorio quality names", function()
    assert.equal("normal", helpers.get_quality_string(nil))
    assert.equal("normal", helpers.get_quality_string(0))
    assert.equal("uncommon", helpers.get_quality_string(1))
    assert.equal("rare", helpers.get_quality_string(2))
    assert.equal("epic", helpers.get_quality_string(3))
    assert.equal("legendary", helpers.get_quality_string(5))
    assert.equal("normal", helpers.get_quality_string(4))
    assert.equal("normal", helpers.get_quality_string(999))
  end)

  it("detects when the player is holding anything", function()
    local holding_player = {
      is_cursor_empty = function()
        return false
      end,
    }
    local empty_player = {
      is_cursor_empty = function()
        return true
      end,
    }

    assert.is_true(helpers.is_holding_anything(nil, holding_player, nil))
    assert.is_nil(helpers.is_holding_anything(nil, empty_player, nil))
  end)
end)
