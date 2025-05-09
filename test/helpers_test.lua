local _lib = require("test._lib")
local helpers = require("scripts.helpers")

-----------------------------------------------------------------------------
local tbl1 = {
  {name="a",val=1},
  {name="b",val=2},
  {name="c",val=3},
}
_lib.assert_equal(helpers.pluck(tbl1, "name"), {"a", "b", "c"}, "pluck failed")
_lib.assert_equal(helpers.pluck(tbl1, "val"), {1, 2, 3}, "pluck failed")

-----------------------------------------------------------------------------
local tbl2 = {
  {name="a",val=1},
  {name="b",val=2},
  {name="c",val=3},
}
_lib.assert_equal(helpers.pluck_set(tbl2, "name"), {["a"]=true, ["b"]=true, ["c"]=true}, "pluck failed")
_lib.assert_equal(helpers.pluck_set(tbl2, "val"), {[1]=true, [2]=true, [3]=true}, "pluck failed")

-----------------------------------------------------------------------------
local entity = {
  valid = true,
  position = {x=1, y=2},
}
_lib.assert_equal(helpers.get_area(entity, 3), {{-2, -1}, {4, 5}}, "get_area failed")
_lib.assert_equal(helpers.get_area(nil, 3), nil, "get_area failed")
_lib.assert_equal(helpers.get_area(entity, -99), {{1, 2}, {1, 2}}, "get_area failed")

-----------------------------------------------------------------------------
print("All tests passed!")
