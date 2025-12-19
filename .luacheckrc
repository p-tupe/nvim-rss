-- Luacheck configuration for nvim-rss

-- Ignore global vim
globals = {
  "vim",
}

-- Don't report unused self arguments of methods
self = false

-- Increase line length limit
max_line_length = 120

-- Ignore some pedantic warnings
ignore = {
  "212", -- Unused argument
  "213", -- Unused loop variable
  "631", -- Line is too long
}

-- Exclude directories
exclude_files = {
  ".luarocks/",
  "lua_modules/",
  "lua/nvim-rss/vendor/",
}

-- Busted testing globals
files["tests/**/*_spec.lua"] = {
  std = "+busted",
  globals = {
    "async",
    "done",
  },
}
