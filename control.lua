-----------------------------------------------------------------------------
-- Prefix all events to avoid conflicts.
local EVENT_NAMESPACE = "paste-logistic-settings-continued"
-- Fallback value to use for stack sizes if all else fails.
local DEFAULT_STACK_SIZE = 1

-----------------------------------------------------------------------------
-- Determines whether the entity is valid for copying FROM.
-- @param entity LuaEntity: THe entityt to test.
-- @return boolean: True only if the entity is valid for copying.

local function is_valid_source(entity)
  return entity
    and entity.valid
    and entity.get_recipe
    and entity.get_recipe() ~= nil
end

-----------------------------------------------------------------------------
-- Determines whether the entity is valid for copying TO.
-- @param entity LuaEntity: The entity to test.
-- @return boolean: True only if the entity is valid for copying.

local function is_valid_target(entity)
  return entity
    and entity.valid
    and (
      entity.type == "logistic-container"
      or (entity.type == "inserter" and entity.get_or_create_control_behavior)
    )
end

-----------------------------------------------------------------------------
-- Copies the settings from the source entity.
-- @param entity LuaEntity: The entity to copy from.
-- @return table: Information about the recipe being crafted.

local function copy_settings(entity)
  local recipe = entity.get_recipe()
  if not recipe then return nil end

  local product = recipe.products and recipe.products[1]
  if not product or not product.name then return nil end

  return {
    name = product.name,
    ingredients = recipe.ingredients,
  }
end

-----------------------------------------------------------------------------
--- Applies the settings to an inserter.
-- @param entity LuaEntity: The inserter to configure.
-- @param data table: Information about the recipe being crafted.
-- @return nil
local function apply_inserter_settings(player_index, inserter, data)
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
-- Applies the settings to a chest.
-- @param entity LuaEntity: The chest to copy to.
-- @param data table: Information about the recipe being crafted.
local function apply_chest_settings(player_index, chest, data)
  local mode = chest.prototype.logistic_mode

  if mode == "storage" then
    chest.storage_filter = prototypes.item[data.name]

  elseif mode == "requester" or mode == "buffer" then
    local point = chest.get_logistic_point(0)
    local section = point.add_section()
    if data.ingredients then
      for i, ing in ipairs(data.ingredients) do
        local proto = prototypes.item[ing.name]
        -- The runtime per user setting `request-size` controls how many of each
        -- ingredient the chest will request. A (default) value of 0 means use the
        -- native stack size of each item. A positive value overrides that behavior.
        local request_size= settings.get_player_settings(player_index)["paste-logistic-settings-continued-request-size"].value
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
-- Applies the settings to the target entity.
-- @param data table: Information about the recipe being crafted.
-- @param target LuaEntity: The entity to copy to.
local function paste_settings(player_index, data, target)
  if target.type == "logistic-container" then
    apply_chest_settings(player_index, target, data)
  elseif target.type == "inserter" then
    apply_inserter_settings(player_index, target, data)
  end
end

-----------------------------------------------------------------------------
-- Copy hotkey
script.on_event(EVENT_NAMESPACE .. "-copy", function(event)
  local player = game.players[event.player_index]
  local selected = player.selected
  if not is_valid_source(selected) then return end

  global = global or {}
  global.paste_data = global.paste_data or {}

  global.paste_data[event.player_index] = copy_settings(selected)
end)

-----------------------------------------------------------------------------
-- Paste hotkey
script.on_event(EVENT_NAMESPACE .. "-paste", function(event)
  local player = game.players[event.player_index]
  local selected = player.selected
  if not is_valid_target(selected) then return end

  global = global or {}
  global.paste_data = global.paste_data or {}
  local data = global.paste_data[event.player_index]

  paste_settings(event.player_index, data, selected)
end)
