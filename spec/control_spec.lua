local Support = require("spec.support")

describe("control", function()
  local harness

  before_each(function()
    harness = Support.make_control_harness()
  end)

  after_each(function()
    harness.restore()
  end)

  it("registers copy, paste, and migration handlers", function()
    harness.load_control()

    assert.is_function(harness.handlers["paste-logistic-settings-continued-copy"])
    assert.is_function(harness.handlers["paste-logistic-settings-continued-paste"])
    assert.is_function(harness.handlers.configuration_changed)
  end)

  it("copy handler stores copied data for the player", function()
    local target = { name = "assembling-machine-2" }
    _G.game = {
      players = {
        [1] = { selected = target },
      },
    }
    _G.global = nil

    harness.load_control()
    harness.handlers["paste-logistic-settings-continued-copy"]({ player_index = 1 })

    assert.same({ source = target, copied = true }, global.paste_data[1])
    assert.equal("copy", harness.lib_calls[1].kind)
  end)

  it("copy and paste handlers do nothing while the player is holding something", function()
    local source = { name = "assembling-machine-2", valid = true }
    _G.game = {
      players = {
        [1] = { selected = source },
      },
    }
    _G.global = {
      paste_data = {
        [1] = { source = source },
      },
    }
    harness.helpers_stub.is_holding_anything = function()
      return true
    end

    harness.load_control()
    harness.handlers["paste-logistic-settings-continued-copy"]({ player_index = 1 })
    harness.handlers["paste-logistic-settings-continued-paste"]({ player_index = 1 })

    assert.same({}, harness.lib_calls)
    assert.same({ source = source }, global.paste_data[1])
  end)

  it("paste handler dispatches between autoconfigure and direct paste", function()
    local source = { name = "assembling-machine-2" }
    local same_target = { valid = true, type = "entity-ghost", ghost_name = "assembling-machine-2" }
    local other_target = { valid = true, name = "storage-chest" }
    _G.game = {
      players = {
        [1] = { selected = same_target },
      },
    }
    _G.global = {
      paste_data = {
        [1] = { source = source },
      },
    }

    harness.load_control()
    harness.handlers["paste-logistic-settings-continued-paste"]({ player_index = 1 })

    _G.game.players[1].selected = other_target
    harness.handlers["paste-logistic-settings-continued-paste"]({ player_index = 1 })

    assert.equal("autoconfigure", harness.lib_calls[1].kind)
    assert.equal("paste", harness.lib_calls[2].kind)
    assert.equal(other_target, harness.lib_calls[2].target)
  end)

  it("paste handler returns early for invalid targets or missing data", function()
    _G.game = {
      players = {
        [1] = { selected = nil },
      },
    }
    _G.global = { paste_data = {} }

    harness.load_control()
    harness.handlers["paste-logistic-settings-continued-paste"]({ player_index = 1 })

    _G.game.players[1].selected = { valid = false }
    harness.handlers["paste-logistic-settings-continued-paste"]({ player_index = 1 })

    _G.game.players[1].selected = { valid = true, name = "storage-chest" }
    harness.handlers["paste-logistic-settings-continued-paste"]({ player_index = 1 })

    assert.same({}, harness.lib_calls)
  end)

  it("paste handler returns early when helpers reject the target", function()
    local target = { valid = true, name = "storage-chest" }
    _G.game = {
      players = {
        [1] = { selected = target },
      },
    }
    _G.global = {
      paste_data = {
        [1] = { source = { name = "assembling-machine-2" } },
      },
    }
    harness.entity_view_stub.resolve = function()
      return {
        is_valid_target = function()
          return false
        end,
        same_effective_name = function()
          return false
        end,
      }
    end

    harness.load_control()
    harness.handlers["paste-logistic-settings-continued-paste"]({ player_index = 1 })

    assert.same({}, harness.lib_calls)
  end)

  it("migration handler prints warnings for low legacy settings", function()
    local messages = {}
    _G.game = {
      players = {
        {
          print = function(message)
            table.insert(messages, message)
          end,
        },
      },
    }
    _G.settings = {
      get_player_settings = function()
        return {
          ["paste-logistic-settings-continued-output-limit"] = { value = 0 },
          ["paste-logistic-settings-continued-request-size"] = { value = 0 },
        }
      end,
    }

    harness.load_control()
    harness.handlers.configuration_changed({})

    assert.same({
      { "msg.paste-logistic-settings-continued-output-limit-migration" },
      { "msg.paste-logistic-settings-continued-request-size-migration" },
    }, messages)
  end)
end)
