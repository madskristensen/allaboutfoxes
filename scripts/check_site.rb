require "jekyll"
require "nokogiri"
require "pathname"
require "tmpdir"
require "fileutils"
require "uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)

def assert(condition, message)
  raise message unless condition
end

def check_social_metadata(document, file, root, baseurl)
  values = {}
  %w[og:title og:description og:type og:url og:site_name og:locale og:image og:image:width og:image:height og:image:alt twitter:card twitter:title twitter:description twitter:image twitter:image:alt].each do |key|
	tags = document.css("head meta[property='#{key}'], head meta[name='#{key}']")
	assert(tags.length == 1, "#{file}: expected exactly one #{key} tag")
	values[key] = tags.first["content"]
	assert(!values[key].to_s.strip.empty?, "#{file}: empty #{key}")
  end
  assert(document.css("head link[rel='canonical']").length == 1, "#{file}: duplicate canonical URL")
  assert(values["og:url"] == document.at_css("link[rel='canonical']")["href"], "#{file}: sharing URL must match canonical URL")
  assert(values["og:site_name"] == "All About Foxes", "#{file}: incorrect sharing site name")
  assert(values["og:locale"] == "en_US", "#{file}: incorrect sharing locale")
  assert(values["twitter:card"] == "summary_large_image", "#{file}: expected a large-image Twitter card")
  %w[title description image image:alt].each do |key|
	assert(values["twitter:#{key}"] == values["og:#{key}"], "#{file}: Twitter and Open Graph #{key} disagree")
  end
  assert(values["og:description"] == document.at_css("meta[name='description']")["content"], "#{file}: sharing description differs from page description")
  assert(document.css("meta[name='twitter:site'], meta[name='twitter:creator']").empty?, "#{file}: do not invent social account handles")

  prefix = "https://www.allaboutfoxes.com#{baseurl}/"
  assert(values["og:image"].start_with?(prefix), "#{file}: sharing image must use an absolute HTTPS URL with the correct baseurl")
  image_path = root.join(values["og:image"].delete_prefix(prefix))
  assert(image_path.file?, "#{file}: sharing image does not exist")
  assert(%w[.png .jpg .jpeg].include?(image_path.extname.downcase), "#{file}: use a PNG or JPEG sharing image, not SVG")
  assert(image_path.size < 5 * 1024 * 1024, "#{file}: sharing image must be smaller than 5 MB")
  bytes = image_path.binread
  dimensions = if bytes.start_with?("\x89PNG\r\n\x1a\n".b)
				 bytes.byteslice(16, 8).unpack("N2")
			   else
				 frame = bytes.match(/\xFF[\xC0-\xC3].{3}(.{4})/mn)
				 assert(frame, "#{file}: JPEG dimensions could not be read")
				 frame[1].unpack("n2").reverse
			   end
  width = Integer(values["og:image:width"])
  height = Integer(values["og:image:height"])
  assert(dimensions == [width, height], "#{file}: image metadata does not match actual pixel dimensions")
  assert(width >= 600 && height >= 300 && (1.8..2.1).cover?(width.fdiv(height)), "#{file}: sharing image must be a large landscape image")
end

