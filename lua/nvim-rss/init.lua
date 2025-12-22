local cache = require("nvim-rss.modules.cache")
local utils = require("nvim-rss.modules.utils")
local buffer = require("nvim-rss.modules.buffer")
local feedparser = require("nvim-rss.modules.feedparser")

local M = {}
local options = {}
local feeds_file
local feed_changed = {} -- Track which feeds have changed

-- Concurrent fetch queue management
local active_fetches = 0
local fetch_queue = {}
local max_concurrent_fetches = 5

-- Helper function for notifications with verbosity control
local function notify(msg, level)
	level = level or vim.log.levels.INFO

	if level >= vim.log.levels.WARN then
		vim.notify(msg, level)
	elseif options.log_level == "debug" then
		vim.notify(msg, level)
	elseif options.log_level == "info" and level >= vim.log.levels.INFO then
		vim.notify(msg, level)
	end
end

-- Map curl exit codes to user-friendly messages
local function get_curl_error_message(exit_code)
	local curl_errors = {
		[1] = "Unsupported protocol",
		[3] = "Malformed URL",
		[5] = "Couldn't resolve proxy",
		[6] = "Couldn't resolve host",
		[7] = "Failed to connect",
		[28] = "Operation timeout",
		[35] = "SSL connection error",
		[52] = "Empty response from server",
		[56] = "Failure receiving network data",
	}
	return curl_errors[exit_code] or ("Unknown error (code " .. exit_code .. ")")
end

local function open_entries_split(parsed_feed, metadata)
	buffer.create_feed_buffer()
	buffer.insert_feed_info(parsed_feed.feed, metadata)
	buffer.insert_entries(parsed_feed.entries)
end

local function update_line(parsed_feed)
	-- Show * if feed has changed
	local changed = feed_changed[parsed_feed.xmlUrl] or false
	buffer.update_feed_line({
		xmlUrl = parsed_feed.xmlUrl,
		changed = changed,
		star_updated = options.star_updated or true,
	})
end

-- Process next item in fetch queue
local function process_queue()
	if active_fetches >= max_concurrent_fetches or #fetch_queue == 0 then
		return
	end

	local next_fetch = table.remove(fetch_queue, 1)
	if next_fetch then
		next_fetch()
	end
end

-- Validate URL format
local function is_valid_url(url)
	if not url or url == "" then
		return false
	end
	-- Check for http:// or https:// followed by valid domain
	return url:match("^https?://[%w%-%.]+") ~= nil
end

local function web_request(url, callback)
	-- Validate URL before making request
	if not is_valid_url(url) then
		notify("Invalid URL format: " .. tostring(url), vim.log.levels.ERROR)
		return
	end

	-- Queue management: if at capacity, queue the request
	if active_fetches >= max_concurrent_fetches then
		table.insert(fetch_queue, function()
			web_request(url, callback)
		end)
		return
	end

	-- Increment active fetches
	active_fetches = active_fetches + 1

	notify("Fetching feed " .. url .. "...", vim.log.levels.DEBUG)

	vim.system({
		"curl",
		"-s",
		"-L",
		"--max-time",
		tostring(options.fetch_timeout),
		"--user-agent",
		"Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/90.0",
		url,
	}, { text = true }, function(obj)
		vim.schedule(function()
			-- Decrement active fetches and process queue
			active_fetches = active_fetches - 1
			vim.schedule(process_queue)

			if obj.code ~= 0 then
				local error_msg = "Failed to fetch " .. url .. ": " .. get_curl_error_message(obj.code)
				notify(error_msg, vim.log.levels.ERROR)
				return
			end

			local raw_feed = obj.stdout or ""

			-- Save raw XML to cache and detect changes
			local changed = cache.save_feed(url, raw_feed)
			feed_changed[url] = changed

			-- Parse the feed for display
			local parsed_feed, parse_err = feedparser.parse(raw_feed)
			if not parsed_feed then
				notify("Failed to parse feed from " .. url .. ": " .. tostring(parse_err), vim.log.levels.ERROR)
				return
			end

			parsed_feed.xmlUrl = url
			callback(parsed_feed)
		end)
	end)
end

local function fetch_and_update(line)
	local xmlUrl = utils.get_url(line)
	if xmlUrl then
		web_request(xmlUrl, update_line)
	end
end

function M.open_feeds_tab()
	vim.cmd("tabnew " .. feeds_file)
end

function M.fetch_feed()
	local xmlUrl = utils.get_url(vim.api.nvim_get_current_line())

	if not xmlUrl then
		notify("Invalid URL", vim.log.levels.ERROR)
		return
	end

	local function callback(parsed_feed)
		-- Show * if feed changed
		local changed = feed_changed[parsed_feed.xmlUrl] or false
		buffer.update_feed_line({
			xmlUrl = parsed_feed.xmlUrl,
			changed = changed,
			star_updated = options.star_updated or true,
		})

		-- Gather metadata
		local metadata = {
			item_count = #parsed_feed.entries,
			last_checked = utils.format_relative_time(cache.get_last_fetch_time(parsed_feed.xmlUrl)),
		}

		open_entries_split(parsed_feed, metadata)
	end

	web_request(xmlUrl, callback)
end

function M.fetch_all_feeds()
	notify("Fetching all feeds...", vim.log.levels.INFO)
	for line in io.lines(feeds_file) do
		fetch_and_update(line)
	end
	notify("All feeds fetched!", vim.log.levels.INFO)
end

