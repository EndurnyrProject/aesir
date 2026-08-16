defmodule Aesir.ZoneServer.Mmo.Skills.Guild.DefinitionsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  @expected [
    {10_000, :gd_approval, 1},
    {10_001, :gd_kafracontract, 1},
    {10_002, :gd_guardresearch, 1},
    {10_003, :gd_guardup, 3},
    {10_004, :gd_extension, 10},
    {10_006, :gd_leadership, 5},
    {10_007, :gd_glorywounds, 5},
    {10_008, :gd_soulcold, 5},
    {10_009, :gd_hawkeyes, 5},
    {10_014, :gd_development, 1},
    {10_016, :gd_guild_storage, 5},
    {10_017, :gd_chargeshout_flag, 1},
    {10_018, :gd_chargeshout_beating, 1}
  ]

  test "every passive guild skill resolves through the catalog with the tree max level" do
    for {id, name, max_level} <- @expected do
      assert {:ok, definition} = Catalog.by_id(id),
             "expected catalog to resolve guild skill #{id}"

      assert definition.name == name
      assert definition.max_level == max_level
      assert definition.target_type == :passive
    end
  end

  test "passive guild skills expose no active cast module" do
    for {id, _name, _max_level} <- @expected do
      assert Catalog.active_module_for(id) == :error
    end
  end

  test "GLORYGUILD has no catalog module - unlearnable in the renewal tree" do
    assert Catalog.by_id(10_005) == :error
  end
end
