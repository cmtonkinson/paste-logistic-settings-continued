local lib = {}

local helpers = require("src.helpers")
local EntityView = require("src.entity_view")

-----------------------------------------------------------------------------
-- Applies the settings to an inserter.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The inserter to configure.
-- @param data table: Information about the recipe being crafted.
-- @return nil
function lib.apply_inserter_settings(game, player, inserter, data)
  EntityView.resolve(inserter):apply_inserter_settings(game, player, data)
end

-----------------------------------------------------------------------------
-- Checks if the filters in the given logistic section match the ingredients
-- of the given recipe.
-- @param game LuaGameScript: The game object.
-- @param filters table: The filters to check.
-- @param ingredients table: The ingredients to check against.
-- @return boolean: True if the filters match the ingredients, false otherwise.
function lib.has_same_ingredient_names(game, player, filters, ingredients)
  return EntityView.has_same_ingredient_names(filters, ingredients)
end

-----------------------------------------------------------------------------
-- Return a LuaLogisticSection suitable for configuring slots with the ingredients.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The entity to configure.
-- @param data table: Information about the recipe being crafted.
-- @return LuaLogisticSection: The section to configure.
-- Ensures it does not create uneccessary sections, and will override an existing
-- section if the ingredients are the same (quantity and order may be overridden).
function lib.get_or_create_section(game, player, entity, data)
  return EntityView.resolve(entity):get_or_create_request_section(data)
end

-----------------------------------------------------------------------------
-- Applies the settings to a chest.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The chest to copy to.
-- @param data table: Information about the recipe being crafted.
-- @return nil
function lib.apply_chest_settings(game, player, entity, data)
  local view = EntityView.resolve(entity)
  if view:is_storage_chest() then
    view:apply_storage_settings(game, player, data)
  elseif view:is_requester_chest() then
    view:apply_requester_settings(game, player, data)
  end
end

-----------------------------------------------------------------------------
-- Copies the settings from the source entity.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The entity to copy from.
-- @return table: Information about the recipe being crafted.
function lib.copy_settings(game, player, entity)
  local view = EntityView.resolve(entity)
  local data = {}
  local recipe, quality = view:get_recipe()
  local quality_level = 0
  if not recipe then
    return nil
  end

  data.source = entity
  data.source_name = view:get_name()
  data.source_type = view:get_type()
  if quality and quality.level ~= nil then
    quality_level = quality.level
  end

  local product = nil
  if recipe.products then
    for _, prod in ipairs(recipe.products) do
      if prototypes.item[prod.name] then
        product = prod
        break
      end
    end
  end
  if product and product.name then
    data.item = true
    data.name = product.name
    data.quality = quality_level
  end

  -- We only want to deal with items, not fluids, so we check prototypes
  -- and ignore fluids.
  local item_ingredients = {}
  for _, ing in ipairs(recipe.ingredients) do
    local proto = prototypes.item[ing.name]
    if proto then
      table.insert(item_ingredients, {
        name = ing.name,
        amount = ing.amount,
        stack_size = proto.stack_size,
        quality = quality_level,
      })
    end
  end
  data.ingredients = item_ingredients

  return data
end

-----------------------------------------------------------------------------
-- Applies the settings to the target entity.
-- @param game LuaGameScript: The game object.
-- @param data table: Information about the recipe being crafted.
-- @param target LuaEntity: The entity to copy to.
-- @return nil
function lib.paste_settings(game, player, target, data)
  local view = EntityView.resolve(target)
  if view:is_logistic_container() then
    lib.apply_chest_settings(game, player, target, data)
  elseif view:is_inserter() then
    lib.apply_inserter_settings(game, player, target, data)
  end
end

-----------------------------------------------------------------------------
-- Automatically copies settings from the target entity to connected inserters
-- and chests, in line with the basic copy/paste semantics of the mod.
-- When a taret CraftinMachine is copied from, and then pasted to, this function
-- locates connected inserters (and chests connected to the inserters) and then
-- applies the settings to them.
-- @param game LuaGameScript: The game object.
-- @param player.index number: The index of the player.
-- @param target LuaEntity: The entity to copy from.
-- @return nil
function lib.autoconfigure_settings(game, player, target, data)
  local target_view = EntityView.resolve(target)
  -- Seemingly counter-intuitively, the target needs to be a valid source.
  if not target_view:is_valid_source() then
    return
  end
  -- Find nearby inserters.
  local nearby_inserters = target.surface.find_entities_filtered({
    area = helpers.get_area(game, target, 4),
    force = target.force,
  })

  -- Loop through each inserter; only paste settings for inserters which are
  -- linked to both the target and a chest in the "right" direction.
  for _, candidate in ipairs(nearby_inserters) do
    local inserter_view = EntityView.resolve(candidate)
    if inserter_view:is_inserter() then
      local pt = inserter_view:get_pickup_target()
      local dt = inserter_view:get_drop_target()
      -- Look for cases where we have an output inserter dropping into a storage chest.
      if pt and pt.valid and pt == target and EntityView.resolve(dt):is_storage_chest() then
        lib.paste_settings(game, player, candidate, data)
        lib.paste_settings(game, player, dt, data)
      -- Look for cases where we have an input inserter pulling from a requester chest.
      elseif dt and dt.valid and dt == target and EntityView.resolve(pt):is_requester_chest() then
        lib.paste_settings(game, player, pt, data)
      end
    end
  end
end

return lib
