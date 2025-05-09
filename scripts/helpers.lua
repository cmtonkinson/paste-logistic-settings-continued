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

-----------------------------------------------------------------------------
-- Determines whether the entity is a crafting machine.
-- @param entity LuaEntity: The entity to test.
-- @return boolean: True if the entity is a crafting machine, false otherwise.
function helpers.is_crafting_machine(entity)
  if not (entity and entity.valid) then return false end
  return pcall(entity.get_recipe, entity)
end

-----------------------------------------------------------------------------
-- Determines whether the entity is valid for copying FROM.
-- @param entity LuaEntity: THe entity to test.
-- @return boolean: True only if the entity is valid for copying.
function helpers.is_valid_source(game, entity)
  game = game or nil
  return helpers.is_crafting_machine(entity) and entity.get_recipe() ~= nil
end

-----------------------------------------------------------------------------
-- Determines whether the entity is valid for copying TO.
-- @param entity LuaEntity: The entity to test.
-- @return boolean: True only if the entity is valid for copying.
function helpers.is_valid_target(game, entity)
  game = game or nil
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

return helpers
