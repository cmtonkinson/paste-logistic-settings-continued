local lib = {}

local helpers = require("src.helpers")
local EntityView = require("src.entity_view")

local function get_player_setting(player, name)
  return settings.get_player_settings(player.index)[name]
end

local function get_player_setting_value(player, name, default)
  local setting = get_player_setting(player, name)
  if setting == nil or setting.value == nil then
    return default
  end
  return setting.value
end

local function get_direction_by_name(name)
  if not defines or not defines.direction then
    return nil
  end
  return defines.direction[name]
end

local function get_opposite_direction(direction)
  if not defines or not defines.direction then
    return nil
  end

  local opposites = {
    [defines.direction.north] = defines.direction.south,
    [defines.direction.east] = defines.direction.west,
    [defines.direction.south] = defines.direction.north,
    [defines.direction.west] = defines.direction.east,
  }

  return opposites[direction]
end

-- The stack inserter needs Space Age; without it, fall back to the bulk inserter.
local function normalize_inserter_name(name)
  if name == "stack-inserter" and not prototypes.entity[name] then
    return "bulk-inserter"
  end
  return name
end

local function get_ghost_placement_settings(player)
  return {
    enabled = get_player_setting_value(player, "paste-logistic-settings-continued-enable-ghost-placement", false),
    face = get_player_setting_value(player, "paste-logistic-settings-continued-ghost-direction", "south"),
    input_inserter = normalize_inserter_name(
      get_player_setting_value(player, "paste-logistic-settings-continued-ghost-input-inserter", "bulk-inserter")
    ),
    output_inserter = normalize_inserter_name(
      get_player_setting_value(player, "paste-logistic-settings-continued-ghost-output-inserter", "fast-inserter")
    ),
    output_chest = get_player_setting_value(
      player,
      "paste-logistic-settings-continued-ghost-output-chest",
      "storage-chest"
    ),
  }
end

local function get_adjacent_tangent_offsets(span)
  local centers = {}
  local midpoint = (span + 1) / 2

  for index = 1, span do
    centers[index] = index - midpoint
  end

  local left_index = math.max(1, math.floor(span / 2))
  return {
    input = centers[left_index],
    output = centers[left_index + 1] or centers[left_index],
  }
end

local function get_tile_span(prototype, axis)
  local direct_value = axis == "x" and prototype.tile_width or prototype.tile_height
  if direct_value ~= nil then
    return direct_value
  end

  local box = prototype.selection_box or prototype.collision_box
  if not box or not box.left_top or not box.right_bottom then
    return 1
  end

  local span = box.right_bottom[axis] - box.left_top[axis]
  return math.max(1, math.floor(span + 0.5))
end

local function offset_position(position, dx, dy)
  return {
    x = position.x + dx,
    y = position.y + dy,
  }
end

function lib.get_ghost_placement_layout(entity, placement_settings)
  local view = EntityView.resolve(entity)
  local prototype = view:get_prototype()
  if not prototype then
    return {}
  end

  local face = get_direction_by_name(placement_settings.face)
  if not face then
    return {}
  end

  local tile_width = get_tile_span(prototype, "x")
  local tile_height = get_tile_span(prototype, "y")
  local half_width = tile_width / 2
  local half_height = tile_height / 2
  local tangent_span = (face == defines.direction.east or face == defines.direction.west) and tile_height or tile_width
  local tangent = get_adjacent_tangent_offsets(tangent_span)
  local inward_direction = get_opposite_direction(face)
  local insertion_distance = (face == defines.direction.east or face == defines.direction.west) and (half_width + 0.5)
    or (half_height + 0.5)
  local chest_distance = insertion_distance + 1

  if face == defines.direction.north or face == defines.direction.south then
    local normal_sign = face == defines.direction.south and 1 or -1
    return {
      {
        role = "input_chest",
        name = "requester-chest",
        position = offset_position(entity.position, tangent.input, normal_sign * chest_distance),
      },
      {
        role = "input_inserter",
        name = placement_settings.input_inserter,
        position = offset_position(entity.position, tangent.input, normal_sign * insertion_distance),
        direction = face,
      },
      {
        role = "output_inserter",
        name = placement_settings.output_inserter,
        position = offset_position(entity.position, tangent.output, normal_sign * insertion_distance),
        direction = inward_direction,
      },
      {
        role = "output_chest",
        name = placement_settings.output_chest,
        position = offset_position(entity.position, tangent.output, normal_sign * chest_distance),
      },
    }
  end

  local normal_sign = face == defines.direction.east and 1 or -1
  return {
    {
      role = "input_chest",
      name = "requester-chest",
      position = offset_position(entity.position, normal_sign * chest_distance, tangent.input),
    },
    {
      role = "input_inserter",
      name = placement_settings.input_inserter,
      position = offset_position(entity.position, normal_sign * insertion_distance, tangent.input),
      direction = face,
    },
    {
      role = "output_inserter",
      name = placement_settings.output_inserter,
      position = offset_position(entity.position, normal_sign * insertion_distance, tangent.output),
      direction = inward_direction,
    },
    {
      role = "output_chest",
      name = placement_settings.output_chest,
      position = offset_position(entity.position, normal_sign * chest_distance, tangent.output),
    },
  }
