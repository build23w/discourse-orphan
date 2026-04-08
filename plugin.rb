# name: discourse-orphan
# about: Orphan post fix
# version: 0.4
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

      html_output << "<li><a href='/sitemap_1.xml'>sitemap.xml</a></li></ul></div></noscript>"
      html_output
    end
  end

  register_html_builder("server:before-head-close") do |controller|
    path = controller&.request&.path.to_s
    next if path.empty?

    is_category_or_tag_page = path.match?(%r{\A/(c|tag|tags)(/|$)})
    next unless is_category_or_tag_page

    <<~HTML
      <meta name="googlebot" content="noindex, follow">
      <meta name="robots" content="noindex, follow">
    HTML
  end
end

