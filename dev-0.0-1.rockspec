rockspec_format = "3.0"
package = "dev"
source = {
  url = "https://gitlab.com/cmtonkinson/paste-logistic-settings-continued"
}
version = "0.0-1"
description = {
  summary = "Development tooling for Paste Logistic Settings (Continued)",
  license = "MIT",
}
dependencies = {
  "serpent >= 0.30-2",
}
test_dependencies = {
  "busted",
  "luacheck",
}
test = {
  type = "busted",
}
build = {
  type = "builtin",
  modules = {}
}
