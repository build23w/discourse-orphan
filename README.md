# discourse-orphan

A Discourse plugin that fixes common SEO issues out of the box.

## What it does

**Orphan post links** — Injects a `<noscript>` block on every page containing 30 random post links. This ensures crawlers can always discover content even when JavaScript is not executed, preventing posts from becoming orphaned (unreachable by bots).

**Listing page noindex** — Category, tag, and tags listing pages (`/c/`, `/tag/`, `/tags/`) are marked `noindex, follow` via meta tags and the `X-Robots-Tag` response header. This prevents low-value listing pages from consuming crawl budget or competing with real content in search results.

**Crawler signature** — A freeform block of HTML (e.g. a tagline, disclaimer, or brand text) that appears in a `<noscript>` tag on every page. Visible to crawlers and users with JavaScript disabled.

**Crawler backlink** — A configurable anchor tag injected on every page inside `<noscript>`. Useful for linking to a related site, hosting provider, or any page you want to pass link equity to.

## Installation

Add the plugin to your Discourse `app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/your-org/discourse-orphan
```

Rebuild the container:

```
./launcher rebuild app
```

## Settings

All settings are found in **Admin → Settings → Plugins**.

| Setting | Description |
|---|---|
| `orphan_crawler_signature` | HTML or text appended to every page in a `<noscript>` block |
| `orphan_backlink_url` | URL for the sitewide crawler backlink |
| `orphan_backlink_text` | Anchor text for the backlink (defaults to the URL if blank) |

## Version history

- **0.6** — Added crawler signature and backlink settings
- **0.5** — Initial release: orphan post links, listing-page noindex
