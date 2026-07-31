defmodule Aesir.ZoneServer.Mmo.Skill.Ensemble.PartnerTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Partner
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "ensemble_partner_test"
  @skill_id 306
  @violin 1901
  @whip 1960

  setup :setup_ets_tables

  test "returns an eligible partner and the averaged skill level" do
    caster = player(1, :bard, 7, @violin)
    partner = player(2, :dancer, 4, @whip)
    register(partner)

    assert {:ok, ^partner, 5} = Partner.find(caster, @skill_id, 7)
  end

  test "rejects the caster" do
    caster = player(1, :bard, 7, @violin)
    register(player(1, :dancer, 4, @whip))

    assert :none = Partner.find(caster, @skill_id, 7)
  end

  test "rejects a candidate with the same performer job" do
    caster = player(1, :bard, 7, @violin)
    register(player(2, :bard, 4, @whip))

    assert :none = Partner.find(caster, @skill_id, 7)
  end

  test "rejects a candidate from a different or zero party" do
    caster = player(1, :bard, 7, @violin)
    register(%{player(2, :dancer, 4, @whip) | party_id: 2})

    assert :none = Partner.find(caster, @skill_id, 7)

    caster_without_party = %{caster | party_id: 0}
    register(%{player(3, :dancer, 4, @whip) | party_id: 0})

    assert :none = Partner.find(caster_without_party, @skill_id, 7)
  end

  test "rejects a candidate who does not know the skill" do
    caster = player(1, :bard, 7, @violin)
    register(player(2, :dancer, 0, @whip))

    assert :none = Partner.find(caster, @skill_id, 7)
  end

  test "rejects a candidate without a musical or whip weapon" do
    caster = player(1, :bard, 7, @violin)
    register(player(2, :dancer, 4, nil))

    assert :none = Partner.find(caster, @skill_id, 7)
  end

  test "rejects a sitting candidate" do
    caster = player(1, :bard, 7, @violin)
    register(%{player(2, :dancer, 4, @whip) | action_state: :sitting})

    assert :none = Partner.find(caster, @skill_id, 7)
  end

  test "rejects a candidate who cannot move" do
    caster = player(1, :bard, 7, @violin)
    register(player(2, :dancer, 4, @whip))
    :ok = StatusStorage.apply_status(:player, 2, :sc_stun)

    assert :none = Partner.find(caster, @skill_id, 7)
  end

  test "rejects a dead candidate" do
    caster = player(1, :bard, 7, @violin)
    candidate = put_in(player(2, :dancer, 4, @whip).stats.current_state.hp, 0)
    register(candidate)

    assert :none = Partner.find(caster, @skill_id, 7)
  end

  test "rejects an unknown candidate job without raising" do
    caster = player(1, :bard, 7, @violin)
    candidate = put_in(player(2, :dancer, 4, @whip).stats.progression.job_id, -1)
    register(candidate)

    assert :none = Partner.find(caster, @skill_id, 7)
  end

  test "returns at most one of several eligible partners" do
    caster = player(1, :bard, 7, @violin)
    first = player(2, :dancer, 4, @whip)
    second = player(3, :dancer, 1, @violin)
    register(first)
    register(second)

    assert {:ok, partner, effective_level} = Partner.find(caster, @skill_id, 7)
    assert {partner, effective_level} in [{first, 5}, {second, 4}]
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