end

local function is_compatible_placement_entity(entity, spec)
  local view = EntityView.resolve(entity)
  if spec.role == "input_chest" then
    return view:is_requester_chest()
  elseif spec.role == "output_chest" then
    return view:is_logistic_container() and view:get_name() == spec.name
  elseif spec.role == "input_inserter" or spec.role == "output_inserter" then
    return view:is_inserter() and entity.direction == spec.direction
  end
  return false
end

function lib.find_placement_entity(surface, force, spec)
  local found = surface.find_entities_filtered({
    position = spec.position,
    force = force,
  })
  local has_occupant = false
  for _, entity in ipairs(found) do
    has_occupant = true
    if is_compatible_placement_entity(entity, spec) then
      return entity, true
    end
  end
  return nil, has_occupant
end

local function create_requester_ghost_from_blueprint(surface, force, spec, player, data)
  if not game.create_inventory or not player then
    return nil
  end

  local inventory = game.create_inventory(1)
  if not inventory or not inventory.valid or not inventory[1] then
    return nil
  end

  local stack = inventory[1]
  local ok = pcall(function()
    stack.set_stack("blueprint")
    stack.set_blueprint_entities({
      {
        entity_number = 1,
        name = spec.name,
        position = { x = 0, y = 0 },
        request_filters = {
          sections = {
            {
              index = 1,
              filters = (function()
                local filters = {}
                for index, ingredient in ipairs(EntityView.item_ingredients_only(data and data.ingredients)) do
                  local prototype = prototypes.item[ingredient.name]
                  if prototype then
                    filters[#filters + 1] = {
                      index = index,
                      name = ingredient.name,
                      quality = helpers.get_quality_string(data.quality),
                      count = helpers.get_request_quota(player, prototype),
                      comparator = "=",
                    }
                  end
                end
                return filters
              end)(),
            },
          },
        },
      },
    })
  end)
  if not ok then
    inventory.destroy()
    return nil
  end
  if not stack.is_blueprint_setup() then
    inventory.destroy()
    return nil
  end

  local ok_build, entities = pcall(function()
    return stack.build_blueprint({
      surface = surface,
      force = force,
      position = spec.position,
      build_mode = defines and defines.build_mode and defines.build_mode.forced or nil,
      raise_built = false,
    })
  end)

  inventory.destroy()

  if not ok_build or not entities then
    return nil
  end

  if entities[1] then
    return entities[1]
  end

  for _, entity in pairs(entities) do
    if entity ~= nil then
      return entity
    end
  end

  return nil
end

function lib.create_ghost_entity(surface, force, spec, player, data)
  if spec.role == "input_chest" then
    local requester = create_requester_ghost_from_blueprint(surface, force, spec, player, data)
    if requester then
      return requester
    end
  end

  local params = {
    name = "entity-ghost",
    inner_name = spec.name,
    position = spec.position,
    force = force,
  }
  if spec.direction ~= nil then
    params.direction = spec.direction
  end

  local ok, entity = pcall(function()
    return surface.create_entity(params)
  end)
  if not ok then
    return nil
  end
  return entity
end

local function configure_placement_entity(player, entity, spec, data)
  if not entity then
    return
  end
  local view = EntityView.resolve(entity)
  if spec.role == "input_chest" then
    if not view.is_ghost then
      lib.paste_settings(player, entity, data)
    end
    return
  end
  if spec.role == "output_inserter" or spec.role == "output_chest" then
    lib.paste_settings(player, entity, data)
  end
end

function lib.ensure_ghost_layout(player, target, data)
  local placement_settings = get_ghost_placement_settings(player)
  if not placement_settings.enabled then
    return {}
  end

  local processed = {}
  local specs = lib.get_ghost_placement_layout(target, placement_settings)

  for _, spec in ipairs(specs) do
    local entity, has_occupant = lib.find_placement_entity(target.surface, target.force, spec)
    if not entity and not has_occupant then
      entity = lib.create_ghost_entity(target.surface, target.force, spec, player, data)
    end
    if entity then
      if spec.role ~= "input_chest" or EntityView.resolve(entity).is_ghost then
        processed[entity] = true
      end
      configure_placement_entity(player, entity, spec, data)
    end
  end

  return processed
