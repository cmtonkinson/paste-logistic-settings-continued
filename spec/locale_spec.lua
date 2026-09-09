-- Guards the locale file itself. The other specs assert the *structure* of the
-- LocalisedStrings the code builds, which says nothing about whether the .cfg
-- they reference is present or well formed -- a gap that shipped a literal
-- "__plural_for_parameter_1__{1=stack|rest=stacks}__" into the game once.

local LOCALE_PATH = "locale/en/paste-logistic-settings.continued.cfg"

local function read_locale()
  local file = assert(io.open(LOCALE_PATH, "r"), "could not open " .. LOCALE_PATH)
  local content = file:read("*a")
  file:close()
  return content
end

-- Returns a "section.key" -> value map of every entry in the file.
local function parse_locale(content)
  local entries = {}
  local section = nil

  for line in content:gmatch("[^\n]+") do
    local heading = line:match("^%[(.+)%]$")
    if heading then
      section = heading
    elseif section and not line:match("^%s*$") then
      local key, value = line:match("^([^=]+)=(.*)$")
      if key then
        entries[section .. "." .. key] = value
      end
    end
  end

  return entries
end

describe("locale", function()
  local entries

  before_each(function()
    entries = parse_locale(read_locale())
  end)

  it("defines every key the source references", function()
    local referenced = {}
    for _, path in ipairs({ "src/helpers.lua", "src/lib.lua", "control.lua" }) do
      local file = io.open(path, "r")
      if file then
        local source = file:read("*a")
        file:close()
        for key in source:gmatch('"([%w%-]+%.[%w%-]+)"') do
          referenced[key] = path
        end
      end
    end

    -- Only keys that look like locale lookups, i.e. ones the file also defines
    -- a section for, are worth asserting on here.
    local checked = 0
    for key, path in pairs(referenced) do
      local section = key:match("^([^.]+)%.")
      if section == "floating-text" or section == "msg" then
        assert.is_truthy(entries[key], key .. " is referenced by " .. path .. " but missing from " .. LOCALE_PATH)
        checked = checked + 1
      end
    end

    assert.is_true(checked > 0, "expected to find at least one locale reference in the source")
  end)

  it("spells the plural marker the way Factorio parses it", function()
    for key, value in pairs(entries) do
      if value:find("plural_for_parameter", 1, true) then
        -- Documented form: __plural_for_parameter__N__{1=one|rest=many}__
        assert.is_truthy(
          value:match("__plural_for_parameter__%d+__{[^}]+}__"),
          key .. " has a malformed plural marker: " .. value
        )
      end
    end
  end)

  it("keeps rich text out of parameterised locale entries", function()
    for key, value in pairs(entries) do
      -- Factorio resolves rich text before substituting __N__ parameters, so a
      -- tag containing one silently renders as nothing.
      assert.is_nil(
        value:match("%[[%w%-]+=__%d+__%]"),
        key .. " puts a locale parameter inside a rich text tag: " .. value
      )
    end
  end)

  it("declares a name and description for every mod setting", function()
    local file = assert(io.open("settings.lua", "r"))
    local source = file:read("*a")
    file:close()

    local count = 0
    for name in source:gmatch('name = "(paste%-logistic%-settings%-continued%-[%w%-]+)"') do
      assert.is_truthy(entries["mod-setting-name." .. name], name .. " has no [mod-setting-name] entry")
      assert.is_truthy(entries["mod-setting-description." .. name], name .. " has no [mod-setting-description] entry")
      count = count + 1
    end

    assert.is_true(count > 0, "expected to find mod settings in settings.lua")
  end)
end)
