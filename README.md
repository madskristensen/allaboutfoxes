# All About Foxes

A small wildlife field guide for curious kids, made for Wesley. Built with
Jekyll and deployed to GitHub Pages at **https://www.allaboutfoxes.com**.

The site includes the original front page, a Meet the Foxes section,
illustrated Red Fox, Arctic Fox, Gray Fox, Fennec Fox, Bat-eared Fox, and Island
Fox profiles, a fox knowledge quiz, and a friendly
404. There are no empty "coming soon" pages, external fonts, trackers, cookies,
or third-party image requests. A small local script powers the quiz only;
the rest of the site stays static. The SVG fox illustrations are original site artwork; the
locally hosted photographs are credited below and beside each photograph.

## Local preview

Install Ruby 3.4 and Bundler. On Windows, use RubyInstaller **with Devkit**.
On Windows, double-click `run.cmd` (or run `.\run.cmd` in PowerShell). It checks
dependencies, installs any that are missing, and opens http://localhost:4002
with automatic rebuilding and browser live reload. It always runs from the site
directory, even when launched from another working directory. Ruby and Bundler
must already be on PATH. Startup failures stay visible in the command window.

Alternatively, from this directory:

```powershell
bundle install
bundle exec jekyll serve --host 127.0.0.1 --port 4002 --livereload --livereload-port 35731
```

Open http://localhost:4002. Markdown and layout changes rebuild automatically;
restart the server after editing `_config.yml`. Stop it with Ctrl+C.

Before publishing:

```powershell
$env:JEKYLL_ENV = 'production'
bundle exec jekyll build --trace
bundle exec ruby scripts\check_site.rb
```

The checker validates generated HTML, local links and anchors, metadata, images,
strict SVG XML, the logo link's accessible labeling,
and source-file exclusions. Profile checks cover photo dimensions and web-sized
files, linked credits, species-specific diagrams, automatic card ordering, and
expanded homepage fact cards. Quiz checks cover answer keys, accessible labels,
no-JavaScript answers, and research links. It also builds temporary parent/child Markdown pages
under a `/preview` base path to exercise recursive navigation and breadcrumbs.
These test pages are never included in the published site.

## Where things live

| Path | Purpose |
| --- | --- |
| `index.html` | The front page: welcome, facts, and the adventure panel with a quiz link |
| `_config.yml` | Site title, description, canonical domain, and defaults |
| `_data/navigation.yml` | Header links; supports nested `children` |
| `_data/quiz.yml` | Quiz questions, three choices, correct answer, explanation, and source |
| `_layouts/default.html` | Shared head, header, navigation, and footer |
| `_layouts/page.html` | Article layout with title and breadcrumbs |
| `_layouts/section.html` | Section landing page with automatic fox article cards |
| `_layouts/fox.html` | Fox profile with photograph, credit, and quick facts |
| `_includes/navigation.html` | Recursive navigation renderer |
| `foxes/index.md` | Meet the Foxes section at `/foxes/` |
| `foxes/red-fox/index.md` | Complete example article at `/foxes/red-fox/` |
| `foxes/arctic-fox/index.md` | Arctic fox profile, seasonal coats, and tundra den |
| `foxes/gray-fox/index.md` | Gray fox profile, tree-climbing adaptations, and hollow-log den |
| `foxes/fennec-fox/index.md` | Fennec profile, desert adaptations, and shrub-supported sandy den |
| `foxes/bat-eared-fox/index.md` | Bat-eared profile, insect-hunting teeth, and family burrow |
| `foxes/island-fox/index.md` | Island profile, six island subspecies, rock shelter, and conservation |
| `quiz/index.md` | Accessible ten-question quiz at `/quiz/` |
| `site.webmanifest` | Home-screen app name, scope, theme, and icons |
| `_templates/page.md` | Copyable page starter; not published by Jekyll |
| `assets/css/style.css` | Responsive design and reduced-motion support |
| `assets/js/quiz.js` | Local-only quiz progress, scoring, explanations, and retry |
| `assets/images/` | Original SVG artwork and credited, locally hosted photographs |
| `.github/workflows/pages.yml` | Build, validate, and deploy |
| `scripts/check_site.rb` | Build-output and page-structure checks |
| `scripts/export_artwork.mjs` | Optional local Edge/Chromium export of original SVG cards and icons |
| `llms.txt` | Automatically generated content guide for AI tools |

