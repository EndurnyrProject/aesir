defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgHermodeTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Clown.CgHermode
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Proximity
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  Mimic.copy(Proximity)
  Mimic.copy(Relations)

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 30, 30)})
    manager = start_supervised!({Manager, name: nil, schedule_tick: fn _, _ -> :ok end})
    Process.put({Manager, :server}, manager)
    caster = %{player(17, 10, 10) | party_id: 2, guild_id: 10}
    register(caster)
    %{caster: caster}
  end

  @tag game_mode: :renewal
  test "renewal includes nearby party and guild allies, clears their buffs but keeps the caster's",
       %{caster: caster} do
    stub(Relations, :friendly?, fn a, b -> a == 10 and b in [10, 20] end)

    for p <- [
          %{player(18, 13, 13) | party_id: 2},
          %{player(19, 10, 13) | guild_id: 10},
          %{player(20, 13, 10) | guild_id: 20},
          player(21, 11, 10),
          %{player(22, 14, 10) | party_id: 2}
        ] do
      register(p)
    end

    for id <- [17, 18] do
      assert :ok = Interpreter.apply_status(:player, id, :sc_blessing, caster_id: 17, val1: 10)
    end

    assert {:ok, _} = CgHermode.cast(caster, :self, 3, CgHermode.definition())
    for id <- [17, 18, 19, 20], do: assert(StatusStorage.has_status?(:player, id, :sc_hermode))
    for id <- [21, 22], do: refute(StatusStorage.has_status?(:player, id, :sc_hermode))
    assert StatusStorage.has_status?(:player, 17, :sc_blessing)
    refute StatusStorage.has_status?(:player, 18, :sc_blessing)
    assert Storage.get_groups_by_caster(:player, 17) == []
  end

  @tag game_mode: :pre_renewal
  test "classic cast begins only beside a warp portal's area", %{caster: caster} do
    definition = CgHermode.definition()
    stub(Warps, :for_map, fn "prontera" -> {:ok, [warp(1, 1)]} end)
    assert {:error, :no_npc_nearby} = CgHermode.begin_attempt(caster, :self, 3, definition)

    stub(Warps, :for_map, fn "prontera" -> {:ok, [warp(2, 0)]} end)
    assert {:ok, ^caster} = CgHermode.begin_attempt(caster, :self, 3, definition)
  end

  @tag game_mode: :pre_renewal
  test "a script NPC's touch area does not let the cast begin", %{caster: caster} do
    stub(Warps, :for_map, fn "prontera" -> :error end)
    stub(Proximity, :touch_area_within?, fn _map, _x, _y, _range -> true end)

    assert {:error, :no_npc_nearby} =
             CgHermode.begin_attempt(caster, :self, 3, CgHermode.definition())
  end

  @tag game_mode: :pre_renewal
  test "classic cast creates a seven-by-seven rooted field with five-second upkeep", %{
    caster: caster
  } do
    assert {:ok, _} = CgHermode.cast(caster, :self, 3, CgHermode.definition())
    [group] = Storage.get_groups_by_caster(:player, 17)
    assert length(group.cells) == 49
    assert group.state.performance.layout_radius == 3

    assert %{state: %{root: :always, upkeep: 5, upkeep_sp: 1}} =
             StatusStorage.get_status(:player, 17, :sc_dancing)

    refute Interpreter.can_move?(:player, 17)
  end

  defp warp(xs, ys) do
    %Warp{
      id: "test_warp",
      map: "prontera",
      x: 13,
      y: 10,
      xs: xs,
      ys: ys,
      to_map: "geffen",
      to_x: 100,
      to_y: 100
    }
  end

  defp player(id, x, y) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Hermode #{id}",
      class: 4020,
      base_level: 80,
      job_level: 50,
      sex: "M",
      last_map: "prontera",
      last_x: x,
      last_y: y,
      str: 10,
      agi: 10,
      vit: 0,
      int: 10,
      dex: 10,
      luk: 0
    })
  end

  defp register(player) do
    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_player(player.character_id, player.x, player.y, player.map_name)
  end
end
