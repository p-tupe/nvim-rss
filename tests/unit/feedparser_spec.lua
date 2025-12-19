---Unit tests for feedparser module
describe("feedparser module", function()
	local feedparser
	local vim_mock

	before_each(function()
		-- Load vim mock
		vim_mock = require("tests.helpers.vim_mock")
		vim_mock.reset()

		-- Load module
		feedparser = require("nvim-rss.modules.feedparser")
	end)

	describe("parse RSS 2.0", function()
		local sample_rss20

		before_each(function()
			-- Read sample RSS 2.0 fixture
			local file = io.open("tests/fixtures/sample_rss20.xml", "r")
			sample_rss20 = file:read("*all")
			file:close()
		end)

		it("should parse valid RSS 2.0 feed", function()
			local result = feedparser.parse(sample_rss20)

			assert.is_not_nil(result)
			assert.equals("rss", result.format)
			assert.is_not_nil(result.feed)
			assert.equals("Sample RSS 2.0 Feed", result.feed.title)
			assert.equals("http://example.com", result.feed.link)
		end)

		it("should parse RSS 2.0 entries", function()
			local result = feedparser.parse(sample_rss20)

			assert.is_table(result.entries)
			assert.equals(3, #result.entries)

			local first = result.entries[1]
			assert.equals("First Article", first.title)
			assert.equals("http://example.com/article1", first.link)
			assert.is_not_nil(first.summary)
		end)

		it("should parse RSS 2.0 entry dates", function()
			local result = feedparser.parse(sample_rss20)

			local first = result.entries[1]
			assert.is_not_nil(first.updated_parsed)
			assert.is_number(first.updated_parsed)
		end)

		it("should parse RSS 2.0 feed subtitle", function()
			local result = feedparser.parse(sample_rss20)

			assert.is_not_nil(result.feed.subtitle)
			assert.equals("A sample RSS 2.0 feed for testing", result.feed.subtitle)
		end)
	end)

	describe("parse Atom 1.0", function()
		local sample_atom10

		before_each(function()
			-- Read sample Atom 1.0 fixture
			local file = io.open("tests/fixtures/sample_atom10.xml", "r")
			sample_atom10 = file:read("*all")
			file:close()
		end)

		it("should parse valid Atom 1.0 feed", function()
			local result = feedparser.parse(sample_atom10)

			assert.is_not_nil(result)
			assert.equals("atom", result.format)
			assert.is_not_nil(result.feed)
			assert.equals("Sample Atom 1.0 Feed", result.feed.title)
		end)

		it("should parse Atom 1.0 entries", function()
			local result = feedparser.parse(sample_atom10)

			assert.is_table(result.entries)
			assert.equals(2, #result.entries)

			local first = result.entries[1]
			assert.equals("Atom Entry One", first.title)
			assert.equals("http://example.com/atom1", first.link)
		end)

		it("should parse Atom 1.0 entry summaries", function()
			local result = feedparser.parse(sample_atom10)

			local first = result.entries[1]
			assert.is_not_nil(first.summary)
			assert.equals("Summary of the first atom entry", first.summary)
		end)

		it("should parse Atom 1.0 entry dates", function()
			local result = feedparser.parse(sample_atom10)

			local first = result.entries[1]
			assert.is_not_nil(first.updated_parsed)
			assert.is_number(first.updated_parsed)
		end)

		it("should parse Atom 1.0 feed subtitle", function()
			local result = feedparser.parse(sample_atom10)

			assert.is_not_nil(result.feed.subtitle)
			assert.equals("A sample Atom 1.0 feed for testing", result.feed.subtitle)
		end)
	end)

	describe("error handling", function()
		it("should handle malformed XML gracefully", function()
			local malformed
			local file = io.open("tests/fixtures/malformed.xml", "r")
			malformed = file:read("*all")
			file:close()

			local result, err = feedparser.parse(malformed)

			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.is_string(err)
		end)

		it("should handle invalid XML string", function()
			local result, err = feedparser.parse("<invalid>")

			assert.is_nil(result)
			assert.is_not_nil(err)
		end)

		it("should handle empty string", function()
			local result, err = feedparser.parse("")

			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("empty response", err)
		end)

		it("should handle whitespace-only response", function()
			local result, err = feedparser.parse("   \n\n\t  \n  ")

			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("empty response", err)
		end)

		it("should handle non-feed XML", function()
			local non_feed = '<?xml version="1.0"?><root><item>test</item></root>'
			local result, err = feedparser.parse(non_feed)

			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("unknown feed format", err)
		end)

		it("should handle UTF-8 BOM", function()
			local xml_with_bom = '\xEF\xBB\xBF<?xml version="1.0"?><rss version="2.0"><channel><title>Test</title><link>http://example.com</link></channel></rss>'
			local result, err = feedparser.parse(xml_with_bom)

			assert.is_not_nil(result, "Should parse XML with BOM: " .. tostring(err))
			assert.equals("Test", result.feed.title)
		end)

		it("should handle leading/trailing whitespace", function()
			local xml_with_whitespace = '\n\n  <?xml version="1.0"?><rss version="2.0"><channel><title>Test</title><link>http://example.com</link></channel></rss>  \n\n'
			local result, err = feedparser.parse(xml_with_whitespace)

			assert.is_not_nil(result, "Should parse XML with whitespace: " .. tostring(err))
			assert.equals("Test", result.feed.title)
		end)

		it("should detect HTML response", function()
			local html_response = '<!DOCTYPE html>\n<html><head><title>Error</title></head><body>404 Not Found</body></html>'
			local result, err = feedparser.parse(html_response)

			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("received HTML instead of RSS/Atom feed", err)
		end)

		it("should detect HTML response with different case", function()
			local html_response = '<HTML><HEAD><TITLE>Error</TITLE></HEAD><BODY>Error</BODY></HTML>'
			local result, err = feedparser.parse(html_response)

			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("received HTML instead of RSS/Atom feed", err)
		end)
	end)

	describe("feed detection", function()
		it("should detect RSS version", function()
			local rss_xml = [[<?xml version="1.0"?>
<rss version="2.0">
	<channel>
		<title>Test</title>
		<link>http://example.com</link>
	</channel>
</rss>]]

			local result = feedparser.parse(rss_xml)
			assert.is_not_nil(result)
			assert.equals("rss20", result.version)
		end)

		it("should detect Atom version", function()
			local atom_xml = [[<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom">
	<title>Test Feed</title>
	<link href="http://example.com/"/>
	<updated>2024-01-01T00:00:00Z</updated>
	<id>http://example.com</id>
</feed>]]

			local result = feedparser.parse(atom_xml)
			assert.is_not_nil(result)
			assert.equals("atom10", result.version)
		end)
	end)

	describe("SLAXML-specific parsing", function()
		it("should handle CDATA sections", function()
			local cdata_xml = [[<?xml version="1.0"?>
<rss version="2.0">
	<channel>
		<title>Test</title>
		<link>http://example.com</link>
		<item>
			<title>Article with CDATA</title>
			<description>]] .. "<![CDATA[This is <b>bold</b> text]]>" .. [[</description>
			<link>http://example.com/1</link>
		</item>
	</channel>
</rss>]]

			local result = feedparser.parse(cdata_xml)
			assert.is_not_nil(result)
			assert.equals(1, #result.entries)
			assert.equals("This is <b>bold</b> text", result.entries[1].summary)
		end)

		it("should ignore comments", function()
			local comment_xml = [[<?xml version="1.0"?>
<rss version="2.0">
	<!-- This is a comment -->
	<channel>
		<title>Test</title>
		<link>http://example.com</link>
		<!-- Another comment -->
	</channel>
</rss>]]

			local result = feedparser.parse(comment_xml)
			assert.is_not_nil(result)
			assert.equals("Test", result.feed.title)
		end)

		it("should handle mixed content (text and elements)", function()
			local mixed_xml = [[<?xml version="1.0"?>
<rss version="2.0">
	<channel>
		<title>Test</title>
		<link>http://example.com</link>
		<item>
			<title>Mixed Content</title>
			<description>Text with <em>emphasis</em> inside</description>
			<link>http://example.com/1</link>
		</item>
	</channel>
</rss>]]

			local result = feedparser.parse(mixed_xml)
			assert.is_not_nil(result)
			assert.equals(1, #result.entries)
			assert.matches("emphasis", result.entries[1].summary)
		end)
	end)
end)
