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

-- Save fetched XML and detect if it changed
-- @param url Feed URL
-- @param xml_content Raw XML content from the feed
-- @return boolean true if XML content changed (show *), false otherwise
function M.save_feed(url, xml_content)
	local filepath = url_to_filename(url)
	local changed = false

	-- Check if XML differs from cached version
	if vim.fn.filereadable(filepath) == 1 then
		local old_content = table.concat(vim.fn.readfile(filepath), "\n")
		changed = (old_content ~= xml_content)
	else
		-- New feed, always marked as changed
		changed = true
	end

	-- Write new XML to cache
	vim.fn.writefile(vim.split(xml_content, "\n"), filepath)

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

	return table.concat(vim.fn.readfile(filepath), "\n")
end

-- Check if a feed has cached data
-- @param url Feed URL
-- @return boolean true if feed is cached, false otherwise
function M.has_feed(url)
	local filepath = url_to_filename(url)
	return vim.fn.filereadable(filepath) == 1
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

return M
