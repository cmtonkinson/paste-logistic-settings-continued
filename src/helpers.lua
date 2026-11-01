local helpers = {}

-----------------------------------------------------------------------------
-- Returns how many items to allow or request; 0 for an unknown limit_type.
function helpers.get_limit(prototype, limit_type, limit)
  if limit_type == "stacks" then
    return prototype.stack_size * limit
  elseif limit_type == "items" then
    return limit
  end
  return 0
end

-----------------------------------------------------------------------------
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

-----------------------------------------------------------------------------
-- Resolves a quality level from the game's quality prototypes, not a fixed
-- table: vanilla leaves level 4 unused and mods can fill it. Returns "normal"
-- when nothing claims the level.
function helpers.get_quality_string(quality_id)
  if type(quality_id) ~= "number" then
    return "normal"
  end

  local registry = rawget(_G, "prototypes")
  local qualities = registry and registry.quality
  if qualities then
    for _, quality in pairs(qualities) do
      if quality.level == quality_id then
        return quality.name
      end
    end
  end

  return "normal"
end

-----------------------------------------------------------------------------
-- Formats an amount for display: "2" for 2.0, "1.5" for 1.5, "0.33" for 1/3.
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
-- Builds the output limit text, e.g. "1 stack / 100x [item=transport-belt]";
-- nil when there is nothing to show. limit is in items.
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

  -- Built in Lua, not a locale entry: Factorio resolves rich text before
  -- substituting __N__ parameters, so "[item=__2__]" in a .cfg renders nothing.
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
-- The hotkeys share super force build's modifiers, so they do nothing while the
-- cursor holds anything.
function helpers.is_holding_anything(game, player, event)
  if not player.is_cursor_empty() then
    return true
  end
end

return helpers