function M.fetch_feeds_by_category()
	notify("Fetching feeds in category...", vim.log.levels.INFO)

	-- Select current paragraph
	vim.cmd("silent normal! vip")

	-- Get visual selection range
	local start_line = vim.fn.line("'<") - 1
	local end_line = vim.fn.line("'>")

	-- Get lines in the paragraph
	local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)

	for _, line in ipairs(lines) do
		fetch_and_update(line)
	end

	notify("Category feeds fetched!", vim.log.levels.INFO)
end

function M.fetch_selected_feeds()
	notify("Fetching selected feeds...", vim.log.levels.INFO)

	-- Get visual selection range
	local start_line = vim.fn.line("'<") - 1
	local end_line = vim.fn.line("'>")

	-- Get selected lines
	local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)

	for _, line in ipairs(lines) do
		fetch_and_update(line)
	end

	notify("Selected feeds fetched!", vim.log.levels.INFO)
end

function M.import_opml(opml_file)
	notify("Importing " .. opml_file .. "...", vim.log.levels.INFO)

	local feeds = {}
	for line in io.lines(opml_file) do
		local type = line:match('type="(.-)"')
		local link = line:match('xmlUrl="(.-)"')
		local title = line:match('title="(.-)"')
		if not title then
			title = line:match('text="(.-)"')
		end

		if type and title and link then
			feeds[#feeds + 1] = link .. " " .. title
		end
	end

	local nvim_rss, err = io.open(feeds_file, "a+")

	if err then
		notify(tostring(err), vim.log.levels.ERROR)
		return
	end

	if nvim_rss == nil then
		notify("Can't find file " .. feeds_file, vim.log.levels.ERROR)
		return
	end

	nvim_rss:write("\n\nOPML IMPORT\n-----\n")
	nvim_rss:write(table.concat(feeds, "\n"))
	nvim_rss:flush()
	nvim_rss:close()

	notify("OPML import completed!", vim.log.levels.INFO)
end

function M.export_opml(opml_file)
	notify("Exporting to " .. opml_file .. "...", vim.log.levels.INFO)

	local feeds = {}
	for line in io.lines(feeds_file) do
		local url = utils.get_url(line)
		if url then
			local title = line:match(url .. "%s+(.+)") or url
			table.insert(feeds, {url = url, title = title})
		end
	end

	local outfile, err = io.open(opml_file, "w")
	if err then
		notify(tostring(err), vim.log.levels.ERROR)
		return
	end

	if outfile == nil then
		notify("Can't create file " .. opml_file, vim.log.levels.ERROR)
		return
	end

	outfile:write('<?xml version="1.0" encoding="UTF-8"?>\n')
	outfile:write('<opml version="2.0">\n')
	outfile:write('  <head>\n')
	outfile:write('    <title>RSS Feeds</title>\n')
	outfile:write('  </head>\n')
	outfile:write('  <body>\n')

	for _, feed in ipairs(feeds) do
		local escaped_title = feed.title:gsub('"', '&quot;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('&', '&amp;')
		outfile:write(string.format('    <outline type="rss" text="%s" title="%s" xmlUrl="%s"/>\n',
			escaped_title, escaped_title, feed.url))
	end

	outfile:write('  </body>\n')
	outfile:write('</opml>\n')
	outfile:flush()
	outfile:close()

	notify("OPML export completed!", vim.log.levels.INFO)
end

function M.view_feed()
	local url = utils.get_url(vim.api.nvim_get_current_line())

	if not url then
		notify("Invalid URL", vim.log.levels.ERROR)
		return
	end

	-- Read cached XML
	local cached_xml = cache.read_feed(url)
	if not cached_xml then
		notify("No cached data for this feed. Fetch it first with fetch_feed()", vim.log.levels.WARN)
		return
	end

	-- Parse the cached XML
	local parsed_feed = feedparser.parse(cached_xml)
	if not parsed_feed then
		notify("Failed to parse cached feed", vim.log.levels.ERROR)
		return
	end

	parsed_feed.xmlUrl = url

	-- Mark feed as viewed (remove star)
	feed_changed[url] = false
	buffer.update_feed_line({
		xmlUrl = url,
		changed = false,
		star_updated = options.star_updated or true,
	})

	-- Gather metadata
	local metadata = {
		item_count = #parsed_feed.entries,
		last_checked = utils.format_relative_time(cache.get_last_fetch_time(url)),
	}

	open_entries_split(parsed_feed, metadata)
end

-- Removes cached data for a feed
function M.clean_feed()
	local xmlUrl = utils.get_url(vim.api.nvim_get_current_line())
	if not xmlUrl then
		notify("Invalid URL", vim.log.levels.ERROR)
		return
	end
	cache.clean_feed(xmlUrl)
	feed_changed[xmlUrl] = nil
	notify("Cleared cache for feed: " .. xmlUrl, vim.log.levels.INFO)
end

-- Clear all cached feeds
function M.clean_all_feeds()
	cache.reset_cache()
	feed_changed = {}
	notify("Cleared all cached feeds", vim.log.levels.INFO)
end

function M.setup(user_options)
	user_options = user_options or {}
	options.feeds_dir = user_options.feeds_dir or "~"
	options.verbose = user_options.verbose or false
	options.star_updated = user_options.star_updated ~= false
	options.log_level = user_options.log_level or "info"
	options.fetch_timeout = user_options.fetch_timeout or 30

	feeds_file = vim.fn.expand(options.feeds_dir) .. "/nvim.rss"

	-- Initialize cache
	cache.create(vim.fn.expand(options.feeds_dir))

	-- Automatic cleanup of old cached feeds (30 days)
	cache.clean_old_feeds(30)
end

return M