def check_site(destination, baseurl: "")
  root = Pathname.new(destination).expand_path
  pages = Dir.glob(File.join(destination, "**", "*.html"))
  assert(!pages.empty?, "No generated HTML found in #{destination}; run the Jekyll build first")

  pages.each do |file|
	document = Nokogiri::HTML(File.read(file))
	check_social_metadata(document, file, root, baseurl)
	assert(document.css("h1").length == 1, "#{file}: expected exactly one h1")
	assert(document.at_css("html[lang='en']"), "#{file}: missing document language")
	assert(document.at_css("title")&.text&.length.to_i > 0, "#{file}: missing title")
	assert(document.at_css("meta[name='description']"), "#{file}: missing description")
	assert(document.at_css("link[rel='canonical']"), "#{file}: missing canonical URL")
	assert(document.at_css("link[rel='canonical']")["href"].start_with?("https://www.allaboutfoxes.com#{baseurl}/"), "#{file}: canonical URL must use the www domain")
	document.css("img").each do |image|
	  assert(image.key?("alt"), "#{file}: image missing alt attribute")
	end

	document.css("[href], [src]").each do |element|
	  reference = element["href"] || element["src"]
	  next if reference.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|//)}i)

	  path, fragment = reference.split("#", 2)
	  path = path.split("?", 2).first.to_s
	  if path.empty?
		target = Pathname.new(file)
	  elsif path.start_with?("/")
		assert(baseurl.empty? || path.start_with?("#{baseurl}/"), "#{file}: link bypasses baseurl: #{reference}")
		target = root.join(URI::DEFAULT_PARSER.unescape(path.delete_prefix(baseurl).delete_prefix("/")))
	  else
		target = Pathname.new(file).dirname.join(URI::DEFAULT_PARSER.unescape(path))
	  end
	  target = target.cleanpath
		assert(target == root || target.to_s.start_with?("#{root}#{File::SEPARATOR}"), "#{file}: link escapes output directory: #{reference}")
	  target = target.join("index.html") if target.directory?
	  assert(target.file?, "#{file}: broken local reference: #{reference}")
	  next if fragment.nil? || fragment.empty? || target.extname != ".html"

	  linked_document = Nokogiri::HTML(File.read(target))
	  id = URI::DEFAULT_PARSER.unescape(fragment)
	  assert(linked_document.css("[id]").any? { |node| node["id"] == id }, "#{file}: missing fragment: #{reference}")
	end
  end

  %w[CNAME robots.txt sitemap.xml assets/css/style.css].each do |path|
	assert(root.join(path).file?, "Missing output: #{path}")
  end
	assert(root.join("CNAME").read.strip == "www.allaboutfoxes.com", "Incorrect custom domain")
  assert(root.join("robots.txt").read.include?("Sitemap: https://www.allaboutfoxes.com#{baseurl}/sitemap.xml"), "Robots sitemap URL must use the www domain")
  sitemap = Nokogiri::XML(root.join("sitemap.xml").read)
  assert(sitemap.xpath("//*[local-name()='loc']").all? { |location| location.text.start_with?("https://www.allaboutfoxes.com#{baseurl}/") }, "Sitemap URLs must use the www domain")
	%w[Gemfile Gemfile.lock README.md run.cmd scripts/check_site.rb .github/workflows/pages.yml .github/copilot-instructions.md].each do |path|
	assert(!root.join(path).exist?, "Source-only file leaked into site: #{path}")
  end
	puts "Checked #{pages.length} pages: metadata, headings, images, local links, fragments, and output files."
end

