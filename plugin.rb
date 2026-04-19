# name: discourse-orphan
# about: Improves Discourse SEO by suppressing noindex on category/tag listing pages, injecting crawlable noscript post links to prevent orphaned content, and providing configurable per-page crawler signatures and backlinks
# version: 0.6
# authors: build23w

after_initialize do
  register_html_builder("server:before-body-close") do |_attrs|
    random_posts = Post
      .includes(:topic)
      .where("posts.deleted_at IS NULL")
      .order("RANDOM()")
      .limit(30)
      .to_a

    if random_posts.blank?
      "<noscript><div>No posts available.</div></noscript>"
    else
      html_output = <<~HTML
        <noscript>
          <div class="wrap">
            <h4 style="margin-top:0;">Latest Posts</h4>
            <ul style="margin: 0; padding-left: 20px;">
      HTML

      random_posts.each do |post|
        topic = post.topic
        topic_slug = topic.try(:slug) || "unknown"
        topic_id = topic.try(:id) || post.topic_id
        post_url = "#{Discourse.base_url}/t/#{topic_slug}/#{topic_id}/#{post.post_number}"
        topic_title = topic.try(:title) || "Post ##{post.id}"

        html_output << "<li><a href='#{post_url}'>#{topic_title}</a></li>"
      end

      html_output << "<li><a href='/sitemap.xml'>sitemap.xml</a></li></ul></div></noscript>"

      signature = SiteSetting.orphan_crawler_signature.to_s.strip
      html_output << "<noscript>#{signature}</noscript>" if signature.present?

      backlink_url  = SiteSetting.orphan_backlink_url.to_s.strip
      backlink_text = SiteSetting.orphan_backlink_text.to_s.strip
      if backlink_url.present?
        label = backlink_text.present? ? backlink_text : backlink_url
        html_output << "<noscript><a href='#{backlink_url}'>#{label}</a></noscript>"
      end

      html_output
    end
  end

  %w[server:before-head-close server:before-head-close-crawler].each do |hook|
    register_html_builder(hook) do |controller|
      path = controller&.request&.path.to_s
      next if path.empty?

      is_listing = path.match?(%r{\A/(c|tag|tags)(/|$)})
      next unless is_listing

      <<~HTML
        <meta name="googlebot" content="noindex, follow">
        <meta name="robots" content="noindex, follow">
      HTML
    end
  end

  ::ApplicationController.class_eval do
    before_action :hrr_set_listing_robots_header

    def hrr_set_listing_robots_header
      return unless request.get?
      if request.path =~ %r{\A/(c|tag|tags)(/|$)}
        response.set_header('X-Robots-Tag', 'noindex, follow')
      end
    end
  end
end