local lib = {}

local helpers = require("__paste-logistic-settings-continued__.scripts.helpers")

-- Fallback value to use for stack sizes if all else fails.
local DEFAULT_STACK_SIZE = 1

-- Applies the settings to an inserter.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The inserter to configure.
-- @param data table: Information about the recipe being crafted.
-- @return nil
function lib.apply_inserter_settings(game, player_index, inserter, data)
  game = game or nil
  local behavior = inserter.get_or_create_control_behavior()
  if not behavior then return end

  -- The runtime per user setting `output-limit` controls how many of the item
  -- the inserter will allow into the network. A (default) value of 0 means use
  -- the native stack size of the item and a positive value overrides that
  -- behavior.
  local item_proto = prototypes.item[data.name]
  local output_limit = settings.get_player_settings(player_index)["paste-logistic-settings-continued-output-limit"].value
  if output_limit == 0 then
    output_limit = item_proto and item_proto.stack_size or DEFAULT_STACK_SIZE
  end

  behavior.connect_to_logistic_network = true
  behavior.logistic_condition = {
    comparator = "<",
    first_signal = { type = "item", name = data.name},
    constant = output_limit,
  }
end

-----------------------------------------------------------------------------
-- Checks if the filters in the given logistic section match the ingredients
-- of the given recipe.
-- @param game LuaGameScript: The game object.
-- @param filters table: The filters to check.
-- @param ingredients table: The ingredients to check against.
-- @return boolean: True if the filters match the ingredients, false otherwise.
function lib.has_same_ingredient_names(game, filters, ingredients)
  game = game or nil

  if table_size(filters) ~= table_size(ingredients) then return false end

  local ingredient_names = helpers.pluck_set(ingredients, "name")
  local filter_names = helpers.pluck_set(helpers.pluck(filters, "value"), "name")

  for ing, _ in ipairs(ingredient_names) do
    if not filter_names[ing] then return false end
  end

  -- If the cardinality of each is the same and every ingredient is a filter,
  -- then we know the filters are the same as the ingredients.
  return true
end

-----------------------------------------------------------------------------
-- Return a LuaLogisticSection suitable for configuring slots with the ingredients.
-- @param game LuaGameScript: The game object.
-- Ensures it does not create uneccessary sections, and will override an existing
-- section if the ingredients are the same (quantity and order may be overridden).
function lib.get_or_create_section(game, entity, data)
  game = game or nil

  -- Get the LuaLogisticPoint for the given LuaEntity.
  local point = entity.get_logistic_point(0)
  if not point then return end

  -- If there are existing sections...
  if point.sections_count > 0 then
    -- Is there an empty, unnamed section? Return that.
    for i, sec in ipairs(point.sections) do
      if sec.filters_count == 0 and sec.group == "" then
        return sec
      end
    end
    -- If none are empty, does one section match exactly the kind of ingredients
    -- we need for this recipe? If so, clear the filters and return it. This is
    -- easier than knowing which filter is in which slot and then updating their
    -- quantities; it's easier to just nuke the section and let the client code
    -- pave over it.
    for idx, sec in ipairs(point.sections) do
      if lib.has_same_ingredient_names(game, sec.filters, data.ingredients) and sec.group == "" then
        point.remove_section(idx)
        break
      end
    end
  end

  -- If all else fails, create a new empty section.
  return point.add_section()
end

-----------------------------------------------------------------------------
-- Applies the settings to a chest.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The chest to copy to.
-- @param data table: Information about the recipe being crafted.
function lib.apply_chest_settings(game, player_index, chest, data)
  game = game or nil

  if helpers.is_storage_chest(chest) then
    chest.storage_filter = prototypes.item[data.name]

  elseif helpers.is_requester_chest(chest) then
    local section = lib.get_or_create_section(game, chest, data)
    if data.ingredients then
      for i, ing in ipairs(data.ingredients) do
        local proto = prototypes.item[ing.name]
        -- The runtime per user setting `request-size` controls how many of each
        -- ingredient the chest will request. A (default) value of 0 means use the
        -- native stack size of each item. A positive value overrides that behavior.
        local request_size = settings.get_player_settings(player_index)["paste-logistic-settings-continued-request-size"].value
        if request_size == 0 then
          request_size = proto and proto.stack_size or DEFAULT_STACK_SIZE
        end

        if proto then
          section.set_slot(i, {
            value = ing.name,
            mode = "at-least",
            min = request_size,
          })
        end
      end
    end
  end
end

-----------------------------------------------------------------------------
-- Copies the settings from the source entity.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The entity to copy from.
-- @return table: Information about the recipe being crafted.
function lib.copy_settings(game, entity)
  game = game or nil
  local recipe = entity.get_recipe()
  if not recipe then return nil end

  local product = recipe.products and recipe.products[1]
  if not product or not product.name then return nil end

  return {
    source = entity,
    name = product.name,
    ingredients = recipe.ingredients,
  }
end

-----------------------------------------------------------------------------
-- Applies the settings to the target entity.
-- @param game LuaGameScript: The game object.
-- @param data table: Information about the recipe being crafted.
-- @param target LuaEntity: The entity to copy to.
function lib.paste_settings(game, player_index, data, target)
  game = game or nil
  if target.type == "logistic-container" then
    lib.apply_chest_settings(game, player_index, target, data)
  elseif target.type == "inserter" then
    lib.apply_inserter_settings(game, player_index, target, data)
  end
end

-----------------------------------------------------------------------------
-- Automatically copies settings from the target entity to connected inserters
-- and chests, in line with the basic copy/paste semantics of the mod.
-- When a taret CraftinMachine is copied from, and then pasted to, this function
-- locates connected inserters (and chests connected to the inserters) and then
-- applies the settings to them.
-- @param game LuaGameScript: The game object.
-- @param player_index number: The index of the player.
-- @param target LuaEntity: The entity to copy from.
-- @return nil
function lib.autoconfigure_settings(game, player_index, data, target)
  game.print('autconfigure!' .. target.name)

  -- Seemingly counter-intuitively, the target needs to be a valid source.
  if not helpers.is_valid_source(target) then return end

  -- Find nearby inserters.
  local nearby_inserters = target.surface.find_entities_filtered{
    area = helpers.get_area(target.position, 4),
    type = "inserter",
    force = target.force,
  }

  -- Loop through each inserter; only paste settings for inserters which are
  -- linked to both the target and a chest in the "right" direction.
  for _, inserter in ipairs(nearby_inserters) do
    local pt = inserter.pickup_target
    local dt = inserter.drop_target
    -- Look for cases where we have an output inserter dropping into a storage chest.
    if pt and pt == target and helpers.is_storage_chest(dt) then
      lib.paste_settings(game, player_index, data, inserter)
      lib.paste_settings(game, player_index, data, dt)
    -- Look for cases where we have an input inserter pulling from a requester chest.
    elseif dt and dt == target and helpers.is_requester_chest(pt) then
      lib.paste_settings(game, player_index, data, pt)
    end
  end
end


return lib