def check_fox_pages(destination, baseurl: "")
  home = Nokogiri::HTML(File.read(File.join(destination, "index.html")))
  section = Nokogiri::HTML(File.read(File.join(destination, "foxes", "index.html")))
  article = Nokogiri::HTML(File.read(File.join(destination, "foxes", "red-fox", "index.html")))
  assert(home.at_css(".hero .button")["href"] == "#{baseurl}/foxes/", "Homepage must link to Meet the Foxes")
  assert(section.at_css(".species-card[href='#{baseurl}/foxes/red-fox/']"), "Section must link to Red Fox")
  assert(section.at_css(".site-header a[aria-current='page']")["href"] == "#{baseurl}/foxes/", "Section navigation must mark its current page")
  assert(article.at_css(".site-header .is-section-active")["href"] == "#{baseurl}/foxes/", "Article must highlight its parent section")
  assert(article.css(".site-header a[aria-current='page']").empty?, "Parent section must not claim to be the current page")
  assert(article.at_css(".breadcrumbs a[href='#{baseurl}/foxes/']"), "Article is missing its section breadcrumb")
  assert(article.at_css(".breadcrumbs [aria-current='page']").text == "Red Fox", "Article breadcrumb must identify the current page")
  assert(article.at_css(".explore-links a[href='#{baseurl}/foxes/']"), "Article must link back to its section")
  assert(article.css(".quick-facts dt").length == 4, "Fox profile must render its quick facts")
  assert(article.css(".article-contents a").length >= 7, "Article must render its Markdown table of contents")
  assert(article.at_css(".article-photo figcaption").text.include?("NPS / Neal Herbert"), "Photo attribution is missing")
  assert(article.css(".article-photo img, .field-illustration img").length == 2, "Article must include its photograph and identification illustration")
  assert(article.css(".prose").first.text.split.length >= 600, "Red Fox must be a complete article, not a placeholder")
	assert(home.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{baseurl}/assets/images/social-card.png", "Homepage must use the default social card")
  assert(section.at_css("meta[property='og:image']")["content"] == home.at_css("meta[property='og:image']")["content"], "Section must inherit the default social card")
  assert(article.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{baseurl}/assets/images/red-fox-yellowstone.jpg", "Article must override the default card with its own photograph")
  puts "Meet the Foxes cards, article content, photo credits, breadcrumbs, and cross-page navigation passed."
end

check_site(File.join(ROOT, "_site"))
check_fox_pages(File.join(ROOT, "_site"))
template = File.read(File.join(ROOT, "_templates", "page.md"))
metadata = YAML.safe_load(template.split("---", 3)[1])
assert(metadata.fetch("breadcrumbs").first.fetch("url") == "/foxes/", "Page starter has invalid breadcrumbs")
examples = File.read(File.join(ROOT, "README.md")).scan(/```yaml\r?\n(.*?)```/m)
assert(examples.length == 2, "Expected two documented YAML examples")
examples.each do |example|
  YAML.safe_load(example.first)
end

# Exercise future Markdown pages and recursive navigation without publishing sample content.
Dir.mktmpdir("allaboutfoxes-check-") do |temporary|
  source = File.join(temporary, "source")
  destination = File.join(temporary, "output")
  FileUtils.mkdir_p(source)
	%w[_config.yml _layouts _includes _data assets foxes index.html 404.html robots.txt CNAME].each do |path|
	FileUtils.cp_r(File.join(ROOT, path), source)
  end
	FileUtils.mkdir_p(File.join(source, "test-section", "child"))
  parent_metadata = { "title" => "Test section", "description" => "A temporary section." }
  child_metadata = { "title" => 'Test & "child" &lt;guide&gt;', "description" => 'A "fox" & its &lt;habitat&gt;.', "breadcrumbs" => [{ "title" => "Test section", "url" => "/test-section/" }] }
  File.write(File.join(source, "test-section", "index.md"), parent_metadata.to_yaml + "---\nHere is our **fox field guide**.\n")
  File.write(File.join(source, "test-section", "child", "index.md"), child_metadata.to_yaml + "---\nA temporary nested page.\n")
  fox_metadata = YAML.safe_load(File.read(File.join(source, "foxes", "red-fox", "index.md")).split("---", 3)[1])
  { "test-fox" => true, "draft-fox" => false }.each do |name, published|
	directory = File.join(source, "foxes", name)
	FileUtils.mkdir_p(directory)
	data = fox_metadata.merge("title" => name, "nav_order" => 2, "published" => published)
	File.write(File.join(directory, "index.md"), data.to_yaml + "---\nA temporary fox profile.\n")
  end
  navigation_path = File.join(source, "_data", "navigation.yml")
  navigation = YAML.load_file(navigation_path)
	navigation << { "title" => "Test section", "url" => "/test-section/", "children" => [{ "title" => "Test child", "url" => "/test-section/child/" }] }
  File.write(navigation_path, navigation.to_yaml)
  config = Jekyll.configuration("source" => source, "destination" => destination, "baseurl" => "/preview", "quiet" => true)
  Jekyll::Site.new(config).process
  check_site(destination, baseurl: "/preview")
	check_fox_pages(destination, baseurl: "/preview")
  child = Nokogiri::HTML(File.read(File.join(destination, "test-section", "child", "index.html")))
  assert(child.at_css("meta[property='og:title']")["content"] == "Test & \u201cchild\u201d <guide>", "Sharing title must safely preserve quotes, ampersands, and encoded angle brackets after Markdown formatting")
  assert(child.at_css("meta[property='og:description']")["content"] == "A \u201cfox\u201d & its <habitat>.", "Sharing description must safely preserve special characters after Markdown formatting")
  assert(child.at_css(".nav-children a[aria-current='page']")&.[]("href") == "/preview/test-section/child/", "Nested navigation did not render the active child")
  assert(child.at_css(".breadcrumbs a[href='/preview/test-section/']"), "Parent breadcrumb did not render")
  assert(child.at_css("link[rel='canonical']")&.[]("href") == "https://www.allaboutfoxes.com/preview/test-section/child/", "Nested canonical URL is incorrect")
  parent = Nokogiri::HTML(File.read(File.join(destination, "test-section", "index.html")))
  assert(parent.at_css(".prose strong")&.text == "fox field guide", "Markdown content did not render")
	section = Nokogiri::HTML(File.read(File.join(destination, "foxes", "index.html")))
  cards = section.css(".species-card").map { |card| card["href"] }
  assert(cards == ["/preview/foxes/red-fox/", "/preview/foxes/test-fox/"], "Section must automatically list published articles in nav_order and exclude drafts")
  assert(!File.exist?(File.join(destination, "foxes", "draft-fox", "index.html")), "Draft article was published")
  puts "Nested Markdown pages, breadcrumbs, recursive navigation, active links, and subpath hosting passed."
end