# All About Foxes

## Purpose and design

- This is Wesley's kid-friendly fox field guide, built with Jekyll and hosted on GitHub Pages.
- Preserve the existing homepage and its woodland field-guide aesthetic. Grow the site through section landing pages and articles rather than adding all content to the homepage.
- Match the existing colors, typography, spacing, and illustration style when adding layouts or components.
- Prefer static HTML, CSS, local images, system fonts, and native HTML interactions. Add JavaScript or external services only for a concrete need; do not introduce tracking by default.
- Maintain semantic headings, keyboard navigation, visible focus indicators, responsive layouts, and reduced-motion support.

## Pages and navigation

- Write articles in Markdown and reuse the shared layouts in `_layouts` and includes in `_includes`.
- Use a section's `index.md` for its landing page and nested directories for subpages, for example `/foxes/` and `/foxes/red-fox/`.
- The default `page` layout supplies the page title as an `h1`; start article headings at `##`.
- Set a meaningful `title` and `description` in front matter. For subpages, list ancestors in `breadcrumbs`, outermost first; the layout adds Home and the current page.
- Use `_templates/page.md` as the page starter. Keep templates out of published output.
- Use the Red Fox article as the working example for species profiles: `layout: fox`, `section: /foxes/`, scientific name, credited photograph, quick facts, and source links. The `section` layout lists published profiles automatically, sorted by `nav_order`.
- Manage header links centrally in `_data/navigation.yml`; it supports nested `children`. Pages do not automatically appear in navigation.
- As content grows, prefer a small number of top-level header sections, with article links on section landing pages. Do not put the entire encyclopedia in the header.
- Only link to pages that exist. Do not publish empty placeholder articles.
- Use `relative_url` for internal links and image paths so they work at both the domain root and a repository subpath. Use `absolute_url` where an absolute URL is required.

## Content and images

- Write clear, engaging explanations for children without sacrificing factual accuracy. Cite reliable wildlife sources.
- Use original images or images licensed for publication, with appropriate credits and descriptive alternative text. Decorative images should have empty alt text.
- Store images locally under `assets/images` and size them appropriately for the web. Prefer captions for educational context and credits.
- Keep `jekyll-seo-tag` as the single source of social metadata. Pages inherit a 1200-by-630 PNG sharing card; profile `image` objects supply `path`, actual `width` and `height`, and descriptive `alt` text for both displayed photos and sharing previews. Do not invent social handles or add duplicate Open Graph/Twitter tags.
- Do not publish private information about Wesley or other children.
- Keep wildlife guidance safe: observe from a distance and do not present wild foxes as pets.

## Domain and deployment

- The canonical production URL is `https://www.allaboutfoxes.com`; the bare domain redirects to `www`.
- Keep `_config.yml`, `CNAME`, canonical metadata, sitemap URLs, tests, and documentation consistent with that domain. Production `baseurl` is empty.
- GitHub Pages uses the custom domain configured in repository settings; `CNAME` alone does not configure an Actions deployment.
- Production deploys from `main` through `.github/workflows/pages.yml`. Pull requests build and validate but must not deploy.
- Do not add personal access tokens or other secrets. Keep deployment permissions scoped to the deploy job.
- Commit dependency lockfile updates when changing dependencies, preserving support for Windows development and Linux CI.

## Local development and validation

- Use Ruby 3.4 and Bundler. On Windows, use RubyInstaller with Devkit and Windows-style filesystem paths.
- `run.cmd` starts the preview at `http://localhost:4002`, with live reload on port `35731`. Preserve these ports to avoid conflicts with other local sites.
- Restart Jekyll after changing `_config.yml`; ordinary content changes rebuild automatically.
- Before publishing code or content changes, run `bundle exec jekyll build --trace` with `JEKYLL_ENV=production`, then `bundle exec ruby scripts\check_site.rb` on Windows (`scripts/check_site.rb` on Linux).
- The checker covers generated metadata, headings, images, local links and fragments, source-file exclusions, page templates, documented YAML examples, and the `www` domain. It also builds temporary pages under `/preview` to test Markdown, breadcrumbs, recursive navigation, subpath hosting, automatic profile cards, and draft exclusion.
- Update relevant checks when intentionally changing routing, layouts, domain behavior, or output structure. Do not weaken checks merely to make a build pass.
- Preserve existing line endings and formatting. YAML requires spaces, not tabs; verify front matter and YAML examples after editor formatting. Flow-style YAML can keep Markdown examples indentation-independent.
- Do not commit `_site`, Jekyll caches, installed dependencies, or `.vs` state. Keep source-only scripts, templates, documentation, and the Windows launcher out of the deployed site.
- Update `README.md` when changing authoring, navigation, local development, or publishing conventions.