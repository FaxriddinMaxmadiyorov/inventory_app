# Full-text search on the search_text column, backed by a GIN index on the same
# expression (see the migrations). Punctuation is turned into spaces first, so an
# ID like "PC-001" is found by "pc", "001" or "PC-001".
module Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, lambda { |query|
      tsquery = Searchable.tsquery(query)
      next none if tsquery.nil?

      where("#{Searchable.vector("#{table_name}.search_text")} @@ to_tsquery('simple', ?)", tsquery)
    }
  end

  def self.vector(column)
    "to_tsvector('simple', regexp_replace(coalesce(#{column}, ''), '[^[:alnum:]]+', ' ', 'g'))"
  end

  # Turns free user input into a prefix query: "fax mach" -> "fax:* & mach:*"
  def self.tsquery(query)
    words = query.to_s.scan(/[\p{L}\p{N}]+/).first(10)
    return nil if words.empty?

    words.map { |word| "#{word}:*" }.join(" & ")
  end
end
