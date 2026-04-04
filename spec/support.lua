local Support = {}

function Support.make_settings(values)
  return {
    get_player_settings = function(player_index)
      if player_index ~= 1 then
        error("expected mocked player index 1")
      end
      return values
    end,
  }
end

function Support.make_section(group, filters)
  local section = {
    group = group or "",
    filters = filters or {},
    filters_count = #(filters or {}),
  }

  section.set_slot = function(idx, slot)
    section.filters[idx] = slot
    section.filters_count = #section.filters
  end

  return section
end

function Support.with_mocked_factorio_globals()
  local original_prototypes = rawget(_G, "prototypes")
  local original_settings = rawget(_G, "settings")
  local original_table_size = rawget(_G, "table_size")
  local original_defines = rawget(_G, "defines")

  _G.prototypes = {
    item = {
      ["transport-belt"] = { stack_size = 100 },
      ["iron-plate"] = { stack_size = 100 },
      ["iron-gear-wheel"] = { stack_size = 100 },
      sulfur = { stack_size = 50 },
    },
  }

  _G.settings = Support.make_settings({
    ["paste-logistic-settings-continued-output-limit-type"] = { value = "items" },
    ["paste-logistic-settings-continued-output-limit"] = { value = 13 },
    ["paste-logistic-settings-continued-accumulate-inserter-output-limit"] = { value = true },
    ["paste-logistic-settings-continued-request-size-type"] = { value = "items" },
    ["paste-logistic-settings-continued-request-size"] = { value = 7 },
    ["paste-logistic-settings-continued-enable-ghost-placement"] = { value = false },
    ["paste-logistic-settings-continued-ghost-direction"] = { value = "south" },
    ["paste-logistic-settings-continued-ghost-input-inserter"] = { value = "bulk-inserter" },
    ["paste-logistic-settings-continued-ghost-output-inserter"] = { value = "fast-inserter" },
    ["paste-logistic-settings-continued-ghost-output-chest"] = { value = "storage-chest" },
  })

  _G.table_size = function(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do
      count = count + 1
    end
    return count
  end

  _G.defines = {
    direction = {
      north = 0,
      east = 2,
      south = 4,
      west = 6,
    },
    logistic_member_index = {
      logistic_container = 1,
    },
  }

  return function()
    _G.prototypes = original_prototypes
    _G.settings = original_settings
    _G.table_size = original_table_size
    _G.defines = original_defines
  end
end

function Support.make_control_harness()
  local original_script = rawget(_G, "script")
  local original_game = rawget(_G, "game")
  local original_global = rawget(_G, "global")
  local original_settings = rawget(_G, "settings")
  local original_helpers_preload = package.preload["__paste-logistic-settings-continued__.src.helpers"]
  local original_lib_preload = package.preload["__paste-logistic-settings-continued__.src.lib"]
  local original_entity_view_preload = package.preload["__paste-logistic-settings-continued__.src.entity_view"]

  local harness = {
    handlers = {},
    lib_calls = {},
  }

  harness.helpers_stub = {
    is_holding_anything = function()
      return false
    end,
  }

  harness.entity_view_stub = {
    resolve = function(target)
      return {
        is_valid_source = function()
          return target ~= nil
        end,
        is_valid_target = function()
          return target and target.valid
        end,
        same_effective_name = function(_, other)
          local target_name = target and (target.ghost_name or target.name)
          local other_name = other and (other.ghost_name or other.source_name or other.name)
          return target_name ~= nil and target_name == other_name
        end,
      }
    end,
  }

  harness.lib_stub = {
    copy_settings = function(_, _, target)
      local data = { source = target, copied = true }
      table.insert(harness.lib_calls, { kind = "copy", target = target, data = data })
      return data
    end,
    paste_settings = function(_, _, target, data)
      table.insert(harness.lib_calls, { kind = "paste", target = target, data = data })
    end,
    autoconfigure_settings = function(_, _, target, data)
      table.insert(harness.lib_calls, { kind = "autoconfigure", target = target, data = data })
    end,
  }

  package.preload["__paste-logistic-settings-continued__.src.helpers"] = function()
    return harness.helpers_stub
  end
  package.preload["__paste-logistic-settings-continued__.src.lib"] = function()
    return harness.lib_stub
  end
  package.preload["__paste-logistic-settings-continued__.src.entity_view"] = function()
    return harness.entity_view_stub
  end

  _G.script = {
    on_event = function(name, fn)
      harness.handlers[name] = fn
    end,
    on_configuration_changed = function(fn)
      harness.handlers.configuration_changed = fn
    end,
  }

  function harness.load_control()
    package.loaded["__paste-logistic-settings-continued__.src.helpers"] = nil
    package.loaded["__paste-logistic-settings-continued__.src.lib"] = nil
    package.loaded["__paste-logistic-settings-continued__.src.entity_view"] = nil
    assert(loadfile("/Users/chris/repo/paste-logistic-settings-continued/control.lua", "t"))()
  end

  function harness.restore()
    _G.script = original_script
    _G.game = original_game
    _G.global = original_global
    _G.settings = original_settings
    package.preload["__paste-logistic-settings-continued__.src.helpers"] = original_helpers_preload
    package.preload["__paste-logistic-settings-continued__.src.lib"] = original_lib_preload
    package.preload["__paste-logistic-settings-continued__.src.entity_view"] = original_entity_view_preload
    package.loaded["__paste-logistic-settings-continued__.src.helpers"] = nil
    package.loaded["__paste-logistic-settings-continued__.src.lib"] = nil
    package.loaded["__paste-logistic-settings-continued__.src.entity_view"] = nil
  end

  return harness
end

return Support
