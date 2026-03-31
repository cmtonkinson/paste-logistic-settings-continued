local function require_plsc_module(module_name)
  if _G.script == nil then
    return require("src." .. module_name)
  end
  return require("__paste-logistic-settings-continued__.src." .. module_name)
end

local lib = require_plsc_module("lib")

local function ingredient_map(ingredients)
  local mapped = {}
  for _, ingredient in ipairs(ingredients) do
    mapped[ingredient.name] = ingredient
  end
  return mapped
end

local function create_fluid_recipe_cell(surface)
  local plant = surface.create_entity({
    name = "chemical-plant",
    position = { x = 10.5, y = 0.5 },
    force = "player",
  })
  plant.set_recipe("sulfuric-acid")

  local storage = surface.create_entity({
    name = "storage-chest",
    position = { x = 13.5, y = 0.5 },
    force = "player",
  })

  return {
    plant = plant,
    storage = storage,
  }
end

local function fluid_recipe_cell(surface)
  return {
    plant = surface.find_entity("chemical-plant", { x = 10.5, y = 0.5 }),
    storage = surface.find_entity("storage-chest", { x = 13.5, y = 0.5 }),
  }
end

return {
  setup = {
    test = function(f, context)
      local cell = create_fluid_recipe_cell(context.game.surfaces[1])

      f:expect(cell.plant.valid, true)
      f:expect(cell.plant.get_recipe().name, "sulfuric-acid")
      f:expect(cell.storage.valid, true)
    end,
  },

  copy_settings_ignores_fluid_outputs = {
    from = "setup",
    test = function(f, context)
      local cell = fluid_recipe_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.plant)
      local ingredients = ingredient_map(data.ingredients)

      f:expect(data.item == nil, true)
      f:expect(data.name == nil, true)
      f:expect(ingredients["iron-plate"].amount, 1)
      f:expect(ingredients["sulfur"].amount, 5)
      f:expect(ingredients["water"] == nil, true)
    end,
  },

  paste_to_storage_skips_fluid_outputs = {
    from = "setup",
    test = function(f, context)
      local cell = fluid_recipe_cell(context.game.surfaces[1])
      local data = lib.copy_settings(context.game, { index = 1 }, cell.plant)

      lib.paste_settings(context.game, { index = 1 }, cell.storage, data)

      f:expect(cell.storage.storage_filter == nil, true)
    end,
  },
}
