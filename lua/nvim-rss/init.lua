local cache = require("nvim-rss.modules.cache")
local utils = require("nvim-rss.modules.utils")
local buffer = require("nvim-rss.modules.buffer")
local feedparser = require("nvim-rss.modules.feedparser")

local M = {}
local options = {}
local feeds_file
local feed_changed = {} -- Track which feeds have changed

-- Helper function for notifications with verbosity control
local function notify(msg, level)
	level = level or vim.log.levels.INFO

	if level >= vim.log.levels.WARN then
		vim.notify(msg, level)
	elseif options.log_level == "debug" then
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

local function open_entries_split(parsed_feed)
	buffer.create_feed_buffer()
	buffer.insert_feed_info(parsed_feed.feed)
	buffer.insert_entries(parsed_feed.entries)
end

local function update_line(parsed_feed)
	-- Show * if feed has changed
	local changed = feed_changed[parsed_feed.xmlUrl] or false
	buffer.update_feed_line({
		xmlUrl = parsed_feed.xmlUrl,
		changed = changed,
		show_asterisk = options.show_asterisk or true,
	})
end

local function web_request(url, callback)
	local raw_feed = ""
	local stdin = vim.loop.new_pipe(false)
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)

	notify("Fetching feed " .. url .. "...", vim.log.levels.INFO)

	handle = vim.loop.spawn(
		"curl",
		{
			args = { "-L", "--user-agent", "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/90.0", url },
			stdio = { stdin, stdout, stderr },
		},
		vim.schedule_wrap(function(err, msg)
			stdin:shutdown()
			stdout:read_stop()
			stderr:read_stop()

			stdin:close()
			stdout:close()
			stderr:close()

			if not handle:is_closing() then
				handle:close()
			end

			if err ~= 0 then
				local error_msg = "Failed to fetch " .. url .. ": " .. get_curl_error_message(err)
				notify(error_msg, vim.log.levels.ERROR)
				return
			end

			-- Save raw XML to cache and detect changes
			local changed = cache.save_feed(url, raw_feed)
			feed_changed[url] = changed

			-- Parse the feed for display
			local parsed_feed, parse_err = feedparser.parse(raw_feed)
			if not parsed_feed then
				notify("Failed to parse feed from " .. url .. ": " .. tostring(parse_err), vim.log.levels.ERROR)
				return
			end

			raw_feed = ""
			parsed_feed.xmlUrl = url

			callback(parsed_feed)
		end)
	)

	stdout:read_start(vim.schedule_wrap(function(err, chunk)
		if err then
			notify("Error reading feed data: " .. tostring(err), vim.log.levels.ERROR)
			return
		end
		if chunk then
			raw_feed = raw_feed .. chunk
		end
	end))

	stderr:read_start(vim.schedule_wrap(function(err, chunk)
		if err then
			notify("Curl error: " .. tostring(err), vim.log.levels.ERROR)
		end
	end))
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
			show_asterisk = options.show_asterisk or true,
		})
		open_entries_split(parsed_feed)
	end

	web_request(xmlUrl, callback)
end

function M.fetch_all_feeds()
	for line in io.lines(feeds_file) do
		fetch_and_update(line)
	end
end

function M.fetch_feeds_by_category()
	local eval = vim.api.nvim_eval
	local exec = vim.api.nvim_exec

	local category = eval(exec(
		[[
    execute ':silent normal vip'
    echo getline("'<", "'>")
  ]],
		true
	))

	for i = 1, #category do
		fetch_and_update(category[i])
	end
end

function M.fetch_selected_feeds()
	local eval = vim.api.nvim_eval
	local exec = vim.api.nvim_exec

	local selected = eval(exec([[echo getline("'<", "'>")]], true))

	for i = 1, #selected do
		fetch_and_update(selected[i])
	end
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
	open_entries_split(parsed_feed)
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
function M.reset_db()
	cache.reset_cache()
	feed_changed = {}
	notify("Cleared all cached feeds", vim.log.levels.INFO)
end

function M.setup(user_options)
	user_options = user_options or {}
	options.feeds_dir = user_options.feeds_dir or "~"
	options.verbose = user_options.verbose or false
	options.show_asterisk = user_options.show_asterisk ~= false -- Default: true
	options.log_level = user_options.log_level or "error" -- "error" or "debug"

	feeds_file = vim.fn.expand(options.feeds_dir) .. "/nvim.rss"

	-- Initialize cache
	cache.create(vim.fn.expand(options.feeds_dir))
end

return M
