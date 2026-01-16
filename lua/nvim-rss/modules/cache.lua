---Simple XML caching with diff-based change detection
---Replaces SQLite dependency with file-based storage
local M = {}

local cache_dir

-- Generate safe filename from URL
local function url_to_filename(url)
	-- Replace non-alphanumeric characters with underscores
	local safe_name = url:gsub("[^%w]", "_")
	return cache_dir .. "/" .. safe_name .. ".xml"
end

-- Initialize cache directory
function M.create(feeds_dir)
	-- Use cache directory by default, or user-specified directory
	if feeds_dir then
		cache_dir = feeds_dir .. "/.nvim-rss-cache"
	else
		cache_dir = vim.fn.stdpath("cache") .. "/nvim-rss"
	end

	vim.fn.mkdir(cache_dir, "p")
end

-- Extract only the content that matters: items/entries
-- This ignores all metadata and focuses on actual feed content
local function extract_feed_content(xml)
	local items = {}

	-- Extract RSS items (handle attributes like <item rdf:about="...">)
	for item in xml:gmatch("<item[^>]->.-</item>") do
		table.insert(items, item)
	end

	-- Extract Atom entries (handle attributes)
	for entry in xml:gmatch("<entry[^>]->.-</entry>") do
		table.insert(items, entry)
	end

	-- Concatenate all items/entries
	return table.concat(items, "")
end

-- Save fetched XML and detect if it changed
-- @param url Feed URL
-- @param xml_content Raw XML content from the feed
-- @return boolean true if XML content changed (show *), false otherwise
function M.save_feed(url, xml_content)
	local filepath = url_to_filename(url)
	local changed

	-- Ensure content is a string
	xml_content = tostring(xml_content or "")

	-- Check if XML differs from cached version
	if vim.fn.filereadable(filepath) == 1 then
		local old_lines = vim.fn.readfile(filepath)
		local old_content = table.concat(old_lines, "\n")
		-- Compare only the actual content (items/entries), ignore all metadata
		changed = (extract_feed_content(old_content) ~= extract_feed_content(xml_content))
	else
		-- New feed, always marked as changed
		changed = true
	end

	-- Write new XML to cache (split into lines for writefile)
	local lines = vim.split(xml_content, "\n")
	vim.fn.writefile(lines, filepath)

	return changed
end

-- Read cached XML for a feed
-- @param url Feed URL
-- @return string|nil Cached XML content, or nil if not found
function M.read_feed(url)
	local filepath = url_to_filename(url)

	if vim.fn.filereadable(filepath) == 0 then
		return nil
	end

	local lines = vim.fn.readfile(filepath)
	return table.concat(lines, "\n")
end

-- Check if a feed has cached data
-- @param url Feed URL
-- @return boolean true if feed is cached, false otherwise
function M.has_feed(url)
	local filepath = url_to_filename(url)
	return vim.fn.filereadable(filepath) == 1
end

-- Get last fetch time for a feed
-- @param url Feed URL
-- @return number|nil Unix timestamp of last fetch, or nil if not cached
function M.get_last_fetch_time(url)
	local filepath = url_to_filename(url)
	local mtime = vim.fn.getftime(filepath)
	return mtime ~= -1 and mtime or nil
end

-- Delete cached feed
-- @param url Feed URL
function M.clean_feed(url)
	local filepath = url_to_filename(url)
	vim.fn.delete(filepath)
end

-- Delete all cached feeds
function M.reset_cache()
	local files = vim.fn.glob(cache_dir .. "/*.xml", false, true)
	for _, file in ipairs(files) do
		vim.fn.delete(file)
	end
end

-- Get list of all cached feed URLs
-- Reconstructs URLs from filenames (best effort)
-- @return table List of cached feed URLs
function M.list_cached_feeds()
	local files = vim.fn.glob(cache_dir .. "/*.xml", false, true)
	local urls = {}

	for _, file in ipairs(files) do
		-- Extract filename without path and extension
		local filename = file:match("([^/]+)%.xml$")
		if filename then
			-- This is a best-effort reconstruction
			-- The original URL transformation is lossy
			table.insert(urls, filename)
		end
	end

	return urls
end

-- Clean old cached feeds
-- @param max_age_days Maximum age in days (default: 30)
-- @return number Number of files deleted
function M.clean_old_feeds(max_age_days)
	max_age_days = max_age_days or 30
	local max_age_seconds = max_age_days * 24 * 60 * 60
	local current_time = os.time()
	local deleted_count = 0

	local files = vim.fn.glob(cache_dir .. "/*.xml", false, true)
	for _, file in ipairs(files) do
		local mtime = vim.fn.getftime(file)
		if mtime ~= -1 then
			local age = current_time - mtime
			if age > max_age_seconds then
				vim.fn.delete(file)
				deleted_count = deleted_count + 1
			end
		end
	end

	return deleted_count
end

return M
