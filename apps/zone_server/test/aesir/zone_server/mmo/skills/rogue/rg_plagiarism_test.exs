defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgPlagiarismTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgPlagiarism

  setup do
    Catalog.reload()
  end

  test "is discovered as a passive" do
    assert {:ok, RgPlagiarism} = Catalog.passive_module_for(:rg_plagiarism)
  end
end
