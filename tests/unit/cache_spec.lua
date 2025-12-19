---Unit tests for cache module
describe("cache module", function()
	local cache
	local vim_mock

	before_each(function()
		-- Load vim mock
		vim_mock = require("tests.helpers.vim_mock")
		vim_mock.reset()

		-- Load module
		cache = require("nvim-rss.modules.cache")

		-- Initialize cache
		cache.create()
	end)

	describe("save_feed", function()
		it("should save new feed and return true (changed)", function()
			local url = "https://example.com/feed.xml"
			local xml = '<?xml version="1.0"?><rss><channel><title>Test</title></channel></rss>'

			local changed = cache.save_feed(url, xml)

			assert.is_true(changed)
			assert.is_not_nil(vim_mock.get_file("/tmp/nvim_rss_test_cache/nvim-rss/https___example_com_feed_xml.xml"))
		end)

		it("should detect no change when XML is identical", function()
			local url = "https://example.com/feed.xml"
			local xml = '<?xml version="1.0"?><rss><channel><title>Test</title></channel></rss>'

			-- Save first time
			cache.save_feed(url, xml)

			-- Save again with same content
			local changed = cache.save_feed(url, xml)

			assert.is_false(changed)
		end)

		it("should detect change when XML differs", function()
			local url = "https://example.com/feed.xml"
			local xml1 = '<?xml version="1.0"?><rss><channel><title>Test</title></channel></rss>'
			local xml2 = '<?xml version="1.0"?><rss><channel><title>Updated</title></channel></rss>'

			-- Save first version
			cache.save_feed(url, xml1)

			-- Save updated version
			local changed = cache.save_feed(url, xml2)

			assert.is_true(changed)
		end)

		it("should handle multiple different feeds", function()
			local url1 = "https://example.com/feed1.xml"
			local url2 = "https://example.com/feed2.xml"
			local xml1 = "<rss>feed1</rss>"
			local xml2 = "<rss>feed2</rss>"

			cache.save_feed(url1, xml1)
			cache.save_feed(url2, xml2)

			local content1 = cache.read_feed(url1)
			local content2 = cache.read_feed(url2)

			assert.equals(xml1, content1)
			assert.equals(xml2, content2)
		end)
	end)

	describe("read_feed", function()
		it("should read cached feed", function()
			local url = "https://example.com/feed.xml"
			local xml = '<?xml version="1.0"?><rss><channel><title>Test</title></channel></rss>'

			cache.save_feed(url, xml)
			local result = cache.read_feed(url)

			assert.equals(xml, result)
		end)

		it("should return nil for non-existent feed", function()
			local url = "https://example.com/nonexistent.xml"
			local result = cache.read_feed(url)

			assert.is_nil(result)
		end)

		it("should preserve multiline XML", function()
			local url = "https://example.com/feed.xml"
			local xml = [[<?xml version="1.0"?>
<rss version="2.0">
  <channel>
    <title>Test</title>
  </channel>
</rss>]]

			cache.save_feed(url, xml)
			local result = cache.read_feed(url)

			assert.equals(xml, result)
		end)
	end)

	describe("has_feed", function()
		it("should return true for cached feed", function()
			local url = "https://example.com/feed.xml"
			local xml = "<rss>test</rss>"

			cache.save_feed(url, xml)
			local result = cache.has_feed(url)

			assert.is_true(result)
		end)

		it("should return false for non-cached feed", function()
			local url = "https://example.com/notcached.xml"
			local result = cache.has_feed(url)

			assert.is_false(result)
		end)
	end)

	describe("clean_feed", function()
		it("should delete cached feed", function()
			local url = "https://example.com/feed.xml"
			local xml = "<rss>test</rss>"

			cache.save_feed(url, xml)
			assert.is_true(cache.has_feed(url))

			cache.clean_feed(url)
			assert.is_false(cache.has_feed(url))
		end)

		it("should not error when deleting non-existent feed", function()
			local url = "https://example.com/nonexistent.xml"

			assert.has_no_errors(function()
				cache.clean_feed(url)
			end)
		end)
	end)

	describe("reset_cache", function()
		it("should delete all cached feeds", function()
			local url1 = "https://example.com/feed1.xml"
			local url2 = "https://example.com/feed2.xml"
			local xml = "<rss>test</rss>"

			cache.save_feed(url1, xml)
			cache.save_feed(url2, xml)

			assert.is_true(cache.has_feed(url1))
			assert.is_true(cache.has_feed(url2))

			cache.reset_cache()

			assert.is_false(cache.has_feed(url1))
			assert.is_false(cache.has_feed(url2))
		end)

		it("should not error when cache is empty", function()
			assert.has_no_errors(function()
				cache.reset_cache()
			end)
		end)
	end)

	describe("URL to filename conversion", function()
		it("should handle URLs with special characters", function()
			local url = "https://example.com/feed?format=rss&limit=10"
			local xml = "<rss>test</rss>"

			cache.save_feed(url, xml)
			local result = cache.read_feed(url)

			assert.equals(xml, result)
		end)

		it("should handle URLs with hashes", function()
			local url = "https://example.com/feed#section1"
			local xml = "<rss>test</rss>"

			cache.save_feed(url, xml)
			local result = cache.read_feed(url)

			assert.equals(xml, result)
		end)

		it("should handle URLs with ports", function()
			local url = "https://example.com:8080/feed.xml"
			local xml = "<rss>test</rss>"

			cache.save_feed(url, xml)
			local result = cache.read_feed(url)

			assert.equals(xml, result)
		end)
	end)
end)
