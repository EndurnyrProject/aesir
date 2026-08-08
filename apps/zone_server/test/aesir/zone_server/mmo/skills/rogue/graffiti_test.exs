defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.GraffitiTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgFlaggraffiti
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgGraffiti
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :setup_ets_tables
  setup :verify_on_exit!

  @caster_id 1_000
  @map_name "prontera"
  @center {150, 150}

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    on_exit(fn -> Process.delete({Manager, :server}) end)

    :ets.insert(EtsTable.table_for(:map_cache), {@map_name, MapData.new(@map_name, 300, 300)})
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    :ok
  end

  test "Scribble declares its Red Gemstone catalyst and places a 180-second unit" do
    assert {:ok, definition} = Catalog.by_id(220)
    assert definition.name == :rg_graffiti
    assert definition.target_type == :ground
    assert definition.max_level == 1
    assert definition.item_cost == [%{id: 716, amount: 1}]
    assert {:ok, RgGraffiti} = Catalog.ground_module_for(:rg_graffiti)

    assert {:ok, group} = Unit.place(caster(), :rg_graffiti, 1, @center)
    assert group.skill_name == :rg_graffiti
    assert group.expires_at - group.created_at == 180_000
    assert [stored] = Storage.all()
    assert stored.group_id == group.group_id
  end

  test "Piece places a ground unit" do
    assert {:ok, definition} = Catalog.by_id(221)
    assert definition.name == :rg_flaggraffiti
    assert definition.target_type == :ground
    assert definition.max_level == 5
    assert {:ok, RgFlaggraffiti} = Catalog.ground_module_for(:rg_flaggraffiti)

    assert {:ok, group} = Unit.place(caster(), :rg_flaggraffiti, 5, @center)
    assert group.skill_name == :rg_flaggraffiti
    assert [stored] = Storage.all()
    assert stored.group_id == group.group_id
  end

  test "Scribble refuses a second unit anywhere on the same map" do
    assert {:ok, _group} = Unit.place(caster(), :rg_graffiti, 1, @center)
    assert {:ok, definition} = Catalog.by_id(220)

    assert {:error, :graffiti_already_placed} =
             RgGraffiti.validate(caster(), {:ground, 151, 151}, 1, definition)

    assert [_group] = Storage.all()
  end

  defp caster do
    %PlayerState{character_id: @caster_id, map_name: @map_name, x: 150, y: 150}
  end
end
