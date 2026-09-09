local helpers = {}

-----------------------------------------------------------------------------
-- Extract a specific key from a table of tables.
-- @param tbl table: The table to extract from.
-- @param key string: The key to extract.
-- @return table: A new table containing the values of the specified key.
function helpers.pluck(tbl, key)
  local result = {}
  for _, entry in ipairs(tbl) do
    result[#result + 1] = entry[key]
  end
  return result
end

-----------------------------------------------------------------------------
-- Extract a specific key from a table of tables and return it as a set.
-- @param tbl table: The table to extract from.
-- @param key string: The key to extract.
-- @return table: A new table containing the values of the specified key as a set.
function helpers.pluck_set(tbl, key)
  local set = {}
  for _, entry in ipairs(tbl) do
    set[entry[key]] = true
  end
  return set
end

-- Determines whether the entity is a crafting machine.
-- @param entity LuaEntity: The entity to test.
-- @return boolean: True if the entity is a crafting machine, false otherwise.
function helpers.is_crafting_machine(game, entity)
  if not (entity and entity.valid) then
    return false
  end
  return pcall(entity.get_recipe, entity)
end

-----------------------------------------------------------------------------
-- Determines whether the entity is valid for copying FROM.
-- @param entity LuaEntity: THe entity to test.
-- @return boolean: True only if the entity is valid for copying.
function helpers.is_valid_source(game, entity)
  return helpers.is_crafting_machine(game, entity) and entity.get_recipe() ~= nil
end

-----------------------------------------------------------------------------
-- Determines whether the entity is valid for copying TO.
-- @param entity LuaEntity: The entity to test.
-- @return boolean: True only if the entity is valid for copying.
function helpers.is_valid_target(game, entity)
  return entity
    and entity.valid
    and (
            -- It may seem weird to call is_valid_source here, but to enable the
      -- autoconfigure feature, any valid source IS a valid target.
helpers.is_valid_source(game, entity)
      -- And now the "normal" valid targets.
      or entity.type == "logistic-container"
      or (entity.type == "inserter" and entity.get_or_create_control_behavior)
    )
end

-----------------------------------------------------------------------------
-- Determines whether the entity is a storage chest.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The entity to test.
-- @return boolean: True if the entity is a storage chest, false otherwise.
function helpers.is_storage_chest(game, entity)
  return entity and entity.valid and entity.type == "logistic-container" and entity.prototype.logistic_mode == "storage"
end

-----------------------------------------------------------------------------
-- Determines whether the entity is a requester chest.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The entity to test.
-- @return boolean: True if the entity is a requester chest, false otherwise.
function helpers.is_requester_chest(game, entity)
  if not entity or not entity.valid or entity.type ~= "logistic-container" then
    return false
  end
  local mode = entity.prototype.logistic_mode
  return mode == "requester" or mode == "buffer"
end

-----------------------------------------------------------------------------
-- Returns how many items should be allowed/requested.
-- @param game LuaGameScript: The game object.
-- @param prototype LuaItemPrototype: The item prototype.
-- @param type string: The type of limit to apply (stacks or items).
-- @param limit number: The limit to apply.
-- @return number: The calculated limit.
function helpers.get_limit(game, prototype, type, limit)
  local result = 0
  if type == "stacks" then
    result = prototype.stack_size * limit
  elseif type == "items" then
    result = limit
  end
  return result
end

-----------------------------------------------------------------------------
-- Creates an area table a certain distance around the given entity.
-- @param entity LuaEntity: The entity to create the area around.
-- @param radius number: The radius of the area.
-- @return table: The area table.
function helpers.get_area(game, entity, distance)
  if not (entity and entity.valid) then
    return nil
  end
  if not distance or distance < 0 then
    distance = 0
  end

  return {
    {
      entity.position.x - distance,
      entity.position.y - distance,
    },
    {
      entity.position.x + distance,
      entity.position.y + distance,
    },
  }
end

function helpers.get_quality_string(quality_id)
  local mapping = {
    [0] = "normal",
    [1] = "uncommon",
    [2] = "rare",
    [3] = "epic",
    [5] = "legendary",
  }
  if not quality_id or mapping[quality_id] == nil then
    return "normal"
  else
    return mapping[quality_id]
  end
end

-----------------------------------------------------------------------------
-- Formats an amount for display, dropping decimals that carry no information.
-- @param value number: The amount to format.
-- @return string: "2" for 2.0, "1.5" for 1.5, "0.33" for 1/3.
function helpers.format_amount(value)
  if value == math.floor(value) then
    return string.format("%d", value)
  end

  local text = string.format("%.2f", value)
  text = text:gsub("0+$", "")
  text = text:gsub("%.$", "")
  return text
end

-----------------------------------------------------------------------------
-- Builds the floating text shown when an output inserter limit is applied.
-- Either half can be suppressed; when both are shown they are joined with
-- " / ", e.g. "1 stack / 100x [item=transport-belt]".
-- @param prototype LuaItemPrototype: The item the limit applies to.
-- @param limit number: The limit, in items.
-- @param show_stacks boolean: Whether to include the stack count.
-- @param show_items boolean: Whether to include the item count.
-- @return LocalisedString|nil: nil when there is nothing worth showing.
function helpers.build_output_limit_text(prototype, limit, show_stacks, show_items)
  if not prototype or type(limit) ~= "number" or limit <= 0 then
    return nil
  end

  local parts = {}

  if show_stacks then
    local stack_size = prototype.stack_size
    if type(stack_size) ~= "number" or stack_size <= 0 then
      stack_size = 1
    end
    parts[#parts + 1] = {
      "floating-text.paste-logistic-settings-continued-stacks",
      helpers.format_amount(limit / stack_size),
    }
  end

  -- Built in Lua rather than from a locale entry on purpose. Factorio resolves
  -- rich text before substituting __1__ style parameters, so "[item=__2__]" in
  -- a .cfg looks up an item literally named "__2__" and renders nothing. A
  -- count and an icon need no translation anyway.
  if show_items and prototype.name then
    parts[#parts + 1] = helpers.format_amount(limit) .. "x [item=" .. prototype.name .. "]"
  end

  if #parts == 0 then
    return nil
  end
  if #parts == 1 then
    return parts[1]
  end

  return { "", parts[1], " / ", parts[2] }
end

-----------------------------------------------------------------------------
--- Determines whether the player is holding anything. Used to prevent mod
--- activation in cases where the player is trying to super force build
--- anything since the two use the same modifier keys.
--- @param game LuaGameScript: The game object.
--- @param player LuaPlayer: The player to check.
--- @param event LuaEvent: The event that triggered the check.
function helpers.is_holding_anything(game, player, event)
  if not player.is_cursor_empty() then
    return true
  end
end

return helpers
