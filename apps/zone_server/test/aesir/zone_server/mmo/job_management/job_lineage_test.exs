defmodule Aesir.ZoneServer.Mmo.JobManagement.JobLineageTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage

  test "covers both job catalogs with an acyclic lineage" do
    assert :ok = JobLineage.validate!()
  end

  test "base_job collapses transcendence and baby variants to the canonical job" do
    assert JobLineage.base_job(:hunter) == :hunter
    assert JobLineage.base_job(:sniper) == :hunter
    assert JobLineage.base_job(:baby_hunter) == :hunter
    assert JobLineage.base_job(:swordman_high) == :swordman
    assert JobLineage.base_job(:lord_knight) == :knight
    assert JobLineage.base_job(:novice_high) == :novice
    assert JobLineage.base_job(:super_novice) == :super_novice
    assert JobLineage.base_job(:knight2) == :knight
    assert JobLineage.base_job(:novice) == :novice
  end

  test "base_class resolves the first-job lineage root" do
    assert JobLineage.base_class(:hunter) == :archer
    assert JobLineage.base_class(:sniper) == :archer
    assert JobLineage.base_class(:knight) == :swordman
    assert JobLineage.base_class(:archer) == :archer
    assert JobLineage.base_class(:novice) == :novice
    assert JobLineage.base_class(:super_novice) == :novice
    assert JobLineage.base_class(:high_priest) == :acolyte
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
