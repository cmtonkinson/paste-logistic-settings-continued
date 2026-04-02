local lib = {}

local helpers = require("src.helpers")

local function item_ingredients_only(ingredients)
  local filtered = {}
  for _, ingredient in ipairs(ingredients or {}) do
    if prototypes.item[ingredient.name] then
      filtered[#filtered + 1] = ingredient
    end
  end
  return filtered
end

-----------------------------------------------------------------------------
-- Applies the settings to an inserter.
-- @param game LuaGameScript: The game object.
-- @param entity LuaEntity: The inserter to configure.
-- @param data table: Information about the recipe being crafted.
-- @return nil
function lib.apply_inserter_settings(game, player, inserter, data)
  local behavior = inserter.get_or_create_control_behavior()
  if not data then
    return
  end
  if not behavior then
    return
  end

  if not data.item then
    return
  end -- happens when the output is a fluid

  local proto = prototypes.item[data.name]
  if not proto then
    return
  end -- e.g. fluids don't have a useful prototype
  local output_limit_type =
    settings.get_player_settings(player.index)["paste-logistic-settings-continued-output-limit-type"].value
  local output_limit =
    settings.get_player_settings(player.index)["paste-logistic-settings-continued-output-limit"].value
  local accumulate_setting =
    settings.get_player_settings(player.index)["paste-logistic-settings-continued-accumulate-inserter-output-limit"]
  local accumulate_output_limit = true
  if accumulate_setting and accumulate_setting.value ~= nil then
    accumulate_output_limit = accumulate_setting.value
  end
  local limit = helpers.get_limit(game, proto, output_limit_type, output_limit)
  local existing_condition = behavior.logistic_condition

  if accumulate_output_limit and existing_condition then
    local existing_first_signal = existing_condition.first_signal
    local existing_signal = existing_first_signal and (existing_first_signal.signal or existing_first_signal)
    if existing_signal and existing_signal.name == data.name and existing_condition.comparator == "<" then
      limit = limit + (existing_condition.constant or 0)
    end
  end

  behavior.connect_to_logistic_network = true
  behavior.logistic_condition = {
    comparator = "<",
    first_signal = { type = "item", name = data.name, quality = helpers.get_quality_string(data.quality) },
    constant = limit,
  }
end

-----------------------------------------------------------------------------
-- Checks if the filters in the given logistic section match the ingredients
-- of the given recipe.
-- @param game LuaGameScript: The game object.
-- @param filters table: The filters to check.
-- @param ingredients table: The ingredients to check against.
-- @return boolean: True if the filters match the ingredients, false otherwise.
function lib.has_same_ingredient_names(game, player, filters, ingredients)
  if table_size(filters) ~= table_size(ingredients) then
    return false
  end

  local ingredient_names = helpers.pluck_set(ingredients, "name")
  local filter_names = helpers.pluck_set(helpers.pluck(filters, "value"), "name")

  for ing, _ in pairs(ingredient_names) do
    if ing ~= "" and not filter_names[ing] then
      return false
    end
  end

  return true
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
  -- Get the LuaLogisticPoint for the given LuaEntity.
  local point = entity.get_logistic_point(0)
  if not point then
    return
  end
  local ingredients = item_ingredients_only(data and data.ingredients)

  -- If there are existing sections...
  if point.sections_count > 0 then
    -- Reuse the starter blank section only when it is the only section.
    if point.sections_count == 1 then
      local sec = point.sections[1]
      if sec.filters_count == 0 and sec.group == "" then
        return sec
      end
    else
      for idx = point.sections_count, 1, -1 do
        local sec = point.sections[idx]
        if sec.filters_count == 0 and sec.group == "" then
          point.remove_section(idx)
        end
      end
    end
    -- If none are empty, does one section match exactly the kind of ingredients
    -- we need for this recipe? If so, clear the filters and return it. This is
    -- easier than knowing which filter is in which slot and then updating their
    -- quantities; it's easier to just nuke the section and let the client code
    -- pave over it.
    for idx, sec in ipairs(point.sections) do
      if sec.group == "" and lib.has_same_ingredient_names(game, player, sec.filters, ingredients) then
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
-- @return nil
function lib.apply_chest_settings(game, player, entity, data)
  local quality_string = helpers.get_quality_string(data.quality)
  if helpers.is_storage_chest(game, entity) then
    if not data.item then
      return
    end -- happens when the output is a fluid
    entity.storage_filter = {
      name = data.name,
      quality = quality_string,
    }
  elseif helpers.is_requester_chest(game, entity) then
    local section = lib.get_or_create_section(game, player, entity, data)
    local ingredients = item_ingredients_only(data and data.ingredients)
    if section and ingredients then
      for i, ing in ipairs(ingredients) do
        local proto = prototypes.item[ing.name]
        if proto then -- e.g. fluids don't have a useful prototype
          local request_size_type =
            settings.get_player_settings(player.index)["paste-logistic-settings-continued-request-size-type"].value
          local request_size =
            settings.get_player_settings(player.index)["paste-logistic-settings-continued-request-size"].value
          local quota = helpers.get_limit(game, proto, request_size_type, request_size)
          section.set_slot(i, {
            value = {
              name = ing.name,
              quality = quality_string,
            },
            mode = "at-least",
            min = quota,
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
function lib.copy_settings(game, player, entity)
  local data = {}
  local recipe, quality = entity.get_recipe()
  if not recipe then
    return nil
  end

  data.source = entity
  quality = quality or 1

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
    data.quality = quality.level
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
        quality = data.quality,
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
  if target.type == "logistic-container" then
    lib.apply_chest_settings(game, player, target, data)
  elseif target.type == "inserter" then
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
  -- Seemingly counter-intuitively, the target needs to be a valid source.
  if not helpers.is_valid_source(game, target) then
    return
  end
  -- Find nearby inserters.
  local nearby_inserters = target.surface.find_entities_filtered({
    area = helpers.get_area(game, target, 4),
    type = "inserter",
    force = target.force,
  })

  -- Loop through each inserter; only paste settings for inserters which are
  -- linked to both the target and a chest in the "right" direction.
  for _, inserter in ipairs(nearby_inserters) do
    local pt = inserter.pickup_target
    local dt = inserter.drop_target
    -- Look for cases where we have an output inserter dropping into a storage chest.
    if pt and pt.valid and pt == target and helpers.is_storage_chest(game, dt) then
      lib.paste_settings(game, player, inserter, data)
      lib.paste_settings(game, player, dt, data)
    -- Look for cases where we have an input inserter pulling from a requester chest.
    elseif dt and dt.valid and dt == target and helpers.is_requester_chest(game, pt) then
      lib.paste_settings(game, player, pt, data)
    end
  end
end

return lib
