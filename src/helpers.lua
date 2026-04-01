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
