local serpent = require("serpent")
local _lib = {}

-----------------------------------------------------------------------------
function _lib.deep_equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end

  for k, v in pairs(a) do
    if not _lib.deep_equal(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end

  return true
end

-----------------------------------------------------------------------------
function _lib.assert_equal(actual, expected, message)
  if not _lib.deep_equal(actual, expected) then
    error((message or "Assertion failed") ..
      "\nExpected: " .. serpent.block(expected, {compact = true}) ..
      "\nActual:   " .. serpent.block(actual, {compact = true}), 2)
  end
end

return _lib
