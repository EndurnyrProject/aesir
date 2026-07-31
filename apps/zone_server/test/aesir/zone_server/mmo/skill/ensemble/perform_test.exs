defmodule Aesir.ZoneServer.Mmo.Skill.Ensemble.PerformTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.TestSupport.EnsembleSkill
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "ensemble_perform_test"
  @skill_id 999_998
  @violin 1901
  @whip 1960

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  test "snapshots at the averaged level before fatiguing the partner and caster" do
    caster = player(1, :bard, 7, @violin)
    partner = player(2, :dancer, 4, @whip)
    register(partner)

    expect(Combat, :splash_targets, fn @map, {50, 50}, 4, 1 -> [{:mob, 3}] end)
    record_status_writes()

    params_fun = fn level ->
      Process.put(:params_level, level)
      [val1: level]
    end

    assert {:ok, result} =
             Perform.perform(
               caster,
               EnsembleSkill.definition(),
               7,
               :sc_test_ensemble,
               params_fun,
               scope: :enemy,
               radius: 4,
               duration: 60_000
             )

    assert Process.get(:params_level) == 5
    assert result.last_song == %{skill_id: @skill_id, level: 5}

    assert Process.get(:status_writes) == [
             {:mob, 3, :sc_test_ensemble,
              [val1: 5, caster_id: 1, duration: 60_000, owner_refresh: :notify]},
             {:player, 2, :sc_ensemblefatigue, [owner_refresh: :notify, bypass_resistance: true]},
             {:player, 1, :sc_ensemblefatigue, [owner_refresh: :notify, bypass_resistance: true]}
           ]
  end

  test "snapshots solo at the caster level and fatigues nobody" do
    caster = player(1, :bard, 7, @violin)

    expect(Combat, :splash_targets, fn @map, {50, 50}, 4, 1 -> [{:mob, 3}] end)
    record_status_writes()

    params_fun = fn level ->
      Process.put(:params_level, level)
      [val1: level]
    end

    assert {:ok, result} =
             Perform.perform(
               caster,
               EnsembleSkill.definition(),
               7,
               :sc_test_ensemble,
               params_fun,
               scope: :enemy,
               radius: 4,
               duration: 60_000
             )

    assert Process.get(:params_level) == 7
    assert result.last_song == %{skill_id: @skill_id, level: 7}

    assert Process.get(:status_writes) == [
             {:mob, 3, :sc_test_ensemble,
              [val1: 7, caster_id: 1, duration: 60_000, owner_refresh: :notify]}
           ]
  end

  test "a partner who died since selection does not fail the cast or spare the caster" do
    assert_partner_write_failure_is_survived(fn -> {:error, :target_dead} end)
  end

  test "a partner who deregistered since selection does not fail the cast or spare the caster" do
    assert_partner_write_failure_is_survived(fn ->
      raise "Cannot apply status effect to non-existent player with ID: 2"
    end)
  end

  defp assert_partner_write_failure_is_survived(partner_result) do
    caster = player(1, :bard, 7, @violin)
    partner = player(2, :dancer, 4, @whip)
    register(partner)

    expect(Combat, :splash_targets, fn @map, {50, 50}, 4, 1 -> [{:mob, 3}] end)
    Process.put(:status_writes, [])

    stub(StatusInterpreter, :apply_status, fn unit_type, unit_id, status_id, _params ->
      Process.put(
        :status_writes,
        Process.get(:status_writes) ++ [{unit_type, unit_id, status_id}]
      )

      if {unit_type, unit_id, status_id} == {:player, 2, :sc_ensemblefatigue} do
        partner_result.()
      else
        :ok
      end
    end)

    assert {:ok, result} =
             Perform.perform(
               caster,
               EnsembleSkill.definition(),
               7,
               :sc_test_ensemble,
               fn level -> [val1: level] end,
               scope: :enemy,
               radius: 4,
               duration: 60_000
             )

    assert result.last_song == %{skill_id: @skill_id, level: 5}

    assert Process.get(:status_writes) == [
             {:mob, 3, :sc_test_ensemble},
             {:player, 2, :sc_ensemblefatigue},
             {:player, 1, :sc_ensemblefatigue}
           ]
  end

  defp record_status_writes do
    Process.put(:status_writes, [])

    stub(StatusInterpreter, :apply_status, fn unit_type, unit_id, status_id, params ->
      event = {unit_type, unit_id, status_id, params}
      Process.put(:status_writes, Process.get(:status_writes) ++ [event])
      :ok
    end)
  end

  defp player(id, job, skill_level, weapon) do
    {:ok, job_id} = AvailableJobs.job_name_to_id(job)

    %PlayerState{
      character_id: id,
      party_id: 1,
      x: 50,
      y: 50,
      map_name: @map,
      action_state: :idle,
      stats: %Stats{
        progression: %PlayerProgression{
          job_id: job_id,
          learned_skills: %{@skill_id => skill_level}
        },
        equipment: %Equipment{right_hand: weapon},
        current_state: %CurrentState{hp: 100}
      }
    }
  end

  defp register(player) do
    :ok = UnitRegistry.register_unit(:player, player.character_id, PlayerState, player, nil)
    :ok = SpatialIndex.add_player(player.character_id, player.x, player.y, player.map_name)
  end

  defp setup_ets_tables(context), do: Aesir.TestEtsSetup.setup_ets_tables(context)
end
