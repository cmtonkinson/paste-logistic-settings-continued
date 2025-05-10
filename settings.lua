data:extend({
  {
    type = "string-setting",
    name = "paste-logistic-settings-continued-output-limit-type",
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
    setting_type = "runtime-per-user",
    default_value = 1,
    minimum_value = 1,
  },
  {
    type = "string-setting",
    name = "paste-logistic-settings-continued-request-size-type",
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
    setting_type = "runtime-per-user",
    default_value = 1,
    minimum_value = 1,
  },
})
