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

## Installation

**Works on Linux, macOS, and Windows. No external dependencies required!**

```lua
-- In your package manager
{"p-tupe/nvim-rss"}
```

## Setup

```lua
require("nvim-rss").setup({
  feeds_dir = "~",  -- Directory for nvim.rss file (default: "~")
})
```

**Note:** Feed data is now cached in `~/.nvim-rss-cache/` (or `<feeds_dir>/.nvim-rss-cache/`) as raw XML files.

## Usage

**By default, no mappings/commands present. All functions are exposed so you may use them as you like!**

- Open RSS file: `open_feeds_tab()`

  Opens nvim.rss file where all the feeds are listed. By default `~/nvim.rss`, see [Setup](#Setup) to change default dir.

- Fetch and view a feed: `fetch_feed()`

  Pulls updates for the feed under cursor, caches it, and opens a vertical split to show the entries. Shows `*` indicator if the feed has changed since last fetch.

- Fetch feeds by category: `fetch_feeds_by_category()`

  Pulls update for all feeds in the category (paragraph) under cursor.

- Fetch feeds by visual range: `fetch_selected_feeds()`

  Pulls update for all feeds that are selected in visual range.

- Fetch all feeds: `fetch_all_feeds()`

  Fetches data for all feeds in nvim.rss and marks changed feeds with `*` indicator.

- View a feed: `view_feed()`

  Opens entries for feed under cursor in a vertical split. This does not fetch data from server, instead reading from cached XML files.

- Clean a feed: `clean_feed()`

  Removes cached data for a particular feed. Useful to force a fresh fetch.

- Reset everything: `reset_db()`

  Clears all cached feeds. Use with caution.

- Import OPML file: `import_opml(opml_file)`

  Parses the supplied file, extracts feed links if they exist and dumps them under "OPML Import" inside nvim.rss. They are not cached unless you explicitly fetch feeds for the links!

---

To use above functions, write the usual mapping or command syntax. Example -

```lua
vim.cmd [[

  command! OpenRssView lua require("nvim-rss").open_feeds_tab()

  command! FetchFeed lua require("nvim-rss").fetch_feed()

  command! FetchAllFeeds lua require("nvim-rss").fetch_all_feeds()

  command! FetchFeedsByCategory lua require("nvim-rss").fetch_feeds_by_category()

  command! -range FetchSelectedFeeds lua require("nvim-rss").fetch_selected_feeds()

  command! ViewFeed lua require("nvim-rss").view_feed()

  command! CleanFeed lua require("nvim-rss").clean_feed()

  command! CleanAllFeeds lua require("nvim-rss").reset_db()

  command! -nargs=1 ImportOpml lua require("nvim-rss").import_opml(<args>)

]]
```

NOTE: The command ImportOpml requires a full path and surrounding quotes.

```vim

:ImportOpml "/home/user/Documents/rss-file.opml"

```

_Checkout my feeds list [here](https://github.com/EMPAT94/dotfiles/blob/main/nvim/.config/nvim/nvim.rss)_
