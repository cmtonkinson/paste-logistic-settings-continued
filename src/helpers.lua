local helpers = {}

-----------------------------------------------------------------------------
-- Returns how many items should be allowed/requested.
-- @param prototype LuaItemPrototype: The item prototype.
-- @param limit_type string: The type of limit to apply (stacks or items).
-- @param limit number: The limit to apply.
-- @return number: The calculated limit.
function helpers.get_limit(prototype, limit_type, limit)
  if limit_type == "stacks" then
    return prototype.stack_size * limit
  elseif limit_type == "items" then
    return limit
  end
  return 0
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

-----------------------------------------------------------------------------
-- Resolves a quality level to its quality prototype name.
-- Looked up from the game's own quality prototypes rather than a fixed table:
-- vanilla leaves level 4 unused, so a hardcoded map silently reported any tier
-- a mod placed there as "normal", pasting the wrong quality filter.
-- @param quality_id number: The quality level.
-- @return string: The quality name, or "normal" when nothing claims the level.
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