## Add pages and subpages

Copy `_templates/page.md` to `fox-life\index.md` for `/fox-life/`. Edit its title,
description, and Markdown, and remove `breadcrumbs` for this top-level page.
No project file or route registration is needed: Jekyll finds the page.

For a subpage, copy the starter to `fox-life\food\index.md`. That becomes
`/fox-life/food/`. For example, set the child's front matter to:

```yaml
---
title: What foxes eat
description: Discover what is on a fox's menu.
eyebrow: Fox life
breadcrumbs: [{ title: Fox life, url: /fox-life/ }]
---
```

For deeper pages, list every ancestor in `breadcrumbs`, outermost first. The
layout adds Home and the current title. Start article headings at `##` because
the page layout already provides its `h1`.

Add pages to `_data/navigation.yml` when they are ready:

```yaml
- { title: Home, url: / }
- { title: Foxes of the world, url: /foxes/, children: [{ title: Red fox, url: /foxes/red-fox/ }] }
```

Children can have their own children. Navigation remains visible and usable on
small screens without a JavaScript menu. Pages do not appear in navigation
until explicitly added. Only link to pages that exist.

In Markdown or HTML, use Liquid for internal links and image paths so the site
also works under a repository subpath:

```liquid
[Meet the red fox]({{ '/foxes/red-fox/' | relative_url }})
![Describe the fox photo]({{ '/assets/images/your-photo.jpg' | relative_url }})
```

Keep facts age-appropriate, cite reliable sources, and only use photos you own
or have permission to publish. Avoid publishing personal details about children.

### Add another fox to Meet the Foxes

Use `foxes\red-fox\index.md` as the complete working example. Create a new
directory for the new species and write its `index.md`. Keep `layout: fox`
and `section: /foxes/`, then update the title, description, scientific name,
`nav_order`, breadcrumbs, and all image and quick-fact fields for that species.
Use an `image` object with `path`, `width`, `height`, and descriptive `alt` text,
as in the Red Fox example. These fields drive both the displayed photo and
social-sharing metadata. Set dimensions to the photo's actual pixel size.

The section layout automatically lists published pages whose `section` matches
the landing page URL, sorted by `nav_order`. Do not add each fox to the header:
the header links to Meet the Foxes, its cards link to articles, and each article
has breadcrumbs and links back to the section and homepage. The section header
link stays highlighted while reading a fox article, without incorrectly marking
the section landing page as the current page.

Article headings create the on-page contents list through Kramdown's `{:toc}`.
Use the existing `field-illustration`, `explorer-note`, and `wonder-box` patterns
for captioned figures, activities, and revealable questions. Cite sources at the
end of each article and keep photo credits attached to the photograph.

Keep the welcoming language, but give fox enthusiasts real detail: define
technical terms, distinguish local averages from species-wide ranges, name
units and populations, and identify the source of developmental timelines.
Do not combine conflicting sources into an invented universal value. Match
identification and den illustrations to the species and season rather than
recoloring the red fox. Explain schematic features and never imply that an
illustrative den is a measured blueprint.

Add educational photographs throughout each profile with `article-photo`
figures, descriptive alt text, actual pixel dimensions, and linked credits.
Lazy-load photos below the lead image, keep files under 1 MB, and use
`relative_url` for local paths. Lead photos default to a public-domain credit:
use that only when verified. For a licensed lead, set both `image_license`
(for example, `CC BY-SA 4.0`) and `image_license_url`, and include changes in
`image_caption`. The layout links the license beside the photographer. For
other figures, put the license link and modification notice in the caption.
Adapted CC BY-SA photographs retain their respective share-alike licenses;
this does not relicense the whole website or its original artwork.

### Photograph credits and illustration research

