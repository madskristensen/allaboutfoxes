require "jekyll"
require "nokogiri"
require "pathname"
require "tmpdir"
require "fileutils"
require "uri"
require "yaml"
require "json"
require "zlib"

ROOT = File.expand_path("..", __dir__)

def assert(condition, message)
  raise message unless condition
end

def image_dimensions(path)
  bytes = File.binread(path)
  return bytes.byteslice(16, 8).unpack("N2") if bytes.start_with?("\x89PNG\r\n\x1a\n".b)

  frame = bytes.match(/\xFF[\xC0-\xC3].{3}(.{4})/mn)
  assert(frame, "#{path}: JPEG dimensions could not be read")
  frame[1].unpack("n2").reverse
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
  structured_tags = document.css("head script[type='application/ld+json']")
  assert(structured_tags.length == 1, "#{file}: SEO plugin must be the single source of structured metadata")
  structured = JSON.parse(structured_tags.first.text)
  assert(structured["@context"] == "https://schema.org" && structured["url"] == values["og:url"], "#{file}: structured metadata must match the canonical sharing URL")
  assert(structured.dig("image", "url") == values["og:image"], "#{file}: structured metadata must use the page sharing image")

  prefix = "https://www.allaboutfoxes.com#{baseurl}/"
  assert(values["og:image"].start_with?(prefix), "#{file}: sharing image must use an absolute HTTPS URL with the correct baseurl")
  image_path = root.join(values["og:image"].delete_prefix(prefix))
  assert(image_path.file?, "#{file}: sharing image does not exist")
  assert(%w[.png .jpg .jpeg].include?(image_path.extname.downcase), "#{file}: use a PNG or JPEG sharing image, not SVG")
  assert(image_path.size < 5 * 1024 * 1024, "#{file}: sharing image must be smaller than 5 MB")
	dimensions = image_dimensions(image_path)
  width = Integer(values["og:image:width"])
  height = Integer(values["og:image:height"])
  assert(dimensions == [width, height], "#{file}: image metadata does not match actual pixel dimensions")
  assert(width >= 600 && height >= 300 && (1.8..2.1).cover?(width.fdiv(height)), "#{file}: sharing image must be a large landscape image")
end

def check_icon_background(path)
  bytes = File.binread(path)
  assert(bytes.getbyte(24) == 8 && [2, 6].include?(bytes.getbyte(25)), "#{path}: expected an 8-bit RGB or RGBA PNG")
  compressed = +"".b
  offset = 8
  while offset < bytes.bytesize
	length = bytes.byteslice(offset, 4).unpack1("N")
	compressed << bytes.byteslice(offset + 8, length) if bytes.byteslice(offset + 4, 4) == "IDAT"
	offset += length + 12
  end
  pixel = Zlib::Inflate.inflate(compressed).byteslice(1, bytes.getbyte(25) == 6 ? 4 : 3).bytes
  assert(pixel.first(3) == [232, 236, 223] && (pixel.length == 3 || pixel.last == 255), "#{path}: home-screen icon must have an opaque homepage-green background")
end

def check_manifest(root, baseurl)
  manifest = JSON.parse(root.join("site.webmanifest").read)
  assert(manifest.values_at("name", "short_name", "lang", "display") == ["All About Foxes", "Fox Field Guide", "en", "standalone"], "Manifest must identify the field guide and use standalone display")
  assert(!manifest.fetch("description").strip.empty?, "Manifest needs a description")
  %w[id start_url scope].each do |key|
	assert(manifest[key] == "#{baseurl}/", "Manifest #{key} must stay within the configured site baseurl")
  end
  assert(manifest["theme_color"] == "#244c3d" && manifest["background_color"] == "#faf7ef", "Manifest colors must match the woodland theme")
  icons = manifest.fetch("icons")
  assert(icons.map { |icon| icon["sizes"] }.sort == ["192x192", "512x512"], "Manifest must supply 192- and 512-pixel icons")
  icons.each do |icon|
	assert(icon["type"] == "image/png" && icon["src"].start_with?("#{baseurl}/assets/images/"), "Manifest icons must be local, subpath-aware PNGs")
	path = root.join(icon["src"].delete_prefix("#{baseurl}/"))
	size = icon.fetch("sizes").split("x").map(&:to_i)
	assert(path.file? && image_dimensions(path) == size, "Manifest icon sizes must match actual pixels")
	check_icon_background(path)
  end
  assert(icons.any? { |icon| icon["sizes"] == "512x512" && icon.fetch("purpose").split.include?("maskable") }, "Manifest must include a maskable icon")
  { "apple-touch-icon.png" => 180, "favicon-32.png" => 32 }.each do |name, size|
	assert(image_dimensions(root.join("assets/images/#{name}")) == [size, size], "Incorrect #{name} dimensions")
	check_icon_background(root.join("assets/images/#{name}")) if name == "apple-touch-icon.png"
  end
  original = Nokogiri::XML(root.join("assets/images/fox-mark.svg").read)
  icon = Nokogiri::XML(root.join("assets/images/app-icon.svg").read)
	background = icon.at_xpath("/*[local-name()='svg']/*[local-name()='rect']")
	assert(background && %w[width height fill].map { |attribute| background[attribute] } == ["512", "512", "#e8ecdf"], "Home-screen artwork must have a full-size homepage-green background")
  logo_paths = ->(svg) { svg.xpath("//*[local-name()='path']").map { |path| path["d"] } }
  assert(logo_paths.call(original) == logo_paths.call(icon), "Home-screen artwork must preserve the header fox logo, not substitute a different fox")
