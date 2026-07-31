defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdLullabyTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdLullaby
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState

  @map "bd_lullaby_test"

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  test "publishes A Lullaby's pinned ensemble definition" do
    definition = BdLullaby.definition()

    assert definition.id == 306
    assert definition.name == :bd_lullaby
    assert definition.display_name == "Lullaby"
    assert definition.max_level == 1
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.hit_count == 1
    assert definition.splash_radius == 4
    assert definition.sp_cost == [40]
    assert definition.duration == [60_000]
    assert definition.cast_time == [1_000]
    assert definition.fixed_cast_time == [500]
    assert definition.after_cast_delay == [300]
    assert definition.cooldown == [20_000]
    assert definition.require_weapon == [:musical, :whip]
    assert definition.range == 0
    assert definition.item_cost == []
    assert BdLullaby.__skill_capabilities__() == [:active, :ensemble]
    refute function_exported?(BdLullaby, :dynamic_cost, 4)
  end

  test "sleeps only hostile splash targets at the ordinary 100 percent base rate" do
    caster = caster()

    expect(Combat, :splash_targets, fn @map, {50, 50}, 4, 1 ->
      [{:player, 2}, {:mob, 3}]
    end)

    reject(&PartyManager.get/1)
    Process.put(:status_writes, [])

    stub(StatusInterpreter, :apply_status, fn unit_type, target_id, :sc_sleep, params ->
      Process.put(
        :status_writes,
        Process.get(:status_writes) ++ [{unit_type, target_id, params}]
      )

      :ok
    end)

    assert {:ok, result} = BdLullaby.cast(caster, :self, 1, BdLullaby.definition())
    assert result.last_song == %{skill_id: 306, level: 1}

    assert Process.get(:status_writes) == [
             {:player, 2,
              [success_rate: 100, caster_id: 1, duration: 60_000, owner_refresh: :notify]},
             {:mob, 3,
              [success_rate: 100, caster_id: 1, duration: 60_000, owner_refresh: :notify]}
           ]

    Enum.each(Process.get(:status_writes), fn {_, _, params} ->
      refute Keyword.has_key?(params, :bypass_resistance)
    end)
  end

  defp caster do
    {:ok, job_id} = AvailableJobs.job_name_to_id(:bard)

    %PlayerState{
      character_id: 1,
      party_id: 10,
      x: 50,
      y: 50,
      map_name: @map,
      action_state: :idle,
      stats: %Stats{
        progression: %PlayerProgression{job_id: job_id, learned_skills: %{306 => 1}},
        equipment: %Equipment{right_hand: 1901},
        current_state: %CurrentState{hp: 100}
      }
    }
  end

  defp setup_ets_tables(context), do: Aesir.TestEtsSetup.setup_ets_tables(context)
end
