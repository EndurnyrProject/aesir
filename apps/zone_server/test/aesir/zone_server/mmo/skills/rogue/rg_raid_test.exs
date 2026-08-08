defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgRaidTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgRaid
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :setup_ets_tables
  setup :verify_on_exit!

  test "is discovered with Sightless Mind's static definition" do
    Catalog.reload()

    assert {:ok, definition} = Catalog.by_id(214)
    assert definition.name == :rg_raid
    assert definition.display_name == "Sightless Mind"
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert {:ok, RgRaid} = Catalog.active_module_for(:rg_raid)
  end

  test "players require Hiding while mob casters bypass the requirement" do
    player = %PlayerState{character_id: 1_000}

    mob = %MobState{
      instance_id: 2_000,
      mob_id: 1,
      mob_data: %{},
      spawn_ref: nil,
      x: 0,
      y: 0,
      map_name: "prontera",
      hp: 1,
      max_hp: 1,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    assert {:error, :requires_hiding} = RgRaid.validate(player, :self, 1, RgRaid.definition())

    :ok = StatusStorage.apply_status(:player, player.character_id, :sc_hiding)

    assert :ok = RgRaid.validate(player, :self, 1, RgRaid.definition())
    assert :ok = RgRaid.validate(mob, :self, 1, RgRaid.definition())
  end

  test "breaks Hiding and hits each nearby enemy, applying riders only on hit" do
    caster = %PlayerState{character_id: 1_000, map_name: "prontera", x: 150, y: 150}
    hit_target = mob(2_000, 151, 150)
    missed_target = mob(2_001, 149, 150)

    expect(StatusInterpreter, :remove_status, fn :player, 1_000, :sc_hiding -> :ok end)

    stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 2 ->
      [
        {:player, caster.character_id},
        {:mob, hit_target.instance_id},
        {:mob, missed_target.instance_id}
      ]
    end)

    stub(TargetResolver, :resolve, fn
      {:player, 1_000} -> {:ok, self(), caster, :player}
      {:mob, 2_000} -> {:ok, self(), hit_target, :mob}
      {:mob, 2_001} -> {:ok, self(), missed_target, :mob}
    end)

    expect(Combat, :execute_skill_attack, 2, fn ^caster, {:mob, target_id}, opts ->
      assert target_id in [2_000, 2_001]
      assert opts[:skill_id] == 214
      assert opts[:skill_level] == 3
      assert opts[:skill_ratio] == 500
      assert opts[:skip_range]
      assert opts[:report_hit]
      if target_id == 2_000, do: {:ok, %{hit?: true}}, else: {:ok, %{hit?: false}}
    end)

    expect(StatusInterpreter, :apply_status, 3, fn :mob, 2_000, status_id, opts ->
      assert status_id in [:sc_stun, :sc_blind, :sc_raid]
      assert opts[:success_rate] == if(status_id == :sc_raid, do: 100, else: 19)
      assert opts[:caster_id] == caster.character_id
      assert opts[:source_type] == :player
      :ok
    end)

    assert {:ok, ^caster} = RgRaid.cast(caster, :self, 3, RgRaid.definition())
  end

  defp mob(id, x, y) do
    %MobState{
      instance_id: id,
      mob_id: 1,
      mob_data: %{},
      spawn_ref: nil,
      x: x,
      y: y,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end
end
