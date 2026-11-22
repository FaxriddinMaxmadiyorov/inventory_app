module ApplicationHelper
  IMAGE_LINK = /\.(jpe?g|png|gif|webp|svg)(\?.*)?\z/i
  PDF_LINK = /\.pdf(\?.*)?\z/i
  MARKDOWN_TAGS = %w[p br strong em del a ul ol li blockquote pre code h1 h2 h3 h4 h5 h6 hr img table thead tbody tr th td].freeze
  MARKDOWN_ATTRIBUTES = %w[href src alt title rel target].freeze

  def markdown(text)
    return "".html_safe if text.blank?

    @markdown ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true, safe_links_only: true,
                                  link_attributes: { rel: "nofollow noopener", target: "_blank" }),
      autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true, no_intra_emphasis: true
    )
    content_tag(:div, sanitize(@markdown.render(text), tags: MARKDOWN_TAGS, attributes: MARKDOWN_ATTRIBUTES), class: "markdown")
  end

  # Sortable table header: Ransack's sort_link with the table styling.
  def table_sort_link(search, attribute, label, default_order: :asc)
    sort_link(search, attribute, label, default_order: default_order, class: "text-reset text-decoration-none text-nowrap")
  end

  # Keeps the current sorting when a filter form is submitted.
  def keep_sort_field(key = :q)
    sort = ransack_params(key)["s"]
    hidden_field_tag("#{key}[s]", sort, id: nil) if sort.is_a?(String) && sort.present?
  end

  def format_number(value)
    return "" if value.nil?

    number_with_delimiter(value.to_d.round(4).to_s("F").sub(/\.0+\z/, "").sub(/(\.\d*[1-9])0+\z/, '\1'), delimiter: " ")
  end

  # Value of a custom field for tables and read-only pages.
  def field_value(item, field, truncate_at: 60)
    value = item[field.column]

    case field.kind
    when "bool"
      content_tag(:i, "", class: value ? "bi bi-check-square" : "bi bi-square", title: value ? t("common.checked") : t("common.unchecked"))
    when "number"
      format_number(value)
    when "link"
      value.present? ? link_to(truncate(value, length: 40), value, target: "_blank", rel: "nofollow noopener") : ""
    else
      truncate_at ? truncate(value.to_s, length: truncate_at) : value.to_s
    end
  end

  def link_preview(url)
    return if url.blank?

    if url.match?(IMAGE_LINK)
      link_to(image_tag(url, class: "img-fluid rounded border preview-image", alt: "", loading: "lazy"), url, target: "_blank", rel: "nofollow noopener")
    elsif url.match?(PDF_LINK)
      content_tag(:iframe, "", src: url, class: "preview-pdf rounded border w-100", loading: "lazy", title: "PDF")
    end
  end

  def tag_cloud_size(tag, tags)
    max = tags.map { |t| t.uses_count.to_i }.max.to_f
    (0.9 + 1.1 * (tag.uses_count.to_i / max)).round(2)
  end

  def field_kind_icon(kind)
    { "string" => "bi-fonts", "text" => "bi-text-paragraph", "number" => "bi-123",
      "link" => "bi-link-45deg", "bool" => "bi-check2-square", "select" => "bi-menu-button-wide" }[kind]
  end

  def js_translations
    t("js").to_json
  end

  def cloudinary_configured?
    ENV["CLOUDINARY_CLOUD_NAME"].present? && ENV["CLOUDINARY_UPLOAD_PRESET"].present?
  end
end
