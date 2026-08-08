defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgCleanerTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgCleaner
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :setup_ets_tables
  setup :verify_on_exit!

  @map_name "prontera"
  @target {150, 150}

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    on_exit(fn -> Process.delete({Manager, :server}) end)

    :ets.insert(EtsTable.table_for(:map_cache), {@map_name, MapData.new(@map_name, 300, 300)})
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    :ok
  end

  test "Remover clears nearby Scribble and Piece units without persisting" do
    assert {:ok, definition} = Catalog.by_id(222)
    assert definition.name == :rg_cleaner
    assert definition.display_name == "Remover"
    assert definition.max_level == 1
    assert definition.target_type == :ground
    assert {:ok, RgCleaner} = Catalog.active_module_for(:rg_cleaner)

    assert {:ok, scribble} = Unit.place(caster(), :rg_graffiti, 1, {155, 155})
    assert {:ok, piece} = Unit.place(caster(), :rg_flaggraffiti, 5, {145, 145})
    assert {:ok, outside} = Unit.place(caster(), :rg_flaggraffiti, 5, {156, 150})

    {x, y} = @target
    assert {:ok, _caster} = RgCleaner.cast(caster(), {:ground, x, y}, 1, definition)

    assert :error = Unit.fetch(scribble.group_id)
    assert :error = Unit.fetch(piece.group_id)
    assert {:ok, ^outside} = Unit.fetch(outside.group_id)
    assert [^outside] = Storage.all()
  end

  defp caster do
    %PlayerState{character_id: 1_000, map_name: @map_name, x: 150, y: 150}
  end
end