end

def check_site(destination, baseurl: "")
  root = Pathname.new(destination).expand_path
  check_manifest(root, baseurl)
	Dir.glob(File.join(destination, "assets", "images", "*.svg")).each do |image|
	Nokogiri::XML(File.read(image)) { |config| config.strict.nonet }
  end
  pages = Dir.glob(File.join(destination, "**", "*.html"))
  assert(!pages.empty?, "No generated HTML found in #{destination}; run the Jekyll build first")

  pages.each do |file|
	document = Nokogiri::HTML(File.read(file))
	check_social_metadata(document, file, root, baseurl)
	assert(document.css("head link[rel='manifest']").length == 1 && document.at_css("head link[rel='manifest']")["href"] == "#{baseurl}/site.webmanifest", "#{file}: missing subpath-aware manifest link")
	assert(document.at_css("head link[rel='apple-touch-icon'][sizes='180x180']")&.[]("href") == "#{baseurl}/assets/images/apple-touch-icon.png", "#{file}: missing Apple home-screen icon")
	assert(document.at_css("head link[rel='icon'][type='image/png'][sizes='32x32']")&.[]("href") == "#{baseurl}/assets/images/favicon-32.png", "#{file}: missing PNG favicon fallback")
	assert(document.at_css("head link[rel='icon'][type='image/svg+xml']")&.[]("href") == "#{baseurl}/assets/images/fox-mark.svg", "#{file}: favicon must use the header fox")
	assert(document.at_css("head meta[name='theme-color']")&.[]("content") == "#244c3d", "#{file}: browser theme must match manifest")
	brand = document.at_css("a.brand")
	assert(brand && !brand.key?("aria-label") && !brand.key?("aria-labelledby"), "#{file}: brand link must use its visible text as its accessible name")
	assert(document.at_css("link[rel='describedby']")&.[]("href") == "#{baseurl}/llms.txt", "#{file}: missing llms.txt discovery link")
	assert(document.css("h1").length == 1, "#{file}: expected exactly one h1")
	assert(document.at_css("html[lang='en']"), "#{file}: missing document language")
	assert(document.at_css(".site-footer").text.include?("Made by Wesley. Built for discovery."), "#{file}: footer must credit Wesley as the creator")
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

	%w[CNAME robots.txt sitemap.xml llms.txt assets/css/style.css].each do |path|
	assert(root.join(path).file?, "Missing output: #{path}")
  end
	assert(root.join("CNAME").read.strip == "www.allaboutfoxes.com", "Incorrect custom domain")
  assert(root.join("robots.txt").read.include?("Sitemap: https://www.allaboutfoxes.com#{baseurl}/sitemap.xml"), "Robots sitemap URL must use the www domain")
  sitemap = Nokogiri::XML(root.join("sitemap.xml").read)
  assert(sitemap.xpath("//*[local-name()='loc']").all? { |location| location.text.start_with?("https://www.allaboutfoxes.com#{baseurl}/") }, "Sitemap URLs must use the www domain")
  guide = root.join("llms.txt").read
  assert(guide.start_with?("# All About Foxes\n") || guide.start_with?("# All About Foxes\r\n"), "llms.txt must start with the site title, without YAML or an HTML layout")
  assert(guide.include?("\n> A kid-friendly wildlife field guide"), "llms.txt is missing its summary")
  assert(guide.include?("\n## Pages"), "llms.txt is missing its page list")
  urls = guide.scan(/^\- \[.*\]\((https:\/\/[^)]+)\): .+$/).flatten
  expected_urls = sitemap.xpath("//*[local-name()='loc']").map(&:text).select { |url| url.end_with?("/", ".html") }.sort
  assert(urls.sort == expected_urls, "llms.txt must list each published content page exactly once and exclude drafts and utility files")
  assert(!guide.include?("404.html") && !guide.include?("draft-fox"), "llms.txt must exclude error pages and drafts")
  assert(!sitemap.to_xml.include?("/llms.txt"), "llms.txt must not appear as an article in the sitemap")
  assert(!sitemap.to_xml.include?("/site.webmanifest") && !guide.include?("/site.webmanifest"), "The app manifest must not appear as a content article")
	%w[Gemfile Gemfile.lock README.md run.cmd scripts/check_site.rb .github/workflows/pages.yml .github/copilot-instructions.md].each do |path|
	assert(!root.join(path).exist?, "Source-only file leaked into site: #{path}")
  end
	puts "Checked #{pages.length} pages: metadata, headings, images, local links, fragments, and output files."
