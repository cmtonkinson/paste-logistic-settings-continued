local EntityView = {}

local ViewMethods = {}

local function with_view(entity_or_view)
  if entity_or_view and entity_or_view.entity and getmetatable(entity_or_view) == EntityView.metatable then
    return entity_or_view
  end
  return EntityView.resolve(entity_or_view)
end

local function item_ingredients_only(ingredients)
  local filtered = {}
  for _, ingredient in ipairs(ingredients or {}) do
    if prototypes.item[ingredient.name] then
      filtered[#filtered + 1] = ingredient
    end
  end
  return filtered
end

local function pluck_set(tbl, key)
  local set = {}
  for _, entry in ipairs(tbl or {}) do
    set[entry[key]] = true
  end
  return set
end

local function get_limit(prototype, limit_type, limit)
  if limit_type == "stacks" then
    return prototype.stack_size * limit
  elseif limit_type == "items" then
    return limit
  end
  return 0
end

local function get_quality_string(quality_id)
  local mapping = {
    [0] = "normal",
    [1] = "uncommon",
    [2] = "rare",
    [3] = "epic",
    [5] = "legendary",
  }

  if not quality_id or mapping[quality_id] == nil then
    return "normal"
  end

  return mapping[quality_id]
end

local function ok_result()
  return { ok = true }
end

local function fail_result(reason, detail)
  return { ok = false, reason = reason, detail = detail }
end

local function collect_sections(sections_owner)
  local sections = sections_owner and sections_owner.sections or {}
  local collected = {}
  local sections_count = sections_owner and sections_owner.sections_count or nil

  if sections_count ~= nil then
    for index = 1, sections_count do
      local section = sections[index]
      if section == nil then
        break
      end
      collected[#collected + 1] = section
    end
    return collected
  end

  local index = 1
  while sections[index] ~= nil do
    collected[#collected + 1] = sections[index]
    index = index + 1
  end

  return collected
end

local function compact_array(...)
  local compacted = {}
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if value ~= nil then
      compacted[#compacted + 1] = value
    end
  end
  return compacted
end

EntityView.metatable = { __index = ViewMethods }

function EntityView.resolve(entity)
  local valid = entity ~= nil and entity.valid ~= false
  local is_ghost = valid and entity.type == "entity-ghost" or false
  local prototype = valid and entity.prototype or nil
  local effective_prototype = prototype
  local effective_name = valid and entity.name or nil
  local effective_type = valid and entity.type or nil

  if is_ghost then
    effective_prototype = entity.ghost_prototype
    effective_name = entity.ghost_name
    effective_type = entity.ghost_type
  end

  return setmetatable({
    entity = entity,
    valid = valid,
    is_ghost = is_ghost,
    outer_name = valid and entity.name or nil,
    outer_type = valid and entity.type or nil,
    outer_prototype = prototype,
    name = effective_name,
    type = effective_type,
    prototype = effective_prototype,
  }, EntityView.metatable)
end

function EntityView.same_effective_name(a, b)
  return with_view(a):same_effective_name(b)
end

function EntityView.has_same_ingredient_names(filters, ingredients)
  if table_size(filters) ~= table_size(ingredients) then
    return false
  end

  local ingredient_names = pluck_set(ingredients, "name")
  local filter_values = {}
  for _, filter in ipairs(filters or {}) do
    filter_values[#filter_values + 1] = filter.value or {}
  end
  local filter_names = pluck_set(filter_values, "name")

  for ingredient_name in pairs(ingredient_names) do
    if ingredient_name ~= "" and not filter_names[ingredient_name] then
      return false
    end
  end

  return true
end

function EntityView.item_ingredients_only(ingredients)
  return item_ingredients_only(ingredients)
end

function ViewMethods:get_name()
  return self.name
end

function ViewMethods:get_type()
  return self.type
end

function ViewMethods:get_prototype()
  return self.prototype
end

function ViewMethods:get_logistic_mode()
  local prototype = self:get_prototype()
  if not prototype then
    return nil
  end
  return prototype.logistic_mode
end

function ViewMethods:is_logistic_container()
  return self:get_type() == "logistic-container"
end

function ViewMethods:is_inserter()
  return self:get_type() == "inserter"
end

function ViewMethods:same_effective_name(other)
  local other_view = with_view(other)
  return self:get_name() ~= nil and self:get_name() == other_view:get_name()
end

function ViewMethods:get_recipe()
  if not self.valid or not self.entity or not self.entity.get_recipe then
    return nil, nil, "missing-get-recipe"
  end

  local ok, recipe, quality = pcall(self.entity.get_recipe, self.entity)
  if not ok then
    return nil, nil, "get-recipe-failed"
  end

  return recipe, quality, nil
end

function ViewMethods:is_crafting_machine()
  if not self.valid or not self.entity or not self.entity.get_recipe then
    return false
  end

  local ok = pcall(self.entity.get_recipe, self.entity)
  return ok
end

function ViewMethods:is_valid_source()
  local recipe = self:get_recipe()
  return self:is_crafting_machine() and recipe ~= nil
end

function ViewMethods:is_valid_target()
  return self.valid
    and (
      self:is_valid_source()
      or self:is_logistic_container()
      or (self:is_inserter() and self.entity and self.entity.get_or_create_control_behavior)
    )
end

function ViewMethods:is_requester_chest()
  local mode = self:get_logistic_mode()
  return self:is_logistic_container() and (mode == "requester" or mode == "buffer")
end

function ViewMethods:is_storage_chest()
  return self:is_logistic_container() and self:get_logistic_mode() == "storage"
end

function ViewMethods:get_logistic_point(index)
  if not self.valid or not self.entity or not self.entity.get_logistic_point then
    return nil, "missing-get-logistic-point"
  end

  local logistic_index = index
  if
    logistic_index == nil
    and defines
    and defines.logistic_member_index
    and defines.logistic_member_index.logistic_container
  then
    logistic_index = defines.logistic_member_index.logistic_container
  end

  local ok, point
  if logistic_index == nil then
    ok, point = pcall(self.entity.get_logistic_point, self.entity)
  else
    ok, point = pcall(self.entity.get_logistic_point, self.entity, logistic_index)
  end
  if not ok then
    return nil, "get-logistic-point-failed"
  end

  return point, nil
end

function ViewMethods:get_requester_point()
  if not self.valid or not self.entity or not self.entity.get_requester_point then
    return nil, "missing-get-requester-point"
  end

  local ok, point = pcall(self.entity.get_requester_point, self.entity)
  if not ok then
    return nil, "get-requester-point-failed"
  end

  return point, nil
end

function ViewMethods:get_logistic_sections(index)
  if not self.valid or not self.entity or not self.entity.get_logistic_sections then
    return nil, "missing-get-logistic-sections"
  end

  local ok, sections
  if index ~= nil then
    ok, sections = pcall(self.entity.get_logistic_sections, self.entity, index)
  elseif self.is_ghost then
    ok, sections = pcall(self.entity.get_logistic_sections, self.entity, 0)
    if ok and sections then
      return sections, nil
    end
    ok, sections = pcall(self.entity.get_logistic_sections, self.entity)
  else
    ok, sections = pcall(self.entity.get_logistic_sections, self.entity)
  end
  if not ok then
    return nil, "get-logistic-sections-failed"
  end

  return sections, nil
end

function ViewMethods:get_or_create_control_behavior()
  if not self.valid or not self.entity or not self.entity.get_or_create_control_behavior then
    return nil, "missing-get-or-create-control-behavior"
  end

  local ok, behavior = pcall(self.entity.get_or_create_control_behavior, self.entity)
  if not ok then
    return nil, "get-or-create-control-behavior-failed"
  end

  return behavior, nil
end

function ViewMethods:get_pickup_target()
  if not self.entity then
    return nil, "missing-entity"
  end

  local ok, target = pcall(function()
    return self.entity.pickup_target
  end)
  if not ok then
    return nil, "pickup-target-failed"
  end

  return target, nil
end

function ViewMethods:get_drop_target()
  if not self.entity then
    return nil, "missing-entity"
  end

  local ok, target = pcall(function()
    return self.entity.drop_target
  end)
  if not ok then
    return nil, "drop-target-failed"
  end

  return target, nil
end

function ViewMethods:get_or_create_request_section(data)
  local sections_owner
  local requester_point, requester_reason = self:get_requester_point()
  local logistic_sections_zero, logistic_sections_zero_reason = self:get_logistic_sections(0)
  local logistic_sections, logistic_sections_reason = self:get_logistic_sections()
  local logistic_point_zero, logistic_zero_reason = self:get_logistic_point(0)
  local logistic_point, logistic_reason = self:get_logistic_point()
  local candidates
  if self.is_ghost then
    candidates = compact_array(
      logistic_point_zero,
      logistic_point_zero and logistic_point_zero.sections or nil,
      logistic_sections_zero,
      logistic_sections,
      requester_point,
      requester_point and requester_point.sections or nil,
      logistic_point,
      logistic_point and logistic_point.sections or nil
    )
  else
    candidates = compact_array(
      logistic_sections_zero,
      logistic_sections,
      requester_point,
      requester_point and requester_point.sections or nil,
      logistic_point_zero,
      logistic_point_zero and logistic_point_zero.sections or nil,
      logistic_point,
      logistic_point and logistic_point.sections or nil
    )
  end

  for _, candidate in ipairs(candidates) do
    if candidate and candidate.add_section ~= nil then
      sections_owner = candidate
      break
    end
  end

  if not sections_owner then
    sections_owner = self.is_ghost
        and (logistic_point_zero or logistic_sections_zero or logistic_sections or requester_point or logistic_point)
      or (logistic_sections_zero or logistic_sections or requester_point or logistic_point_zero or logistic_point)
  end
  if not sections_owner then
    return nil,
      logistic_sections_zero_reason
        or logistic_sections_reason
        or requester_reason
        or logistic_zero_reason
        or logistic_reason
  end

  local ingredients = item_ingredients_only(data and data.ingredients)
  local sections = collect_sections(sections_owner)
  local sections_count = #sections

  if self.is_ghost and sections_count == 1 then
    local section = sections[1]
    if
      section.filters_count == 0
      and section.group == ""
      and sections_owner.remove_section ~= nil
      and sections_owner.add_section ~= nil
    then
      sections_owner.remove_section(1)
      return sections_owner.add_section(), nil
    end
  end

  if sections_count > 0 then
    if sections_count == 1 then
      local section = sections[1]
      if section.filters_count == 0 and section.group == "" then
        return section, nil
      end
    else
      for idx = sections_count, 1, -1 do
        local section = sections[idx]
        if section.filters_count == 0 and section.group == "" then
          sections_owner.remove_section(idx)
        end
      end
      sections = collect_sections(sections_owner)
    end

    for idx, section in ipairs(sections) do
      if section.group == "" and EntityView.has_same_ingredient_names(section.filters, ingredients) then
        sections_owner.remove_section(idx)
        break
      end
    end
  end

  if sections_owner.add_section == nil then
    return nil, "missing-add-section"
  end

  return sections_owner.add_section(), nil
end

function ViewMethods:apply_storage_settings(game, player, data)
  if not data or not data.item then
    return ok_result()
  end

  local ok, err = pcall(function()
    self.entity.storage_filter = {
      name = data.name,
      quality = get_quality_string(data.quality),
    }
  end)
  if not ok then
    return fail_result("set-storage-filter-failed", err)
  end

  return ok_result()
end

function ViewMethods:apply_requester_settings(game, player, data)
  local section, reason = self:get_or_create_request_section(data)
  if not section then
    return fail_result(reason or "missing-request-section")
  end

  local ingredients = item_ingredients_only(data and data.ingredients)
  local filters = {}
  for index, ingredient in ipairs(ingredients) do
    local prototype = prototypes.item[ingredient.name]
    if prototype then
      local player_settings = settings.get_player_settings(player.index)
      local quota = get_limit(
        prototype,
        player_settings["paste-logistic-settings-continued-request-size-type"].value,
        player_settings["paste-logistic-settings-continued-request-size"].value
      )
      filters[#filters + 1] = {
        index = index,
        value = {
          type = "item",
          name = ingredient.name,
          quality = get_quality_string(data.quality),
        },
        mode = "at-least",
        min = quota,
      }
    end
  end

  if self.is_ghost then
    local ok, err = pcall(function()
      section.filters = filters
    end)
    if not ok then
      return fail_result("set-request-filters-failed", err)
    end
    return ok_result()
  end

  for index, filter in ipairs(filters) do
    local ok, err = pcall(function()
      section.set_slot(index, filter)
    end)
    if not ok then
      return fail_result("set-request-slot-failed", err)
    end
  end

  return ok_result()
end

function ViewMethods:apply_inserter_settings(game, player, data)
  if not data or not data.item then
    return ok_result()
  end

  local behavior, reason = self:get_or_create_control_behavior()
  if not behavior then
    return fail_result(reason or "missing-control-behavior")
  end

  local prototype = prototypes.item[data.name]
  if not prototype then
    return ok_result()
  end

  local player_settings = settings.get_player_settings(player.index)
  local limit = get_limit(
    prototype,
    player_settings["paste-logistic-settings-continued-output-limit-type"].value,
    player_settings["paste-logistic-settings-continued-output-limit"].value
  )
  local accumulate_setting = player_settings["paste-logistic-settings-continued-accumulate-inserter-output-limit"]
  local accumulate_output_limit = accumulate_setting == nil or accumulate_setting.value ~= false
  local existing_condition = behavior.logistic_condition

  if accumulate_output_limit and existing_condition then
    local existing_first_signal = existing_condition.first_signal
    local existing_signal = existing_first_signal and (existing_first_signal.signal or existing_first_signal)
    if existing_signal and existing_signal.name == data.name and existing_condition.comparator == "<" then
      limit = limit + (existing_condition.constant or 0)
    end
  end

  local ok, err = pcall(function()
    behavior.connect_to_logistic_network = true
    behavior.logistic_condition = {
      comparator = "<",
      first_signal = { type = "item", name = data.name, quality = get_quality_string(data.quality) },
      constant = limit,
    }
  end)
  if not ok then
    return fail_result("set-logistic-condition-failed", err)
  end

  return ok_result()
end

return EntityView
