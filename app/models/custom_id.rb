# Builds and validates custom inventory numbers from a list of elements.
#
# Each element is a [kind, format] pair:
#   fixed     - the format is the text itself (any Unicode)
#   rand20, rand32, rand6, rand9, sequence
#             - "D" decimal, "D6" decimal padded with zeros to 6 digits,
#               "X" hex, "X5" hex padded to 5 digits ("x" for lower case);
#               anything after that is appended as is: "X5_" -> "A7E3A_"
#   guid      - "D" with dashes, "N" without; the rest is appended as is
#   datetime  - yyyy yy MM MMM dd ddd HH mm ss, other characters are kept
class CustomId
  KINDS = %w[fixed rand20 rand32 rand6 rand9 guid datetime sequence].freeze
  MAX_ELEMENTS = 12

  RANDOM_LIMIT = { "rand20" => 2**20, "rand32" => 2**32, "rand6" => 10**6, "rand9" => 10**9 }.freeze
  DEFAULT_FORMAT = {
    "fixed" => "", "rand20" => "X5", "rand32" => "X8", "rand6" => "D6", "rand9" => "D9",
    "guid" => "D", "datetime" => "yyyy", "sequence" => "D"
  }.freeze

  NUMBER_FORMAT = /\A([DXx])(\d{0,2})(.*)\z/m
  GUID_FORMAT = /\A([DN]?)(.*)\z/m
  DATE_TOKEN = /yyyy|yy|MMM|MM|ddd|dd|HH|mm|ss/
  DATE_TOKENS = {
    "yyyy" => ["%Y", '\d{4}'], "yy" => ["%y", '\d{2}'],
    "MMM" => ["%b", "[A-Za-z]{3}"], "MM" => ["%m", '\d{2}'],
    "ddd" => ["%a", "[A-Za-z]{3}"], "dd" => ["%d", '\d{2}'],
    "HH" => ["%H", '\d{2}'], "mm" => ["%M", '\d{2}'], "ss" => ["%S", '\d{2}']
  }.freeze

  attr_reader :parts

  # elements: IdElement records or hashes with kind/format keys
  def initialize(elements)
    @parts = elements.filter_map do |element|
      kind, format = element.respond_to?(:kind) ? [element.kind, element.format] : [element["kind"] || element[:kind], element["format"] || element[:format]]
      next unless KINDS.include?(kind)

      format = format.to_s
      format = DEFAULT_FORMAT[kind] if format.empty? && kind != "fixed"
      [kind, format]
    end
  end

  def empty?
    parts.empty?
  end

  def generate(sequence:, time: Time.current)
    return sequence.to_s if empty?

    parts.map do |kind, format|
      case kind
      when "fixed" then format
      when "guid" then guid(format)
      when "datetime" then format.gsub(DATE_TOKEN) { |token| time.strftime(DATE_TOKENS[token][0]) }
      when "sequence" then number(sequence, format)
      else number(SecureRandom.random_number(RANDOM_LIMIT[kind]), format)
      end
    end.join
  end

  def example
    generate(sequence: 13)
  end

  # nil when the inventory has no format: any ID is accepted then.
  def regexp
    return nil if empty?

    source = parts.map do |kind, format|
      case kind
      when "fixed" then Regexp.escape(format)
      when "guid" then guid_pattern(format)
      when "datetime" then date_pattern(format)
      else number_pattern(format)
      end
    end.join
    Regexp.new("\\A#{source}\\z")
  end

  def valid?(value)
    pattern = regexp
    pattern.nil? || pattern.match?(value.to_s)
  end

  private

  def number(value, format)
    match = NUMBER_FORMAT.match(format)
    return "#{value}#{format}" unless match

    digits = match[1] == "D" ? value.to_s : value.to_s(16)
    digits = digits.upcase if match[1] == "X"
    digits.rjust(match[2].to_i, "0") + match[3]
  end

  def number_pattern(format)
    match = NUMBER_FORMAT.match(format)
    return "\\d+#{Regexp.escape(format)}" unless match

    chars = { "D" => '\d', "X" => "[0-9A-F]", "x" => "[0-9a-f]" }[match[1]]
    width = match[2].to_i
    "#{chars}#{width.positive? ? "{#{width},}" : '+'}#{Regexp.escape(match[3])}"
  end

  def guid(format)
    match = GUID_FORMAT.match(format)
    value = SecureRandom.uuid
    value = value.delete("-") if match[1] == "N"
    value + match[2]
  end

  def guid_pattern(format)
    match = GUID_FORMAT.match(format)
    hex = "[0-9a-f]"
    core = match[1] == "N" ? "#{hex}{32}" : "#{hex}{8}-#{hex}{4}-#{hex}{4}-#{hex}{4}-#{hex}{12}"
    core + Regexp.escape(match[2])
  end

  def date_pattern(format)
    pattern = +""
    rest = format
    while (match = DATE_TOKEN.match(rest))
      pattern << Regexp.escape(match.pre_match) << DATE_TOKENS[match[0]][1]
      rest = match.post_match
    end
    pattern << Regexp.escape(rest)
  end
end