end

def check_fox_pages(destination, baseurl: "")
  home = Nokogiri::HTML(File.read(File.join(destination, "index.html")))
  section = Nokogiri::HTML(File.read(File.join(destination, "foxes", "index.html")))
	article = Nokogiri::HTML(File.read(File.join(destination, "foxes", "red-fox", "index.html")))
  arctic = Nokogiri::HTML(File.read(File.join(destination, "foxes", "arctic-fox", "index.html")))
	gray = Nokogiri::HTML(File.read(File.join(destination, "foxes", "gray-fox", "index.html")))
	additional = {
	"fennec-fox" => { name: "Fennec Fox", scientific: "Vulpes zerda", lead: "fennec-fox-ears.jpg", second: "fennec-fox-resting.jpg", credit: "Anass ERRIHANI", second_credit: "Grendelkhan", license: "4.0", pups: 2 },
	"bat-eared-fox" => { name: "Bat-eared Fox", scientific: "Otocyon megalotis", lead: "bat-eared-fox-namibia.jpg", second: "bat-eared-fox-foraging.jpg", credit: "Giles Laurent", second_credit: "Hans Hillewaert", license: "3.0", pups: 3 },
	"island-fox" => { name: "Island Fox", scientific: "Urocyon littoralis", lead: "island-fox-channel-islands.jpg", second: "island-fox-habitat.jpg", credit: "National Park Service", second_credit: "National Park Service", pups: 2 }
  }
  new_profiles = additional.map do |slug, details|
	profile = Nokogiri::HTML(File.read(File.join(destination, "foxes", slug, "index.html")))
	assert(profile.at_css(".article-scientific-name").text == details[:scientific], "#{slug}: incorrect species or genus")
	assert(profile.at_css(".breadcrumbs [aria-current='page']").text == details[:name], "#{slug}: incorrect breadcrumb")
	assert(profile.css(".quick-facts dt").length == 4 && profile.css(".article-contents a").length >= 7 && profile.at_css(".prose").text.split.length >= 800, "#{slug}: must be a complete navigable profile")
	expected = [details[:lead], "#{slug}-field-marks.svg", details[:second], "#{slug}-den.svg"].map { |name| "#{baseurl}/assets/images/#{name}" }
	assert(profile.css(".article-photo img, .field-illustration img").map { |image| image["src"] } == expected, "#{slug}: must have two photographs and species-specific identification and den illustrations")
	card = section.at_css(".species-card[href='#{baseurl}/foxes/#{slug}/'] img")
	assert(card && card["src"] == expected.first, "#{slug}: section must automatically show its own lead image")
	assert(profile.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{expected.first}", "#{slug}: sharing preview must use its own photograph")
	lead, second = profile.css(".article-photo figcaption")
	assert(lead.text.include?(details[:credit]) && second.text.include?(details[:second_credit]), "#{slug}: photographs must retain named credits")
	if details[:license]
	  assert(!lead.text.include?("public domain") && lead.at_css("a[href='https://creativecommons.org/licenses/by-sa/4.0/']"), "#{slug}: lead must retain its CC BY-SA 4.0 license, not a public-domain label")
	  assert(second.at_css("a[href='https://creativecommons.org/licenses/by-sa/#{details[:license]}/']"), "#{slug}: secondary photo must use its own verified license version")
	  assert(lead.text.include?("Cropped and resized") && second.text.include?("Resized") && lead.text.include?("remains under") && second.text.include?("same license"), "#{slug}: adapted photographs need modification and share-alike notices")
	else
	  assert(lead.text.include?("public domain") && second.text.include?("public domain"), "#{slug}: retain verified public-domain credits")
	end
	den = profile.at_css("img[src='#{baseurl}/assets/images/#{slug}-den.svg']")
	art = Nokogiri::XML(File.read(File.join(destination, "assets", "images", "#{slug}-den.svg"))) { |config| config.strict.nonet }
	assert(den["width"] == "960" && den["height"] == "650" && art.root["viewBox"] == "0 0 960 650", "#{slug}: den dimensions must match")
	assert(art.xpath("//*[local-name()='use'][@href='#pup']").length == details[:pups], "#{slug}: den must match the stated example litter")
	assert(den.parent.text.include?("not to scale") && den.parent.text.include?("Never approach"), "#{slug}: den needs scale and safety notes")
	profile
  end
  assert(home.at_css(".hero .button")["href"] == "#{baseurl}/foxes/", "Homepage must link to Meet the Foxes")
	arrow = home.at_css(".hero .button svg")
  assert(arrow && arrow["stroke"] == "currentColor" && arrow["aria-hidden"] == "true" && arrow["focusable"] == "false", "Homepage button must use a decorative SVG arrow instead of a platform-dependent emoji")
  assert(home.at_css(".hero .button").text.strip == "Meet the foxes", "Homepage button must not contain a Unicode emoji arrow")
  challenge = home.at_css("#our-adventure")
	assert(challenge.at_css(".eyebrow").text == "A little place to grow", "Homepage must restore the original adventure panel")
  assert(challenge.at_css("h2")["id"] == challenge["aria-labelledby"], "Adventure panel must keep its accessible section heading")
  assert(challenge.at_css("h2").text == "Every explorer needsa place to start.", "Adventure panel must restore its original heading")
  assert(challenge.at_css("a.button")["href"] == "#{baseurl}/quiz/", "Adventure panel must link to the quiz with the correct baseurl")
	assert(section.at_css(".species-card[href='#{baseurl}/foxes/red-fox/']"), "Section must link to Red Fox")
  assert(section.at_css(".species-card[href='#{baseurl}/foxes/arctic-fox/']"), "Section must link to Arctic Fox")
	assert(section.at_css(".species-card[href='#{baseurl}/foxes/gray-fox/']"), "Section must automatically link to Gray Fox")
  assert(home.css(".fact-card").length == 3, "Keep the three original homepage fact cards")
  home.css(".fact-card").each do |card|
	assert(card.css("p").length >= 2 && card.text.split.length >= 70, "Each homepage fact card must explain the fact and why it matters")
	assert(card.at_css("a[href^='#{baseurl}/foxes/']"), "Homepage fact cards must lead to deeper field notes")
  end
  assert(section.at_css(".site-header a[aria-current='page']")["href"] == "#{baseurl}/foxes/", "Section navigation must mark its current page")
  assert(article.at_css(".site-header .is-section-active")["href"] == "#{baseurl}/foxes/", "Article must highlight its parent section")
  assert(article.css(".site-header a[aria-current='page']").empty?, "Parent section must not claim to be the current page")
  assert(article.at_css(".breadcrumbs a[href='#{baseurl}/foxes/']"), "Article is missing its section breadcrumb")
  assert(article.at_css(".breadcrumbs [aria-current='page']").text == "Red Fox", "Article breadcrumb must identify the current page")
  assert(article.at_css(".explore-links a[href='#{baseurl}/foxes/']"), "Article must link back to its section")
  assert(article.css(".quick-facts dt").length == 4, "Fox profile must render its quick facts")
  assert(article.css(".article-contents a").length >= 7, "Article must render its Markdown table of contents")
  assert(article.at_css(".article-photo figcaption").text.include?("NPS / Neal Herbert"), "Photo attribution is missing")
	expected_images = %w[red-fox-yellowstone.jpg red-fox-field-marks.svg red-fox-kits.jpg red-fox-den.svg].map { |name| "#{baseurl}/assets/images/#{name}" }
  assert(article.css(".article-photo img, .field-illustration img").map { |image| image["src"] } == expected_images, "Red Fox must include its photographs, identification illustration, and den diagram")
  kits_caption = article.at_css("img[src='#{baseurl}/assets/images/red-fox-kits.jpg']").parent.at_css("figcaption")
  assert(kits_caption.text.include?("Jennifer Cross") && kits_caption.text.include?("Resized") && kits_caption.at_css("a[href='https://creativecommons.org/licenses/by/2.0/']"), "Red fox kits must retain attribution, license link, and modification notice")
	expected_arctic_images = %w[arctic-fox-winter.jpg arctic-fox-field-marks.svg arctic-fox-tundra.jpg arctic-fox-molt.jpg arctic-fox-den.svg arctic-fox-kits.jpg].map { |name| "#{baseurl}/assets/images/#{name}" }
  assert(arctic.css(".article-photo img, .field-illustration img").map { |image| image["src"] } == expected_arctic_images, "Arctic Fox must lead with its white winter photograph and retain seasonal photographs and species-specific diagrams")
  arctic_card = section.at_css(".species-card[href='#{baseurl}/foxes/arctic-fox/'] img")
  assert(arctic_card["src"] == "#{baseurl}/assets/images/arctic-fox-winter.jpg", "Meet the Foxes must show the white winter Arctic fox")
  assert(arctic.at_css(".article-photo figcaption").text.include?("Keith Morehouse"), "White winter photograph must credit Keith Morehouse")
	[article, arctic, gray, *new_profiles].each do |profile|
	assert(profile.at_css(".site-header .is-section-active")["href"] == "#{baseurl}/foxes/", "Each profile must highlight Meet the Foxes")
	assert(profile.at_css(".breadcrumbs a[href='#{baseurl}/foxes/']") && profile.at_css(".explore-links a[href='#{baseurl}/foxes/']"), "Each profile needs breadcrumbs and a return trail")
	profile.css(".article-photo").each_with_index do |figure, index|
	  image = figure.at_css("img")
	  path = File.join(destination, image["src"].delete_prefix(baseurl).delete_prefix("/"))
	  assert(image_dimensions(path) == [Integer(image["width"]), Integer(image["height"])], "Profile photo dimensions must match its actual pixels")
	  assert(File.size(path) < 1024 * 1024, "Profile photographs must be web-sized (under 1 MB)")
	  assert(!image["alt"].to_s.strip.empty?, "Profile photographs need descriptive alt text")
	  assert(figure.at_css("figcaption a[href^='https://']"), "Each photograph needs a linked credit")
	  assert(image["loading"] == "lazy", "Below-the-fold photos must be lazy loaded") unless index.zero?
	end
  end
  assert(arctic.css(".prose").first.text.split.length >= 1000 && arctic.css(".article-contents a").length >= 8, "Arctic Fox must be a complete navigable field note")
  assert(arctic.at_css(".breadcrumbs [aria-current='page']").text == "Arctic Fox", "Arctic breadcrumb must identify the current page")
	assert(arctic.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{baseurl}/assets/images/arctic-fox-winter.jpg", "Arctic Fox must use its white winter sharing photograph")
  arctic_den = Nokogiri::XML(File.read(File.join(destination, "assets", "images", "arctic-fox-den.svg"))) { |config| config.strict.nonet }
  assert(arctic_den.root["viewBox"] == "0 0 960 760", "Arctic den must match its declared dimensions")
  assert(arctic_den.xpath("//*[local-name()='use'][@href='#pup']").length == 7, "Arctic den must illustrate seven pups, as its caption explains")
  arctic_labels = arctic_den.xpath("//*[local-name()='text']").map(&:text)
  assert((1..4).all? { |number| arctic_labels.include?("Entrance #{number}") }, "Arctic den must label its four connected entrances")
  assert(arctic_labels.any? { |label| label.include?("Frozen ground") }, "Arctic den must explain its schematic frozen-ground layer")
  arctic_den_figure = arctic.at_css("img[src='#{baseurl}/assets/images/arctic-fox-den.svg']")
  assert(arctic_den_figure["width"] == "960" && arctic_den_figure["height"] == "760", "Arctic den must declare its dimensions")
  assert(arctic_den_figure.parent.text.include?("not to scale") && arctic_den_figure.parent.text.include?("Never approach"), "Arctic den needs scale and wildlife-safety notes")
	expected_gray_images = %w[gray-fox-woodland.jpg gray-fox-field-marks.svg gray-fox-camera-trap.jpg gray-fox-den.svg].map { |name| "#{baseurl}/assets/images/#{name}" }
  assert(gray.css(".article-photo img, .field-illustration img").map { |image| image["src"] } == expected_gray_images, "Gray Fox must include two photographs and species-specific field-mark and den diagrams")
  assert(gray.at_css(".breadcrumbs [aria-current='page']").text == "Gray Fox", "Gray Fox breadcrumb must identify the current page")
  assert(gray.at_css(".article-scientific-name").text == "Urocyon cinereoargenteus", "Gray Fox must identify its separate species and genus")
  assert(gray.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{baseurl}/assets/images/gray-fox-woodland.jpg", "Gray Fox must use its own sharing photograph")
  assert(gray.css(".quick-facts dt").length == 4 && gray.css(".article-contents a").length >= 7 && gray.at_css(".prose").text.split.length >= 800, "Gray Fox must be a complete navigable profile")
  assert(gray.at_css(".article-photo figcaption").text.include?("Tammy Mealman"), "Gray Fox lead photo must retain its credit")
  camera_caption = gray.at_css("img[src='#{baseurl}/assets/images/gray-fox-camera-trap.jpg']").parent.at_css("figcaption")
  assert(camera_caption.text.include?("Bryan White") && camera_caption.text.include?("public domain"), "Gray Fox camera photo must retain its credit and license")
  gray_den = gray.at_css("img[src='#{baseurl}/assets/images/gray-fox-den.svg']")
  assert(gray_den["width"] == "960" && gray_den["height"] == "650", "Gray fox den must declare its dimensions")
  gray_den_art = Nokogiri::XML(File.read(File.join(destination, "assets", "images", "gray-fox-den.svg"))) { |config| config.strict.nonet }
  assert(gray_den_art.root["viewBox"] == "0 0 960 650" && gray_den_art.xpath("//*[local-name()='use'][@href='#pup']").length == 4, "Gray fox den must show four example pups in its hollow log")
  assert(gray_den.parent.text.include?("not to scale") && gray_den.parent.text.include?("Never approach"), "Gray fox den needs scale and wildlife-safety notes")
  den = article.at_css(".field-illustration img[src='#{baseurl}/assets/images/red-fox-den.svg']")
	assert(den["width"] == "960" && den["height"] == "760", "Den diagram must declare its dimensions")
  assert(["three entrances", "branching tunnels", "side chamber", "nursery", "five kits"].all? { |feature| den["alt"].include?(feature) }, "Den diagram must describe its connected passages, chambers, and five kits in alt text")
  den_art = Nokogiri::XML(File.read(File.join(destination, "assets", "images", "red-fox-den.svg"))) { |config| config.strict.nonet }
  assert(den_art.root["viewBox"] == "0 0 960 760", "Den diagram dimensions must match its viewBox")
  assert(den_art.xpath("//*[local-name()='use'][@href='#kit']").length == 5, "Den illustration must show five kits")
  labels = den_art.xpath("//*[local-name()='text']").map(&:text)
  assert(["Main entrance", "Another entrance", "An exit", "Branching", "tunnels", "Side chamber", "Nursery chamber"].all? { |label| labels.include?(label) }, "Den diagram must label its entrances, branching tunnels, and chambers")
  caption = den.parent.at_css("figcaption")
  assert(caption.text.include?("not to scale") && caption.text.include?("Never approach"), "Den caption must explain the simplified view and safe wildlife watching")
	assert(caption.at_css("a[href='https://commons.wikimedia.org/wiki/File:Foxden.jpg']") && caption.at_css("a[href='https://www.wildlifeonline.me.uk/animals/article/red-fox-dens-earths-resting-sites']"), "Den diagram must credit its excavated-den plan and modern wildlife reference")
  assert(article.css(".prose").first.text.split.length >= 600, "Red Fox must be a complete article, not a placeholder")
	assert(home.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{baseurl}/assets/images/social-card.png", "Homepage must use the default social card")
	assert(section.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{baseurl}/assets/images/social-foxes.png", "Meet the Foxes must use its own six-species sharing card")
  assert(article.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{baseurl}/assets/images/red-fox-yellowstone.jpg", "Article must override the default card with its own photograph")
  puts "Meet the Foxes cards, article content, photo credits, breadcrumbs, and cross-page navigation passed."
end

def check_quiz(destination, baseurl: "")
  quiz = Nokogiri::HTML(File.read(File.join(destination, "quiz", "index.html")))
	assert(quiz.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{baseurl}/assets/images/social-quiz.png", "Quiz must use its own field-notebook sharing card")
  error_page = Nokogiri::HTML(File.read(File.join(destination, "404.html")))
  assert(error_page.at_css("meta[property='og:image']")["content"] == "https://www.allaboutfoxes.com#{baseurl}/assets/images/social-trail.png", "404 must use its winding-trail sharing card")
  data = YAML.load_file(File.join(ROOT, "_data", "quiz.yml"))
  questions = quiz.css("#fox-quiz fieldset")
  assert(data.length == 10 && questions.length == data.length, "Quiz must render all ten questions")
  assert(quiz.at_css("script[src='#{baseurl}/assets/js/quiz.js'][defer]"), "Quiz must load its local deferred script with the correct baseurl")
  assert(quiz.at_css("#quiz-progress[aria-live='polite']"), "Quiz needs accessible answer progress")
  assert(quiz.at_css("#quiz-results[tabindex='-1'][hidden]"), "Quiz results must start hidden and accept focus")
  assert(quiz.at_css(".quiz-actions[hidden] button[type='submit']") && quiz.at_css("button[type='reset']"), "Quiz must have progressively enhanced check and retry controls")
  assert(quiz.css("noscript details li").length == data.length, "Quiz must provide an answer key without JavaScript")
  questions.zip(data).each_with_index do |(question, entry), index|
	options = question.css("input[type='radio']")
	assert(entry.fetch("options").length == 3 && entry.fetch("options").all? { |option| option.is_a?(String) }, "Quiz options must be three text choices")
	assert((1..3).cover?(entry.fetch("answer")), "Quiz answer index is invalid")
	assert(options.length == 3 && options.all? { |input| input.key?("required") && input["name"] == "question-#{index + 1}" }, "Each question must be one required radio group")
	assert(question["data-answer"] == entry.fetch("answer").to_s && !question.at_css("legend").text.strip.empty?, "Quiz needs a question legend and a matching answer key")
	options.each do |input|
	  assert(question.at_css("label[for='#{input['id']}']"), "Each quiz choice needs an explicit label")
	  assert(question.at_css("label[for='#{input['id']}'] .quiz-answer-status[hidden]"), "Each quiz choice needs a text result label hidden before grading")
	end
	feedback = question.at_css(".quiz-feedback[hidden]")
	assert(feedback && question["aria-describedby"] == feedback["id"], "Each question needs associated feedback, hidden before grading")
	assert(feedback.at_css("a")["href"] == "#{baseurl}#{entry.fetch('source')}", "Each explanation needs its subpath-aware research link")
  end
  puts "Quiz questions, answer keys, labels, progressive enhancement, and research links passed."
end

check_site(File.join(ROOT, "_site"))
check_fox_pages(File.join(ROOT, "_site"))
check_quiz(File.join(ROOT, "_site"))
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
	%w[_config.yml _layouts _includes _data assets foxes quiz index.html 404.html robots.txt llms.txt site.webmanifest CNAME].each do |path|
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
	data = fox_metadata.merge("title" => name, "nav_order" => 7, "published" => published)
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
	check_quiz(destination, baseurl: "/preview")
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
	assert(cards == %w[red-fox arctic-fox gray-fox fennec-fox bat-eared-fox island-fox test-fox].map { |slug| "/preview/foxes/#{slug}/" }, "Section must automatically list published articles in nav_order and exclude drafts")
  assert(!File.exist?(File.join(destination, "foxes", "draft-fox", "index.html")), "Draft article was published")
  puts "Nested Markdown pages, breadcrumbs, recursive navigation, active links, and subpath hosting passed."
end