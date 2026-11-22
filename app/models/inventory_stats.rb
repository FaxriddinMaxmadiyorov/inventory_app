# Aggregates for the statistics tab. Two queries in total, whatever the number of fields.
class InventoryStats
  NumberRow = Struct.new(:field, :count, :average, :min, :max)
  Flag = Struct.new(:field, :checked)
  Popular = Struct.new(:field, :values)

  attr_reader :inventory, :numbers, :flags, :popular

  def initialize(inventory)
    @inventory = inventory
    fields = inventory.custom_fields
    load_aggregates(fields.select { |f| f.kind == "number" }, fields.select { |f| f.kind == "bool" })
    load_popular(fields.select { |f| %w[string select].include?(f.kind) })
  end

  def items_count
    inventory.items_count
  end

  private

  def load_aggregates(number_fields, bool_fields)
    @numbers = []
    @flags = []
    return if number_fields.empty? && bool_fields.empty?

    # Column names come from CustomField, never from user input.
    expressions = number_fields.flat_map { |f| ["COUNT(#{f.column})", "AVG(#{f.column})", "MIN(#{f.column})", "MAX(#{f.column})"] }
    expressions += bool_fields.map { |f| "COUNT(*) FILTER (WHERE #{f.column})" }
    row = Array(inventory.items.pick(*expressions.map { |e| Arel.sql(e) }))

    @numbers = number_fields.each_with_index.map { |field, i| NumberRow.new(field, *row[i * 4, 4]) }
    offset = number_fields.size * 4
    @flags = bool_fields.each_with_index.map { |field, i| Flag.new(field, row[offset + i]) }
  end

  def load_popular(fields)
    @popular = []
    return if fields.empty?

    queries = fields.map do |field|
      inventory.items.where.not(field.column => nil).group(field.column)
               .order(Arel.sql("COUNT(*) DESC"), field.column).limit(5)
               .select("'#{field.column}' AS field_column, #{field.column} AS value, COUNT(*) AS uses").to_sql
    end
    rows = Item.find_by_sql(queries.map { |sql| "(#{sql})" }.join(" UNION ALL ")).group_by(&:field_column)
    @popular = fields.map { |field| Popular.new(field, (rows[field.column] || []).map { |r| [r.value, r.uses] }) }
  end
end
