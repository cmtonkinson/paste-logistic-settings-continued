local _lib = require("test._lib")
local helpers = require("scripts.helpers")

-----------------------------------------------------------------------------
local tbl = {
  {name="a",val=1},
  {name="b",val=2},
  {name="c",val=3},
}
_lib.assert_equal(helpers.pluck(tbl, "name"), {"a", "b", "c"}, "pluck failed")
_lib.assert_equal(helpers.pluck(tbl, "val"), {1, 2, 3}, "pluck failed")

-----------------------------------------------------------------------------
print("All tests passed!")
