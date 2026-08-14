# name: discourse-orphan
# about: SEO for a large, geo-structured forum — indexes category hubs that have real content while noindexing thin ones, noindexes paginated /latest duplicates and tag listings, rescues least-recently-bumped topics with crawler-visible links, and emits the og:locale meta core omits
# version: 0.8
# authors: build23w

after_initialize do
  module ::DiscourseOrphan
    # One rule shared by the X-Robots-Tag header and the meta-tag paths: Google
    # honors the MOST restrictive directive across the two, so they must agree.
    def self.listing_noindex?(path)
      return true if path =~ %r{\A/(tag|tags)(/|$)}

      if path =~ %r{\A/c(/|$)}
        # Category paths look like /c/slug/5, /c/parent/child/12, /c/slug/5/l/latest.
        # The category id is the last number in the path; anything unresolvable
        # stays noindexed (fail closed).
        id = path.scan(/\d+/).last&.to_i
        return true if id.nil? || id <= 0
        cat = Category.find_by(id: id)
        return true if cat.nil?

        # Judge the SUBTREE, not the category's own topic count: geo hubs like
        # /c/canada own ~40 topics directly but hold thousands across children,
        # and they are exactly the pages search growth depends on.
        total = Discourse.cache.fetch("orphan-subtree-#{id}", expires_in: 5.minutes) do
          ids = [cat.id] + Category.subcategory_ids(cat.id)
          Category.where(id: ids).sum(:topic_count)
        end
        return total < SiteSetting.orphan_index_min_topics
      end

      false
    end

    # /latest?page=N is ~960 interchangeable pages sharing one title; the sitemap
    # already hands Google every topic URL directly. Bare /latest stays indexable.
    def self.paginated_listing?(request)
      request.path == "/latest" && request.params[:page].present?
    end
  end

  # Orphan rescue: crawler view only. The old version injected 30 ORDER BY
  # RANDOM() links into a <noscript> block on the HUMAN app shell — which Google
  # never fetches (it gets the crawler view) — so it taxed every page load while
  # rescuing nothing. Least-recently-bumped topics are the actual orphans, and
  # that ordering rides the bumped_at index.
  register_html_builder("server:before-body-close-crawler") do |_attrs|
    topics = Discourse.cache.fetch("orphan-rescue-links", expires_in: 30.minutes) do
      Topic
        .visible
        .where(archetype: Archetype.default)
        .order(bumped_at: :asc)
        .limit(30)
        .pluck(:slug, :id, :title)
    end

    next "" if topics.blank?

    links = topics.map do |slug, id, title|
      "<li><a href='#{Discourse.base_url}/t/#{slug}/#{id}'>#{CGI.escapeHTML(title)}</a></li>"
    end

    signature = SiteSetting.orphan_crawler_signature.to_s.strip
    sig_html = signature.present? ? "<div>#{signature}</div>" : ""

    "<div class='crawler-orphan-rescue'><h4>Deep archive</h4><ul>#{links.join}</ul>#{sig_html}</div>"
  end

  %w[server:before-head-close server:before-head-close-crawler].each do |hook|
    register_html_builder(hook) do |controller|
      request = controller&.request
      next if request.nil?
      path = request.path.to_s
      next if path.empty?

      parts = []

      # Core's crawlable_meta_data never emits og:locale, so scrapers
      # (Facebook/LinkedIn) silently assume en_US. Declare ours.
      og_locale = SiteSetting.orphan_og_locale.to_s.strip
      if og_locale.match?(/\A[a-z]{2,3}_[A-Z]{2}\z/)
        parts << %(<meta property="og:locale" content="#{og_locale}">)
      end

      if ::DiscourseOrphan.listing_noindex?(path) || ::DiscourseOrphan.paginated_listing?(request)
        parts << '<meta name="googlebot" content="noindex, follow">'
        parts << '<meta name="robots" content="noindex, follow">'
      end

      next if parts.empty?

      parts.join("\n")
    end
  end

  ::ApplicationController.class_eval do
    before_action :hrr_set_listing_robots_header

    def hrr_set_listing_robots_header
      return unless request.get?
      if ::DiscourseOrphan.listing_noindex?(request.path) || ::DiscourseOrphan.paginated_listing?(request)
        response.set_header('X-Robots-Tag', 'noindex, follow')
      end
    end
  end
end
