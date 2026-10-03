defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpAssumptioTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.HighPriest.HpAssumptio
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 36_201
  @ally_id 36_202
  @mob_id 36_203
  @friend_mob_id 36_204

  setup :setup_ets_tables

  setup do
    caster = player(@caster_id)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = UnitRegistry.register_player(player(@ally_id), self())

    %{caster: caster}
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:hp_assumptio)
    definition
  end

  @tag game_mode: :renewal
  test "renewal definition: 0.8-2.4 s cast, 0.2-0.6 s fixed, 0.5 s delay" do
    definition = definition()

    assert definition.id == 361
    assert definition.target_type == :target_ally
    assert definition.range == 9
    assert definition.sp_cost == [20, 30, 40, 50, 60]
    assert definition.cast_time == [800, 1_200, 1_600, 2_000, 2_400]
    assert definition.fixed_cast_time == [200, 300, 400, 500, 600]
    assert definition.after_cast_delay == [500, 500, 500, 500, 500]
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal definition: 1-3 s cast, no fixed time, 1.1-1.5 s delay" do
    definition = definition()

    assert definition.cast_time == [1_000, 1_500, 2_000, 2_500, 3_000]
    assert definition.fixed_cast_time in [[], [0, 0, 0, 0, 0]]
    assert definition.after_cast_delay == [1_100, 1_200, 1_300, 1_400, 1_500]
  end

  test "a player cast on an ally applies Assumptio for 20 s per level", %{caster: caster} do
    assert {:ok, ^caster} = HpAssumptio.cast(caster, {:unit, @ally_id}, 3, definition())

    entry = StatusStorage.get_status(:player, @ally_id, :sc_assumptio)
    assert entry.val1 == 3
    assert entry.expires_at - entry.started_at == 60_000
  end

  test "blessing another player asks that player's session to refresh its stats",
       %{caster: caster} do
    :ok = Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{@ally_id}")

    assert {:ok, ^caster} = HpAssumptio.cast(caster, {:unit, @ally_id}, 1, definition())

    assert_receive :recalculate_stats
  end

  test "a player may target themself", %{caster: caster} do
    assert {:ok, ^caster} = HpAssumptio.cast(caster, :self, 1, definition())
    assert StatusStorage.has_status?(:player, @caster_id, :sc_assumptio)
  end

  test "a player cannot target a mob", %{caster: caster} do
    register_mob(@mob_id, [])

    assert {:error, :invalid_target} =
             HpAssumptio.validate(caster, {:unit, @mob_id}, 5, definition())
  end

  test "a mob caster passes validation with the executor's adapted target" do
    mob = register_mob(@mob_id, [])

    assert :ok = HpAssumptio.validate(mob, {:unit, @friend_mob_id}, 5, definition())
  end

  test "a mob row lands Assumptio on a boss friend" do
    mob = register_mob(@mob_id, [])
    register_mob(@friend_mob_id, [:boss])

    assert {:ok, ^mob} =
             HpAssumptio.mob_cast(mob, {:unit, :mob, @friend_mob_id}, 5, definition(), %{})

    assert StatusStorage.get_status(:mob, @friend_mob_id, :sc_assumptio).val1 == 5
  end

  defp register_mob(id, modes) do
    mob_data = %MobDefinition{
      id: 1086,
      aegis_name: "GOLDEN_BUG",
      name: "Golden Thief Bug",
      level: 65,
      hp: 222_750,
      sp: 0,
      stats: %{str: 65, agi: 75, vit: 35, int: 45, dex: 85, luk: 150},
      atk: 870,
      matk: 0,
      def: 60,
      mdef: 45,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 100,
      attack_delay: 768,
      attack_motion: 768,
      client_attack_motion: 768,
      damage_motion: 480,
      element: {:fire, 2},
      race: :insect,
      size: :large,
      modes: modes
    }

    spawn_ref = %MobSpawn{
      mob: 1086,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(id, mob_data, spawn_ref, "prontera", 100, 100)
    UnitRegistry.register_unit(:mob, id, MobState, state, self())
    state
  end

  defp player(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "HP #{id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "F",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 99,
      job_level: 50,
      class: 4009
    })
  end
end
