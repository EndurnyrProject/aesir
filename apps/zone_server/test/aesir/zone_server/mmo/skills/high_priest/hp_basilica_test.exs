defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpBasilicaTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.HighPriest.HpBasilica
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 36_301

  setup :setup_ets_tables

  setup do
    caster = player(@caster_id)
    :ok = UnitRegistry.register_player(caster, self())
    %{caster: caster}
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:hp_basilica)
    definition
  end

  describe "renewal" do
    @describetag game_mode: :renewal

    test "definition: 3 s cast + 1 s fixed, 1 s delay, 30 s cooldown, no catalysts" do
      definition = definition()

      assert definition.id == 362
      assert definition.target_type == :self
      assert definition.sp_cost == [40, 50, 60, 70, 80]
      assert definition.cast_time == List.duplicate(3_000, 5)
      assert definition.fixed_cast_time == List.duplicate(1_000, 5)
      assert definition.after_cast_delay == List.duplicate(1_000, 5)
      assert definition.cooldown == List.duplicate(30_000, 5)
      assert definition.duration == [60_000, 90_000, 120_000, 150_000, 180_000]
      assert definition.item_cost == []
    end

    test "casting applies the Basilica buff for the level's duration", %{caster: caster} do
      assert {:ok, ^caster} = HpBasilica.cast(caster, :self, 4, definition())

      entry = StatusStorage.get_status(:player, @caster_id, :sc_basilica_buff)
      assert entry.val1 == 4
      assert entry.expires_at - entry.started_at == 150_000
    end
  end

  describe "pre-renewal" do
    @describetag game_mode: :pre_renewal

    test "definition: 5-9 s cast, 2-6 s delay, no cooldown, four catalysts" do
      definition = definition()

      assert definition.sp_cost == [80, 90, 100, 110, 120]
      assert definition.cast_time == [5_000, 6_000, 7_000, 8_000, 9_000]
      assert definition.after_cast_delay == [2_000, 3_000, 4_000, 5_000, 6_000]
      assert definition.duration == [20_000, 25_000, 30_000, 35_000, 40_000]

      assert definition.item_cost == [
               %{id: 715, amount: 1},
               %{id: 716, amount: 1},
               %{id: 717, amount: 1},
               %{id: 523, amount: 1}
             ]
    end
  end

  test "a mob caster is refused", %{caster: caster} do
    mob = struct(MobState, instance_id: 1)

    assert {:error, :player_only} = HpBasilica.cast(mob, :self, 1, definition())
    refute StatusStorage.has_status?(:player, caster.character_id, :sc_basilica_buff)
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
