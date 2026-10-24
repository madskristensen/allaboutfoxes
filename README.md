# All About Foxes

A small wildlife field guide for curious kids, made for Wesley. Built with
Jekyll and deployed to GitHub Pages at **https://www.allaboutfoxes.com**.

The first edition has just a front page (plus a friendly 404). There are no
empty "coming soon" pages, external fonts, trackers, cookies, JavaScript, or
third-party image requests. The SVG fox illustrations are original site artwork.

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
and source-file exclusions. It also builds temporary parent/child Markdown pages
under a `/preview` base path to exercise recursive navigation and breadcrumbs.
These test pages are never included in the published site.

## Where things live

| Path | Purpose |
| --- | --- |
| `index.html` | The front page: welcome, facts, and Wesley's adventure |
| `_config.yml` | Site title, description, canonical domain, and defaults |
| `_data/navigation.yml` | Header links; supports nested `children` |
| `_layouts/default.html` | Shared head, header, navigation, and footer |
| `_layouts/page.html` | Article layout with title and breadcrumbs |
| `_includes/navigation.html` | Recursive navigation renderer |
| `_templates/page.md` | Copyable page starter; not published by Jekyll |
| `assets/css/style.css` | Responsive design and reduced-motion support |
| `assets/images/` | Original local SVG artwork |
| `.github/workflows/pages.yml` | Build, validate, and deploy |
| `scripts/check_site.rb` | Build-output and page-structure checks |

## Add pages and subpages

Copy `_templates/page.md` to `foxes\index.md` for `/foxes/`. Edit its title,
description, and Markdown, and remove `breadcrumbs` for this top-level page.
No project file or route registration is needed: Jekyll finds the page.

For a subpage, copy the starter to `foxes\red-fox\index.md`. That becomes
`/foxes/red-fox/`. Set the child's front matter to:

```yaml
---
title: Red fox
description: Meet the clever red fox and discover where it lives.
eyebrow: Foxes of the world
breadcrumbs: [{ title: Foxes of the world, url: /foxes/ }]
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