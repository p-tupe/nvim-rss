local db = require("nvim-rss.modules.db")
local utils = require("nvim-rss.modules.utils")
local buffer = require("nvim-rss.modules.buffer")
local feedparser = require("nvim-rss.modules.feedparser")

local M = {}
local options = {}
local feeds_file
local feeds_db

local function open_entries_split(parsed_feed)
	local feed_info, entries = db.read_feed(parsed_feed.xmlUrl)
	buffer.create_feed_buffer()
	buffer.insert_feed_info(feed_info)
	buffer.insert_entries(entries)
end

local function update_line(parsed_feed)
	local latest, total, update_date = db.read_entry_stats(parsed_feed.xmlUrl)
	buffer.update_feed_line({
		xmlUrl = parsed_feed.xmlUrl,
		latest = latest,
		total = total,
		update_date = update_date,
		date_format = options.date_format,
	})
end

local function web_request(url, callback)
	local raw_feed = ""
	local stdin = vim.loop.new_pipe(false)
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)

	print("Fetching feed " .. url .. "... ")

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
				error("Web request error", err .. msg)
			end

			local parsed_feed = feedparser.parse(raw_feed)
			if not parsed_feed then
				error("Feed parsing error", raw_feed)
			end

			raw_feed = ""
			parsed_feed.xmlUrl = url
			db.update_feed(parsed_feed)

			callback(parsed_feed)
		end)
	)

	stdout:read_start(vim.schedule_wrap(function(err, chunk)
		if err then
			error(err, chunk)
		end
		if chunk then
			raw_feed = raw_feed .. chunk
		end
	end))

	stderr:read_start(vim.schedule_wrap(function(err, chunk)
		if err then
			error(err, chunk)
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
		error("Invalid url")
	end

	local function callback(parsed_feed)
		local latest, total, update_date = db.read_entry_stats(parsed_feed.xmlUrl)
		buffer.update_feed_line({
			xmlUrl = parsed_feed.xmlUrl,
			latest = latest,
			total = total,
			update_date = update_date,
			date_format = options.date_format,
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
	print("Importing ", opml_file, "...")

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
		error(err)
	end

	if nvim_rss == nil then
		error("Can't find file " .. feeds_file)
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
		error("Invalid url")
	end

	open_entries_split({
		xmlUrl = url,
	})
end

-- Removes all entries associated with a feed
function M.clean_feed()
	local xmlUrl = utils.get_url(vim.api.nvim_get_current_line())
	if not xmlUrl then
		error("Invalid url")
	end
	local removed = db.remove_entries(xmlUrl)
	if removed then
		buffer.update_feed_line(xmlUrl)
	end
end

-- Trunace all tables
function M.reset_db()
	db.truncate_tables()
end

function M.setup(user_options)
	options.feeds_dir = user_options.feeds_dir or "~"
	options.verbose = user_options.verbose or false
	options.date_format = user_options.date_format or "%x %r"

	feeds_file = options.feeds_dir .. "/nvim.rss"
	feeds_db = options.feeds_dir .. "/nvim.rss.db"

	db.create(feeds_db)
end

return M
