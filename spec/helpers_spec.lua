local helpers = require("src.helpers")

describe("helpers", function()
  it("format_amount drops decimals that carry no information", function()
    assert.equal("1", helpers.format_amount(1))
    assert.equal("2", helpers.format_amount(2.0))
    assert.equal("100", helpers.format_amount(100))
    assert.equal("1.5", helpers.format_amount(1.5))
    assert.equal("0.5", helpers.format_amount(0.5))
    assert.equal("2.25", helpers.format_amount(2.25))
    assert.equal("0.33", helpers.format_amount(1 / 3))
  end)

  it("build_output_limit_text joins the stack and item halves with a slash", function()
    local prototype = { stack_size = 100, name = "transport-belt" }

    assert.same({
      "",
      { "floating-text.paste-logistic-settings-continued-stacks", "1" },
      " / ",
      "100x [item=transport-belt]",
    }, helpers.build_output_limit_text(prototype, 100, true, true))
  end)

  it("build_output_limit_text returns a single half on its own when only one is enabled", function()
    local prototype = { stack_size = 100, name = "transport-belt" }

    assert.same(
      { "floating-text.paste-logistic-settings-continued-stacks", "2" },
      helpers.build_output_limit_text(prototype, 200, true, false)
    )
    assert.same("200x [item=transport-belt]", helpers.build_output_limit_text(prototype, 200, false, true))
  end)

  it("build_output_limit_text expresses partial stacks as fractions", function()
    local prototype = { stack_size = 100, name = "transport-belt" }
    local text = helpers.build_output_limit_text(prototype, 150, true, false)

    assert.same({ "floating-text.paste-logistic-settings-continued-stacks", "1.5" }, text)
  end)

  it("build_output_limit_text has nothing to say when both halves are disabled", function()
    local prototype = { stack_size = 100, name = "transport-belt" }

    assert.is_nil(helpers.build_output_limit_text(prototype, 100, false, false))
  end)

  it("build_output_limit_text declines to render a missing prototype or a useless limit", function()
    local prototype = { stack_size = 100, name = "transport-belt" }

    assert.is_nil(helpers.build_output_limit_text(nil, 100, true, true))
    assert.is_nil(helpers.build_output_limit_text(prototype, 0, true, true))
    assert.is_nil(helpers.build_output_limit_text(prototype, -5, true, true))
    assert.is_nil(helpers.build_output_limit_text(prototype, nil, true, true))
  end)

  it("build_output_limit_text survives a prototype with an unusable stack size", function()
    local prototype = { stack_size = 0, name = "oddity" }

    -- Falling back to a stack size of 1 keeps this from dividing by zero.
    assert.same(
      { "floating-text.paste-logistic-settings-continued-stacks", "50" },
      helpers.build_output_limit_text(prototype, 50, true, false)
    )
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

  it("calculates item limits from stacks or items", function()
    local proto = { stack_size = 100 }

    assert.equal(300, helpers.get_limit(proto, "stacks", 3))
    assert.equal(7, helpers.get_limit(proto, "items", 7))
    assert.equal(0, helpers.get_limit(proto, "weird", 7))
  end)

  -- get_quality_string resolves against the game's quality prototypes, so these
  -- stand up a registry instead of assuming a fixed table of levels.
  local function with_qualities(levels, fn)
    local original = rawget(_G, "prototypes")
    local quality = nil
    if levels then
      quality = {}
      for name, level in pairs(levels) do
        quality[name] = { name = name, level = level }
      end
    end
    _G.prototypes = quality and { quality = quality } or nil
    local ok, err = pcall(fn)
    _G.prototypes = original
    if not ok then
      error(err, 0)
    end
  end

  local VANILLA_QUALITIES = { normal = 0, uncommon = 1, rare = 2, epic = 3, legendary = 5 }

  it("resolves quality levels from the game's quality prototypes", function()
    with_qualities(VANILLA_QUALITIES, function()
      assert.equal("normal", helpers.get_quality_string(0))
      assert.equal("uncommon", helpers.get_quality_string(1))
      assert.equal("rare", helpers.get_quality_string(2))
      assert.equal("epic", helpers.get_quality_string(3))
      assert.equal("legendary", helpers.get_quality_string(5))
    end)
  end)

  it("resolves a modded quality tier the old fixed table could not", function()
    -- Vanilla leaves level 4 empty; the hardcoded map reported it as normal,
    -- so a mod occupying that level got the wrong quality pasted silently.
    with_qualities({ normal = 0, mythic = 4, legendary = 5 }, function()
      assert.equal("mythic", helpers.get_quality_string(4))
    end)
  end)

  it("falls back to normal for levels nothing claims", function()
    with_qualities(VANILLA_QUALITIES, function()
      assert.equal("normal", helpers.get_quality_string(4))
      assert.equal("normal", helpers.get_quality_string(999))
    end)
  end)

  it("falls back to normal without a quality registry or a numeric level", function()
    with_qualities(nil, function()
      assert.equal("normal", helpers.get_quality_string(2))
    end)
    with_qualities(VANILLA_QUALITIES, function()
      assert.equal("normal", helpers.get_quality_string(nil))
      assert.equal("normal", helpers.get_quality_string("rare"))
    end)
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
