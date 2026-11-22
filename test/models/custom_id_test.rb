require "test_helper"

class CustomIdTest < ActiveSupport::TestCase
  def build(*parts)
    CustomId.new(parts.map { |kind, format| { "kind" => kind, "format" => format } })
  end

  test "builds the ID from the example in the task" do
    id = build(["fixed", "📚-"], ["rand20", "X5_"], ["sequence", "D3_"], ["datetime", "yyyy"])
    value = id.generate(sequence: 13, time: Time.utc(2025, 3, 4))

    assert_match(/\A📚-[0-9A-F]{5}_013_2025\z/, value)
    assert id.valid?(value)
  end

  test "number formats" do
    assert_equal "13", build(["sequence", "D"]).generate(sequence: 13)
    assert_equal "0000013", build(["sequence", "D7"]).generate(sequence: 13)
    assert_equal "PART-0000001", build(["fixed", "PART-"], ["sequence", "D7"]).generate(sequence: 1)
    assert_equal "00ff", build(["sequence", "x4"]).generate(sequence: 255)
    assert_match(/\A\d{6}\z/, build(["rand6", ""]).generate(sequence: 1))
    assert_match(/\A\d{9}\z/, build(["rand9", ""]).generate(sequence: 1))
    assert_match(/\A[0-9A-F]{8}-\z/, build(["rand32", "X8-"]).generate(sequence: 1))
  end

  test "guid and date formats" do
    assert_match(/\A[0-9a-f]{32}\z/, build(["guid", "N"]).generate(sequence: 1))
    assert_match(/\A[0-9a-f-]{36}\z/, build(["guid", ""]).generate(sequence: 1))
    time = Time.utc(2026, 11, 21, 9, 5, 7)
    assert_equal "2026-11-21 09:05:07 Sat Nov 26", build(["datetime", "yyyy-MM-dd HH:mm:ss ddd MMM yy"]).generate(sequence: 1, time: time)
  end

  test "validates values against the format" do
    id = build(["fixed", "COMP-"], ["datetime", "yyyy"], ["fixed", "-"], ["rand32", "X8"], ["fixed", "-"], ["sequence", "D3"])

    assert id.valid?("COMP-2025-E74FA329-001")
    assert id.valid?("COMP-2025-E74FA329-1234")
    assert_not id.valid?("COMP-2025-E74FA329-1")
    assert_not id.valid?("comp-2025-E74FA329-001")
    assert_not id.valid?("COMP-2025-E74FA329-001 ")
    assert id.valid?(id.example)
  end

  test "every generated value passes its own validation" do
    id = build(*CustomId::KINDS.map { |kind| [kind, kind == "fixed" ? "a.b*c" : ""] })
    20.times { |n| assert id.valid?(id.generate(sequence: n)) }
  end

  test "an empty format accepts anything and generates the sequence number" do
    id = build
    assert_equal "5", id.generate(sequence: 5)
    assert id.valid?("whatever")
  end
end
