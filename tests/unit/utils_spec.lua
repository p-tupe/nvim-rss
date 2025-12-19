---Unit tests for utils module
describe("utils module", function()
	local utils
	local vim_mock

	before_each(function()
		-- Load vim mock
		vim_mock = require("tests.helpers.vim_mock")
		vim_mock.reset()

		-- Load module
		utils = require("nvim-rss.modules.utils")
	end)

	describe("sanitize", function()
		it("should remove HTML tags from text", function()
			local input = "<p>Hello <strong>world</strong>!</p>"
			local result = utils.sanitize(input)

			assert.is_table(result)
			assert.equals("Hello world!", result[1])
		end)

		it("should handle text without HTML tags", function()
			local input = "Plain text without tags"
			local result = utils.sanitize(input)

			assert.is_table(result)
			assert.equals("Plain text without tags", result[1])
		end)

		it("should split multiline text", function()
			local input = "Line 1\nLine 2\nLine 3"
			local result = utils.sanitize(input)

			assert.is_table(result)
			assert.equals(3, #result)
			assert.equals("Line 1", result[1])
			assert.equals("Line 2", result[2])
			assert.equals("Line 3", result[3])
		end)

		it("should remove nested HTML tags", function()
			local input = "<div><p>Nested <span>tags</span> here</p></div>"
			local result = utils.sanitize(input)

			assert.is_table(result)
			assert.equals("Nested tags here", result[1])
		end)

		it("should handle nil input", function()
			local result = utils.sanitize(nil)
			assert.is_nil(result)
		end)

		it("should handle empty string", function()
			local result = utils.sanitize("")
			assert.is_table(result)
			assert.equals(0, #result)
		end)
	end)

	describe("get_url", function()
		it("should extract http URL from string", function()
			local input = "Check out http://example.com for more info"
			local result = utils.get_url(input)

			assert.equals("http://example.com", result)
		end)

		it("should extract https URL from string", function()
			local input = "Visit https://example.com/feed.xml"
			local result = utils.get_url(input)

			assert.equals("https://example.com/feed.xml", result)
		end)

		it("should extract URL with query parameters", function()
			local input = "Feed: https://example.com/rss?format=xml&limit=10"
			local result = utils.get_url(input)

			assert.equals("https://example.com/rss?format=xml&limit=10", result)
		end)

		it("should extract URL from beginning of string", function()
			local input = "https://example.com/feed Some Title"
			local result = utils.get_url(input)

			assert.equals("https://example.com/feed", result)
		end)

		it("should return nil for string without URL", function()
			local input = "No URL here"
			local result = utils.get_url(input)

			assert.is_nil(result)
		end)

		it("should handle URL with path and fragment", function()
			local input = "https://example.com/blog/posts#section1"
			local result = utils.get_url(input)

			assert.equals("https://example.com/blog/posts#section1", result)
		end)

		it("should extract first URL when multiple present", function()
			local input = "http://first.com and http://second.com"
			local result = utils.get_url(input)

			assert.equals("http://first.com", result)
		end)
	end)
end)