`assets/images/red-fox-yellowstone.jpg` is a locally hosted photograph by
**NPS / Neal Herbert**, from [Yellowstone National Park's Red Fox page](https://www.nps.gov/yell/learn/nature/red-fox.htm).
The [NPS image-use policy](https://www.nps.gov/aboutus/disclaimer.htm) identifies
NPS-created U.S. Government works as public domain unless otherwise noted.
The downloaded image is 960 by 481 pixels. No NPS logo is used and no endorsement
is implied. The fox field-marks and den cutaway SVGs are original illustrations,
not photographs. The den diagram is a source-informed, not-to-scale example with
three connected openings, branching tunnels, a side chamber, and a nursery with
a mother and five kits. References include [Seton's public-domain excavated-den
plan](https://commons.wikimedia.org/wiki/File:Foxden.jpg), its accompanying account
in *Life-histories of Northern Animals* (volume II, pages 716-717 and 721),
[Wildlife Online's den research and photographs](https://www.wildlifeonline.me.uk/animals/article/red-fox-dens-earths-resting-sites),
and [Linda J. Spielman's entrance photographs](https://lindajspielman.com/2021/08/23/checking-out-fox-dens/).
It is not a measured reconstruction of one den: real dens vary in complexity,
and not all have side chambers. Reference photographs are not republished.

Additional photographs, all hosted locally as JPEGs:

| Local image | Photographer and source record | Reuse and changes |
| --- | --- | --- |
| `red-fox-kits.jpg` (1200 by 800) | [Jennifer Cross / USFWS](https://commons.wikimedia.org/wiki/File:Red_fox_kits_(40215161564).jpg) | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/); resized |
| `arctic-fox-winter.jpg` (1200 by 630) | [Keith Morehouse / USFWS](https://commons.wikimedia.org/wiki/File:Alopex_lagopus_coiled_up_in_snow.jpg) | Public domain; center-cropped and resized; profile lead, section card, and sharing image |
| `arctic-fox-tundra.jpg` (1200 by 630) | [Lisa Hupp / USFWS](https://commons.wikimedia.org/wiki/File:Arctic_fox_(51356519412).jpg) | Public domain; center-cropped and resized |
| `arctic-fox-molt.jpg` (1200 by 900) | [AGB / USFWS](https://commons.wikimedia.org/wiki/File:Shedding_Arctic_Fox_(51293918357).jpg) | Public domain; resized |
| `arctic-fox-kits.jpg` (1200 by 801) | [Lisa Hupp / USFWS](https://commons.wikimedia.org/wiki/File:Arctic_fox_siblings_(51358274825).jpg) | Public domain; resized |
| `gray-fox-woodland.jpg` (1200 by 630) | [Tammy Mealman / USFWS](https://commons.wikimedia.org/wiki/File:Gray_Fox_(35870741011).jpg) | Public domain; center-cropped and resized |
| `gray-fox-camera-trap.jpg` (1200 by 862) | [Bryan White / USFWS](https://commons.wikimedia.org/wiki/File:Gray_fox_(6492408315).jpg) | Public domain; resized |
| `fennec-fox-ears.jpg` (1200 by 630) | [Anass ERRIHANI](https://commons.wikimedia.org/wiki/File:Fennec_Fox_Peek.jpg) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/); top-cropped and resized; adapted image retains this license |
| `fennec-fox-resting.jpg` (1200 by 800) | [Grendelkhan](https://commons.wikimedia.org/wiki/File:Sleeping_Vulpes_zerda_at_Happy_Hollow,_closeup.jpg) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/); resized; adapted image retains this license; photographed at Happy Hollow Park and Zoo |
| `bat-eared-fox-namibia.jpg` (1200 by 630) | [Giles Laurent](https://commons.wikimedia.org/wiki/File:187_Bat-eared_fox_in_Otjozondjupa_Region_Photo_by_Giles_Laurent.jpg) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/); top-cropped and resized; adapted image retains this license |
| `bat-eared-fox-foraging.jpg` (1200 by 900) | [Hans Hillewaert](https://commons.wikimedia.org/wiki/File:Otocyon_megalotis_(Namibia).jpg) | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/); resized; adapted image retains this license |
| `island-fox-channel-islands.jpg` (1200 by 630) | [National Park Service](https://commons.wikimedia.org/wiki/File:Urocyon_littoralis_full_figure.jpg) | Public domain; top-cropped and resized |
| `island-fox-habitat.jpg` (1200 by 900) | [National Park Service](https://commons.wikimedia.org/wiki/File:Island_fox_(0795e6f3ace4496ca92c041c061083ba).jpg) | Public domain; resized |

The Arctic fox field-marks illustration shows compact winter proportions,
furry paws, and seasonal swatches for both white and blue morphs. Its summer
den cutaway shows a treeless mound, four connected entrances, an adult in a
brown summer coat, seven dark pups, and a schematic frozen-ground boundary.
These original SVGs are informed by [Alaska Fish and Game's Arctic fox
account](https://www.adfg.alaska.gov/index.cfm?adfg=arcticfox.printerfriendly)
and [Animal Diversity Web's den descriptions](https://animaldiversity.org/accounts/Vulpes_lagopus/).
The drawing is not to scale: entrance counts, litter size, and thaw depth
vary. The article follows the Alaska account consistently for pup milestones
and explicitly distinguishes its timeline from ADW's older summary.

The Gray Fox profile uses the same layouts but identifies **Urocyon**, not
**Vulpes**. Its original field-marks SVG labels the grizzled back, rusty legs,
black tail stripe, black tail tip, and a schematic hooked claw. The hollow-log
den cutaway shows one sheltered cavity with an adult and four example pups,
not an underground tunnel system copied from another species. References are
[NPS identification and den notes](https://www.nps.gov/cwdw/learn/nature/gray-fox.htm),
[NPS climbing anatomy and diet notes](https://www.nps.gov/zion/learn/nature/gray-fox.htm),
[Animal Diversity Web](https://animaldiversity.org/accounts/Urocyon_cinereoargenteus/),
and [the University of Minnesota](https://mnmammals.d.umn.edu/gray-fox).
The latter supplies geographically labeled measurements and the profile's pup
timeline. Keep climbing claims species-specific rather than applying them to
foxes as a group. A silver fox remains a color form of the red fox, not a gray fox.

The three additional species also have original, species-specific SVG pairs.
Fennec diagrams show huge ears, furry feet, and sandy passages beneath a shrub
with two example pups, informed by [Smithsonian](https://nationalzoo.si.edu/animals/fennec-fox)
and [Animal Diversity Web](https://animaldiversity.org/accounts/Vulpes_zerda/).
Bat-eared fox diagrams show dark field marks, a tooth-count note, and a grassland
burrow with three example kits, informed by [San Diego Zoo](https://animals.sandiegozoo.org/animals/bat-eared-fox)
and [Smithsonian](https://nationalzoo.si.edu/animals/bat-eared-fox). The latter
supplies the profile's pup timeline. Island fox diagrams show gray-and-rust field
marks and an existing rock cavity with two dark example pups, informed by
[NPS](https://www.nps.gov/chis/learn/nature/island-fox.htm) and
[Animal Diversity Web](https://animaldiversity.org/accounts/Urocyon_littoralis/).
The conservation story explicitly dates the [2016 federal recovery decision](https://www.fws.gov/press-release/2016-08/interior-announces-fastest-successful-recovery-endangered-species-act-0)
rather than presenting historical counts or listings as current. All den
layouts are illustrative, not measured plans; captions explain scale and safety.

## Fox knowledge quiz

The homepage adventure panel links to `/quiz/`. Edit `_data/quiz.yml` to maintain
its ten questions: each entry has a `question`, three text `options`, a one-based
`answer` index, an `explanation`, and a `source` URL with a `source_label`.
Quote choices containing commas or words such as "Yes" and "No" so YAML preserves
them as text. Every answer must be supported by the linked field-guide section;
keep its fragment valid when changing article headings.

The page uses native labeled radio groups and required-answer validation. Its
local script shows progress, grades all answers, explains each answer, focuses
the result, and supports changing answers or starting over. After grading,
correct choices are green and wrong selections are warm red, with explicit
text labels and question verdicts so color is never the only clue. Changing
an answer or retrying clears all previous result labels and highlights. There is no timer,
account, storage, network submission, analytics, or external script. Without
JavaScript, readers can still choose answers and open the native answer key.
Keep this script scoped to the quiz rather than adding JavaScript site-wide.

When changing quiz behavior, also exercise unanswered submission, all-correct,
partly correct, and all-incorrect answers, edits after grading, retry, keyboard
controls, narrow screens, and the no-JavaScript answer key in a browser.

## Social sharing previews

The existing `jekyll-seo-tag` plugin is the single source for Open Graph,
Twitter/X cards, canonical links, and JSON-LD. Do not add duplicate tags to
layouts. Each page gets its own title, description, and absolute HTTPS URL.
No Twitter handles or Facebook app IDs are configured because the site does
not have verified social accounts to identify.

Pages without their own image inherit the original woodland card at
`assets/images/social-card.png` (1200 by 630 pixels). Its editable source is
`assets/images/social-card.svg`; after editing it, export a PNG at exactly
1200 by 630 pixels and commit both files. Social crawlers need the raster
image, not the SVG. Meet the Foxes has its own six-portrait woodland card,
the quiz has a field-notebook card, and the 404 has a winding-trail card.
Each fox profile instead uses its own credited local lead photograph. All
current content pages therefore have relevant, distinct sharing images.

To override the default, set an `image` object in front matter with `path`,
`width`, `height`, and `alt`. Use a local PNG or JPEG under 5 MB, at least
600 pixels wide, and approximately 1.9:1 to 2:1. Prefer 1200 by 630 for new
cards. Keep text and key subjects clear of the edges, since platforms crop
previews differently. For fox profiles, this image also appears in the article
and its section card, so preserve the photo credit fields.

The site checker verifies unique tags, descriptive alt text, matching
Open Graph/Twitter values, fallback and per-page images, real image dimensions,
and subpath-aware URLs. It also tests special characters in titles/descriptions.
After deployment, inspect the public URL in Facebook's Sharing Debugger or
LinkedIn's Post Inspector if an old preview persists; platforms cache previews
and may need to fetch the page again. No sharing scripts, tracking, or external
image service is needed.

## Save to a home screen

Every page links to `site.webmanifest`, which defines the app name, stable
identity, home start URL, scope, standalone display, woodland theme, and local
192- and 512-pixel PNG icons with an enlarged fox face. A separate 512-pixel
maskable icon keeps the fox inside the central 80%-diameter safe circle to
prevent cropping by Android launchers. All icons have an opaque woodland sage
green background (#7e977e) extending to the edges. `apple-touch-icon.png`
(180 pixels) supplies the iPhone/iPad icon; a 32-pixel PNG favicon backs up
the existing SVG favicon. All paths also work under a repository subpath.

After an icon update is deployed, an existing home-screen shortcut may keep its
cached image. Remove it and add the site to the home screen again to refresh it.

The editable icon source is `assets/images/app-icon.svg`; the exporter applies
extra padding for `icon-maskable-512.png`. To re-export that
artwork and all four social-card SVGs using Node.js 22+ and a locally installed
Edge/Chromium browser, run:

```powershell
node scripts\export_artwork.mjs
```

The exporter detects Edge on Windows and common Chromium paths on Linux.
Set `BROWSER_PATH` to an installed browser executable for other locations.
It uses an isolated temporary browser profile, no packages or network service,
and writes the matching PNGs under `assets/images`; commit sources and PNGs.
Node and a browser are only needed when regenerating artwork, not for Jekyll
builds, CI validation, or browsing. The checker validates manifest JSON, icon
sizes, Apple links, social metadata, and `/preview` scope and URLs.

Device/browser support determines the exact Add to Home Screen or Install
experience. There is deliberately no service worker, offline promise, push
permission, install prompt, tracking, or sharing widget. Saving the icon is
not a guarantee that every browser will offer app installation or work offline.

## AI content guide

`/llms.txt` is an optional Markdown-format guide for AI tools. Jekyll generates
it from published pages' titles, descriptions, and absolute canonical URLs;
new articles appear automatically. Error pages, drafts, and utility files are
excluded. Each HTML page has a `rel="describedby"` link to help discover it.

Keep page titles and descriptions meaningful. The checker verifies the guide
at the domain root and under `/preview`, checks its links against the sitemap,
and ensures drafts stay out. This does not add JavaScript, WebMCP, an external
service, or a guarantee of improved search rankings. It is not a crawler access
policy or an image license; retain `robots.txt` and individual image credits.

## GitHub publishing

The public repository is [madskristensen/allaboutfoxes](https://github.com/madskristensen/allaboutfoxes).
The production branch is `main`. The repository and any deployed Pages site
are public, so do not add secrets or private information.

To publish future changes after running the checks above:

```powershell
git add .
git commit -m "Update fox field guide"
git push origin main
```

### Pages configuration

1. On the repository, open **Settings > Pages** and set **Build and deployment >
   Source** to **GitHub Actions**. Enable Actions if your account restricts them.

2. Set the **Custom domain** to `www.allaboutfoxes.com` in those Pages settings
   **before changing DNS**. The included `CNAME` records the intended domain,
   but custom-workflow deployments require this setting: the file alone does
   not configure it.

3. Run **Actions > Build and deploy Jekyll > Run workflow** on `main`. A push may
   have already started a run before Pages was enabled; re-run after setup if
   necessary. Approve the `github-pages` environment deployment if prompted.

On pushes to `main`, the workflow installs locked dependencies, builds Jekyll,
runs the checker, uploads `_site`, and deploys with GitHub's Pages actions.
Pull requests build and validate but **never deploy**. No personal access token
or repository secret is required. The deploy job alone has Pages write and
OIDC permissions. `Gemfile.lock` is committed for reproducible builds on Windows
and Linux. Future dependency updates should regenerate the lockfile and run
the build and checker before merging.

## Connect allaboutfoxes.com

First verify domain ownership in **your GitHub account Settings > Pages > Add a
domain**, following GitHub's TXT record instructions. Keep that verification
record. Then set the custom domain on the repository as described above.

At your domain registrar or DNS provider, configure:

| Type | Host | Value |
| --- | --- | --- |
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |
| CNAME | `www` | `madskristensen.github.io` |

Remove conflicting parking/forwarding records for `@` and `www`, but preserve
unrelated mail and verification records. Do not use wildcard records. The `www`
CNAME points to the **account hostname**, not a URL or repository path. GitHub
redirects `allaboutfoxes.com` to the configured primary domain,
`www.allaboutfoxes.com`. Keep the apex A records so that redirect works.

IPv6 is optional; if existing AAAA records point elsewhere, remove those or
replace them with all four GitHub Pages IPv6 addresses from the official guide.
Do not leave conflicting AAAA records behind.

Allow up to 24 hours for DNS and certificate provisioning. In repository
**Settings > Pages**, wait for the DNS check to succeed and enable **Enforce
HTTPS** when available. Confirm both https://allaboutfoxes.com and
https://www.allaboutfoxes.com work. DNS changes cannot be made from this project.

Official reference: [Managing a custom domain for GitHub Pages](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site).

### Preview on the GitHub URL before using the domain

The default configuration deliberately targets the purchased domain. To publish
at `https://madskristensen.github.io/allaboutfoxes/` instead, set `url` to
`https://madskristensen.github.io` and `baseurl` to `/allaboutfoxes` in
`_config.yml`, remove `CNAME`, and leave the repository custom-domain setting
empty. Update the domain-specific assertions in the checker for that alternate
configuration. Restore the domain configuration when switching to the real URL.

## Design notes

The site uses semantic HTML, a skip link, keyboard focus styles, descriptive
image text, system fonts, and responsive layouts. The question box uses native
`details`/`summary`. SEO titles, descriptions, canonical URLs, a sitemap, robots
file, favicon, and a custom 404 are included. No analytics or data collection is
configured. Keep the site simple as Wesley adds his own discoveries.