local function is_valid_source(entity)
  return entity
    and entity.valid
    and entity.get_recipe
    and entity.get_recipe() ~= nil
end

local function is_valid_target(entity)
  return entity
    and entity.valid
    and (
      entity.type == "logistic-container"
      or (entity.type == "inserter" and entity.get_or_create_control_behavior)
    )
end

local function copy_settings(entity)
  local recipe = entity.get_recipe()
  if not recipe then return nil end

  local product = recipe.products and recipe.products[1]
  if not product or not product.name then return nil end

  return {
    type = "recipe-output",
    name = product.name
  }
end

local function paste_settings(data, target)
  local product_name = data.name
  local item_proto = prototypes.item[product_name]
  local stack_size = item_proto and item_proto.stack_size or 17

  if target.type == "logistic-container" then
		target.storage_filter = prototypes.item[product_name]

  elseif target.type == "inserter" and target.get_or_create_control_behavior then
    local behavior = target.get_or_create_control_behavior()
    behavior.connect_to_logistic_network = true
    behavior.logistic_condition = {
      comparator = "<",
      first_signal = { type = "item", name = product_name },
      constant = stack_size
    }
  end
end

script.on_init(function()
	if not global then global = {} end
  global.paste_data = {}
end)

-- Copy hotkey
script.on_event("paste-logistic-settings-continued-copy", function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local selected = player.selected
  if not is_valid_source(selected) then
    player.create_local_flying_text{
      text = "Not a valid recipe source",
      position = player.position,
      color = { r = 1, g = 0.5, b = 0.5 }
    }
    return
  end

  if not global then global = {} end
  global.paste_data = global.paste_data or {}
  global.paste_data[event.player_index] = copy_settings(selected)

  player.create_local_flying_text{
    text = "Copied recipe output",
    position = selected.position,
    color = { r = 1, g = 1, b = 0.2 }
  }
end)

-- Paste hotkey
script.on_event("paste-logistic-settings-continued-paste", function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local selected = player.selected
  if not is_valid_target(selected) then
    player.create_local_flying_text{
      text = "Not a valid target",
      position = player.position,
      color = { r = 1, g = 0.4, b = 0.4 }
    }
    return
  end

  if not global then global = {} end
  global.paste_data = global.paste_data or {}
  local data = global.paste_data[event.player_index]

  if not data then
    player.create_local_flying_text{
      text = "Nothing copied yet",
      position = selected.position,
      color = { r = 1, g = 0.5, b = 0.2 }
    }
    return
  end

  paste_settings(data, selected)

  player.create_local_flying_text{
    text = "Pasted recipe output",
    position = selected.position,
    color = { r = 0.5, g = 1, b = 0.5 }
  }
end)

