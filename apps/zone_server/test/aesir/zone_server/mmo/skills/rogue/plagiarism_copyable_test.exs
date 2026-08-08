defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.PlagiarismCopyableTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Rogue.PlagiarismCopyable

  test "recognizes skills marked as plagiarism-copyable" do
    assert PlagiarismCopyable.copyable?(5)
    assert PlagiarismCopyable.copyable?(212)
    assert PlagiarismCopyable.copyable?(3_008)
  end

  test "rejects skills not marked as plagiarism-copyable" do
    refute PlagiarismCopyable.copyable?(1)
    refute PlagiarismCopyable.copyable?(225)
    refute PlagiarismCopyable.copyable?(3_009)
  end
end
