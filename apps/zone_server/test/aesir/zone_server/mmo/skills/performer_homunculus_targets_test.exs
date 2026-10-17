defmodule Aesir.ZoneServer.Mmo.Skills.PerformerHomunculusTargetsTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaFrostjoker
  alias Aesir.ZoneServer.Mmo.Skills.Dancer.DcScream
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    Mimic.copy(OnHitEffects)
    :ok
  end

  for {skill, status} <- [{BaFrostjoker, :sc_freeze}, {DcScream, :sc_stun}] do
    test "#{skill} includes enemy homunculi in its delayed area" do
      caster = %MobState{
        instance_id: 1,
        mob_id: 1002,
        mob_data: %{},
        spawn_ref: nil,
        x: 100,
        y: 100,
        map_name: "prontera",
        hp: 100,
        max_hp: 100,
        sp: 0,
        max_sp: 0,
        spawned_at: 0
      }

      target = %HomunculusState{
        id: 3,
        owner_character_id: 2,
        class_id: 6001,
        name: "Lif",
        world_gid: 3,
        map_name: "prontera",
        x: 101,
        y: 100,
        hp: 100,
        max_hp: 100,
        lifecycle: :active
      }

      stub(SpatialIndex, :get_unit_position, fn :mob, 1 -> {:ok, {100, 100, "prontera"}} end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 100, 100, _ ->
        [{:homunculus, 3}]
      end)

      stub(TargetResolver, :resolve, fn :homunculus, 3 -> {:ok, self(), target, :homunculus} end)
      stub(OnHitEffects, :direct, fn _, _, _, _ -> :ok end)

      expect(Interpreter, :apply_status, fn :homunculus, 3, unquote(status), params ->
        assert params[:source_type] == :mob
        assert params[:caster_id] == 1
        :ok
      end)

      payload = %{
        map_name: "prontera",
        x: 100,
        y: 100,
        caster_type: :mob,
        caster_id: 1,
        deferred_epoch: caster.deferred_epoch,
        skill_level: 5
      }

      assert :ok = unquote(skill).deferred(payload, caster)
    end

    test "#{skill} can affect the caster's own homunculus at the party rate" do
      caster =
        Aesir.ZoneServer.PlayerStateFixture.build(%{
          character_id: 1,
          map_name: "prontera",
          x: 100,
          y: 100,
          stats: %{current_state: %{hp: 100}}
        })

      target = %HomunculusState{
        id: 3,
        owner_character_id: 1,
        class_id: 6001,
        name: "Lif",
        world_gid: 3,
        map_name: "prontera",
        x: 101,
        y: 100,
        hp: 100,
        max_hp: 100,
        lifecycle: :active
      }

      stub(SpatialIndex, :get_unit_position, fn :player, 1 -> {:ok, {100, 100, "prontera"}} end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 100, 100, _ ->
        [{:homunculus, 3}]
      end)

      stub(TargetResolver, :resolve, fn :homunculus, 3 -> {:ok, self(), target, :homunculus} end)
      stub(OnHitEffects, :direct, fn _, _, _, _ -> :ok end)

      expect(Interpreter, :apply_status, fn :homunculus, 3, unquote(status), params ->
        assert params[:success_rate] == unquote(if status == :sc_freeze, do: 10.0, else: 12.5)
        :ok
      end)

      payload = %{
        map_name: "prontera",
        x: 100,
        y: 100,
        caster_type: :player,
        caster_id: 1,
        deferred_epoch: caster.deferred_epoch,
        skill_level: 5
      }

      assert :ok = unquote(skill).deferred(payload, caster)
    end
  end
end
