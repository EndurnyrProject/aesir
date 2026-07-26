defmodule Aesir.ZoneServer.Mmo.JobManagement.JobLineageTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage

  test "covers both job catalogs with an acyclic lineage" do
    assert :ok = JobLineage.validate!()
  end

  test "rejects cycles across parent and alias relationships with the cycle path" do
    assert_raise RuntimeError, ~r/:alpha -> :beta -> :gamma -> :alpha/, fn ->
      JobLineage.validate_graph!(
        %{alpha: [:beta], beta: [:gamma]},
        MapSet.new(),
        %{gamma: :alpha},
        [{1, :alpha}, {2, :beta}, {3, :gamma}],
        [{1, :alpha}, {2, :beta}, {3, :gamma}]
      )
    end
  end

  test "rejects a job present only in the database when it is omitted from lineage" do
    assert_raise RuntimeError, ~r/:database_only.*job database.*absent from JobLineage/, fn ->
      JobLineage.validate_graph!(
        %{},
        MapSet.new([:novice]),
        %{},
        [{0, :novice}],
        [{0, :novice}, {99, :database_only}]
      )
    end
  end
end