end

-----------------------------------------------------------------------------
-- The limit governs what the inserter puts into the chest it feeds, so the text
-- goes over that chest; over the inserter when it feeds anything else.
local function get_output_limit_text_anchor(inserter_view)
  local drop_target = inserter_view:get_drop_target()
  local drop_view = EntityView.resolve(drop_target)
  if drop_view.valid and drop_view:is_logistic_container() then
    return drop_target
  end
  return inserter_view.entity
end

-----------------------------------------------------------------------------
function lib.show_output_limit_text(player, inserter_view, data, result)
  if not data or not result or not result.ok or not result.limit then
    return
  end
  -- Ghosts get placed speculatively, often several at once; announcing a limit
  -- for each would bury the player in text.
  if inserter_view.is_ghost then
    return
  end
  if not get_player_setting_value(player, "paste-logistic-settings-continued-show-output-limit-text", true) then
    return
  end
  if type(player.create_local_flying_text) ~= "function" then
    return
  end

  local prototype = prototypes.item[data.name]
  if not prototype then
    return
  end

  local text = helpers.build_output_limit_text(
    prototype,
    result.limit,
    get_player_setting_value(player, "paste-logistic-settings-continued-output-limit-text-stacks", true),
    get_player_setting_value(player, "paste-logistic-settings-continued-output-limit-text-items", true)
  )
  if not text then
    return
  end

  local anchor = get_output_limit_text_anchor(inserter_view)
  if not anchor or anchor.valid == false or not anchor.position then
    return
  end

  -- No speed or time_to_live: Factorio stretches both for text over 25
  -- characters, which this usually is.
  pcall(function()
    player.create_local_flying_text({
      text = text,
      position = anchor.position,
      surface = anchor.surface,
    })
  end)
end

-----------------------------------------------------------------------------
function lib.apply_inserter_settings(player, inserter, data)
  local view = EntityView.resolve(inserter)
  local result = view:apply_inserter_settings(player, data)
  lib.show_output_limit_text(player, view, data, result)
  return result
end

-----------------------------------------------------------------------------
function lib.apply_chest_settings(player, entity, data)
  local view = EntityView.resolve(entity)
  if view:is_storage_chest() then
    view:apply_storage_settings(player, data)
  elseif view:is_requester_chest() then
    view:apply_requester_settings(player, data)
  end
end

-----------------------------------------------------------------------------
-- Returns the recipe data to paste, or nil when the entity has no recipe.
function lib.copy_settings(player, entity)
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
function lib.paste_settings(player, target, data)
  local view = EntityView.resolve(target)
  if view:is_logistic_container() then
    lib.apply_chest_settings(player, target, data)
  elseif view:is_inserter() then
    lib.apply_inserter_settings(player, target, data)
  end
end

-----------------------------------------------------------------------------
-- Pastes onto the inserters around a crafting machine and the chests they feed
-- or draw from.
function lib.autoconfigure_settings(player, target, data)
  local target_view = EntityView.resolve(target)
  -- The target is a crafting machine, so it must pass the source check.
  if not target_view:is_valid_source() then
    return
  end
  local processed = lib.ensure_ghost_layout(player, target, data)
  -- Reach a long-handed inserter two tiles out from any side of the machine.
  local prototype = target_view:get_prototype()
  local radius = prototype and math.max(get_tile_span(prototype, "x"), get_tile_span(prototype, "y")) / 2 + 2.5 or 4
  local nearby_inserters = target.surface.find_entities_filtered({
    area = helpers.get_area(target, radius),
    force = target.force,
    type = { "inserter", "entity-ghost" },
  })

  for _, candidate in ipairs(nearby_inserters) do
    local inserter_view = EntityView.resolve(candidate)
    if inserter_view:is_inserter() and not processed[candidate] then
      local pt = inserter_view:get_pickup_target()
      local dt = inserter_view:get_drop_target()
      -- Output inserter dropping into a storage chest.
      if pt and pt.valid and pt == target and EntityView.resolve(dt):is_storage_chest() then
        if not processed[candidate] then
          lib.paste_settings(player, candidate, data)
          processed[candidate] = true
        end
        if dt and not processed[dt] then
          lib.paste_settings(player, dt, data)
          processed[dt] = true
        end
      -- Input inserter pulling from a requester chest.
      elseif dt and dt.valid and dt == target and EntityView.resolve(pt):is_requester_chest() then
        if pt and not processed[pt] then
          lib.paste_settings(player, pt, data)
          processed[pt] = true
        end
      end
    end
  end
end

return lib
