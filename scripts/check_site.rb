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

def check_site(destination, baseurl: "")
  root = Pathname.new(destination).expand_path
  pages = Dir.glob(File.join(destination, "**", "*.html"))
  assert(!pages.empty?, "No generated HTML found in #{destination}; run the Jekyll build first")

  pages.each do |file|
	document = Nokogiri::HTML(File.read(file))
	assert(document.css("h1").length == 1, "#{file}: expected exactly one h1")
	assert(document.at_css("html[lang='en']"), "#{file}: missing document language")
	assert(document.at_css("title")&.text&.length.to_i > 0, "#{file}: missing title")
	assert(document.at_css("meta[name='description']"), "#{file}: missing description")
	assert(document.at_css("link[rel='canonical']"), "#{file}: missing canonical URL")
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
  assert(root.join("CNAME").read.strip == "allaboutfoxes.com", "Incorrect custom domain")
	%w[Gemfile Gemfile.lock README.md run.cmd scripts/check_site.rb .github/workflows/pages.yml].each do |path|
	assert(!root.join(path).exist?, "Source-only file leaked into site: #{path}")
  end
  puts "Checked #{pages.length} pages: metadata, headings, images, local links, fragments, and output files."
end

check_site(File.join(ROOT, "_site"))
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
  %w[_config.yml _layouts _includes _data assets index.html 404.html robots.txt CNAME].each do |path|
	FileUtils.cp_r(File.join(ROOT, path), source)
  end
  FileUtils.mkdir_p(File.join(source, "foxes", "red-fox"))
	parent_metadata = { "title" => "Foxes of the world", "description" => "Meet the fox family." }
  child_metadata = { "title" => "Red fox", "description" => "Meet the red fox.", "breadcrumbs" => [{ "title" => "Foxes of the world", "url" => "/foxes/" }] }
  File.write(File.join(source, "foxes", "index.md"), parent_metadata.to_yaml + "---\nHere is our **fox field guide**.\n")
  File.write(File.join(source, "foxes", "red-fox", "index.md"), child_metadata.to_yaml + "---\nA red fox has a bushy tail.\n")
  navigation_path = File.join(source, "_data", "navigation.yml")
  navigation = YAML.load_file(navigation_path)
  navigation << { "title" => "Foxes", "url" => "/foxes/", "children" => [{ "title" => "Red fox", "url" => "/foxes/red-fox/" }] }
  File.write(navigation_path, navigation.to_yaml)
  config = Jekyll.configuration("source" => source, "destination" => destination, "baseurl" => "/preview", "quiet" => true)
  Jekyll::Site.new(config).process
  check_site(destination, baseurl: "/preview")
  child = Nokogiri::HTML(File.read(File.join(destination, "foxes", "red-fox", "index.html")))
  assert(child.at_css(".nav-children a[aria-current='page']")&.[]("href") == "/preview/foxes/red-fox/", "Nested navigation did not render the active child")
  assert(child.at_css(".breadcrumbs a[href='/preview/foxes/']"), "Parent breadcrumb did not render")
  assert(child.at_css("link[rel='canonical']")&.[]("href") == "https://allaboutfoxes.com/preview/foxes/red-fox/", "Nested canonical URL is incorrect")
  parent = Nokogiri::HTML(File.read(File.join(destination, "foxes", "index.html")))
  assert(parent.at_css(".prose strong")&.text == "fox field guide", "Markdown content did not render")
  puts "Nested Markdown pages, breadcrumbs, recursive navigation, active links, and subpath hosting passed."
end