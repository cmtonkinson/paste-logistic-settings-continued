data:extend({
  {
    type = "string-setting",
    name = "paste-logistic-settings-continued-output-limit-type",
    order = "a[a]",
    setting_type = "runtime-per-user",
    default_value = "stacks",
    allowed_values = {
      "stacks",
      "items",
    },
  },
  {
    type = "int-setting",
    name = "paste-logistic-settings-continued-output-limit",
    order = "a[b]",
    setting_type = "runtime-per-user",
    default_value = 1,
    minimum_value = 1,
  },
  {
    type = "string-setting",
    name = "paste-logistic-settings-continued-request-size-type",
    order = "a[c]",
    setting_type = "runtime-per-user",
    default_value = "stacks",
    allowed_values = {
      "stacks",
      "items",
    },
  },
  {
    type = "int-setting",
    name = "paste-logistic-settings-continued-request-size",
    order = "a[d]",
    setting_type = "runtime-per-user",
    default_value = 1,
    minimum_value = 1,
  },
--  {
--    type = "bool-setting",
--    name = "paste-logistic-settings-continued-enable-ghost-placement",
--    order = "b[a]",
--    setting_type = "runtime-per-user",
--    default_value = false
--  },
--  {
--    type = "string-setting",
--    name = "paste-logistic-settings-continued-ghost-direction",
--    order = "b[b]",
--    setting_type = "runtime-per-user",
--    allowed_values = { "north", "east", "south", "west" },
--    default_value = "south"
--  }
--  ,
--  {
--    type = "string-setting",
--    name = "paste-logistic-settings-continued-ghost-input-inserter",
--    order = "b[c]",
--    setting_type = "runtime-per-user",
--    allowed_values = {
--      "burner-inserter",
--      "inserter",
--      "fast-inserter",
--      "long-handed-inserter",
--      "stack-inserter",
--      "bulk-inserter",
--    },
--    default_value = "bulk-inserter",
--  },
--  {
--    type = "string-setting",
--    name = "paste-logistic-settings-continued-ghost-output-inserter",
--    order = "b[d]",
--    setting_type = "runtime-per-user",
--    allowed_values = {
--      "burner-inserter",
--      "inserter",
--      "fast-inserter",
--      "long-handed-inserter",
--      "stack-inserter",
--      "bulk-inserter",
--    },
--    default_value = "fast-inserter",
--  },
})
