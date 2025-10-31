<br />
<div style="width:100%" align="center"> <img src="./logo.svg" alt="nvim.rss Image"> </div>
<h1 align="center">nvim.rss</h1>
<p align="center">A simple rss reader for neovim.</p>
<br />

## Intro

nvim-rss aims to be similar to the excellent [vnews](https://github.com/danchoi/vnews) and, if you squint hard enough while looking sideways, then perhaps [elfeed](https://github.com/skeeto/elfeed).

Ideally, if you have a bunch of feeds and simply wish to view the latest entries in neovim instead of browsers or dedicated apps, then this plugin should help you out.

## Demo (v0.2)

https://user-images.githubusercontent.com/9110181/141071168-ce671cd5-3f9b-4b68-b0d0-bb76abb7a8c5.mp4

## Pre-requisites

1. [neovim](https://neovim.io/)
2. [curl](https://curl.se/) | Usually pre-installed on most systems
3. [sqlite3](https://sqlite.org/index.html) | Usually pre-installed on some systems
4. [tami5/sqlite.lua](https://github.com/tami5/sqlite.lua) | Either as plugin or luarock
5. [tomasguisasola/luaexpat](https://lunarmodules.github.io/luaexpat/) | From luarocks

## Installation

**Tested on linux, may work on macos. Probably won't work on windows.**

If using `packer.nvim` (recommended) then

```lua

use {
  "empat94/nvim-rss",
  requires = { "tami5/sqlite.lua" },
  rocks = { "luaexpat" },
  config = function() require("nvim-rss").setup({...}) end
}

```

Else if using `vim-plug` then

```vim

Plug `tami5/sqlite.lua`

Plug 'empat94/nvim-rss'

```

```sh

luarocks install luaexpat

```

```vim

lua << EOF
  require("nvim-rss").setup({...})
EOF

```

Else your usual way of installing plugins and luarocks

## Setup

```lua

require("nvim-rss").setup({   -- set nothing to use defaults

  feeds_dir = "/home/user",   -- ensure has write permissions (use full path to dir)

  date_format = "%x %r",      -- man date for more formats; updates when feed is refreshed

})

```

If using init.vim, wrap the code inside `lua << EOF ... EOF`

## Usage

**By default, no mappings/commands present. All functions are exposed so you may use them as you like!**

- Open RSS file: `open_feeds_tab()`

  Opens nvim.rss file where all the feeds are listed. By default `~/nvim.rss`, see [Setup](#Setup) to change default dir.

- Fetch and view a feed: `fetch_feed()`

  Pulls updates for the feed under cursor and opens a vertical split to show the entries.

- Fetch feeds by category: `fetch_feeds_by_category()`

  Pulls update for all feeds in the category (paragraph) under cursor.

- Fetch feeds by visual range: `fetch_selected_feeds()`

  Pulls update for all feeds that are selected in visual range.

- Fetch all feeds: `fetch_all_feeds()`

  Fetches data for all feeds in nvim.rss and updates the corresponding counts if nvim.rss is loaded in a buffer.

- View a feed: `view_feed()`

  Opens entries for feed under cursor in a vertical split. This does not fetch data from server, instead pulling stored content from database.

- Clean a feed: `clean_feed()`

  Removes all entires associated with a particular feed. Useful if you are encountering SQL errors.

- Reset everything: `reset_db()`

  Truncates all tables. Use with caution. Might be useful when there is an unforeseen db-related error occurs. If this doesn't work, delete `nvim.rss.db` and restart neovim instance.

- Import OPML file: `import_opml(opml_file)`

  Parses the supplied file, extracts feed links if they exist and dumps them under "OPML Import" inside nvim.rss. They are not added to database unless you explicitly fetch feeds for the links!

---

To use above functions, write the usual mapping or command syntax. Example -

```lua

vim.cmd [[ -- no need for vim.cmd if vim file

  command! OpenRssView lua require("nvim-rss").open_feeds_tab()

  command! FetchFeed lua require("nvim-rss").fetch_feed()

  command! FetchAllFeeds lua require("nvim-rss").fetch_all_feeds()

  command! FetchFeedsByCategory lua require("nvim-rss").fetch_feeds_by_category()

  command! -range FetchSelectedFeeds lua require("nvim-rss").fetch_selected_feeds()

  command! ViewFeed lua require("nvim-rss").view_feed()

  command! CleanFeed lua require("nvim-rss").clean_feed()

  command! ResetDB lua require("nvim-rss").reset_db()

  command! -nargs=1 ImportOpml lua require("nvim-rss").import_opml(<args>)

]]

```

NOTE: The command ImportOpml requires a full path and surrounding quotes.

```vim

:ImportOpml "/home/user/Documents/rss-file.opml"

```

_Checkout my feeds list [here](https://github.com/EMPAT94/dotfiles/blob/main/nvim/.config/nvim/nvim.rss)_

## Todos

- [ ] Star favourite entries
- [ ] OPML export
- [ ] Console browser (lynx, w3m) integration
- [ ] Most viewed, most recent, favorite feeds view
- [ ] Highlight entries (new, read, starred)
- [ ] Windows support

## Personal Goals

1. Learn lua (I plan to make a few more plugins!)
2. Learn how to make a neovim plugin
3. Contribute to the awesome neovim ecosystem
4. Share some open-source love <3
