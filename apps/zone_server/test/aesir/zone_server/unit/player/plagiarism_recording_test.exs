defmodule Aesir.ZoneServer.Unit.Player.PlagiarismRecordingTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @plagiarism_id 225
  @copyable_skill_id 21

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(StatusStorage)

    stub(CharacterPersistence, :update_stats, fn _character_id, _attrs, _opts ->
      {:ok, %Character{}}
    end)

    stub(StatusStorage, :has_status?, fn :player, _character_id, :sc_preserve -> false end)

    :ok
  end

  test "records a copyable skill at the plagiarism level and refreshes the skill list" do
    state = state_with_skills(%{@plagiarism_id => 3})

    assert {:noreply, new_state} =
             PlayerSession.handle_cast(
               {:unit, {:record_skill_hit, @copyable_skill_id, 5}},
               state
             )

    assert new_state.game_state.plagiarized == %{skill_id: @copyable_skill_id, level: 3}

    assert_received {:send, :bulk,
                     {:skill_list, %SkillList{skills: skills}}}

    assert %{skill_id: @copyable_skill_id, level: 3} =
             Enum.find(skills, &(&1.skill_id == @copyable_skill_id))
  end

  test "does not record a non-copyable skill" do
    state = state_with_skills(%{@plagiarism_id => 5})

    assert {:noreply, new_state} =
             PlayerSession.handle_cast({:unit, {:record_skill_hit, 1, 1}}, state)

    assert new_state.game_state.plagiarized == nil
    refute_received {:send, :bulk, {:skill_list, _}}
  end

  test "does not record a skill without plagiarism" do
    state = state_with_skills(%{})

    assert {:noreply, new_state} =
             PlayerSession.handle_cast(
               {:unit, {:record_skill_hit, @copyable_skill_id, 5}},
               state
             )

    assert new_state.game_state.plagiarized == nil
    refute_received {:send, :bulk, {:skill_list, _}}
  end

  test "does not record while preserve is active" do
    stub(StatusStorage, :has_status?, fn :player, _character_id, :sc_preserve -> true end)
    state = state_with_skills(%{@plagiarism_id => 5})

    assert {:noreply, new_state} =
             PlayerSession.handle_cast(
               {:unit, {:record_skill_hit, @copyable_skill_id, 5}},
               state
             )

    assert new_state.game_state.plagiarized == nil
    refute_received {:send, :bulk, {:skill_list, _}}
  end

  defp state_with_skills(learned_skills) do
    player = PlayerState.new(character())
    progression = %{player.stats.progression | learned_skills: learned_skills}
    game_state = %{player | stats: %{player.stats | progression: progression}}
    %{connection_pid: self(), game_state: game_state}
  end

  defp character do
    %Character{
      id: 1,
      account_id: 2,
      name: "Rogue",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      class: 1,
      base_level: 50,
      job_level: 50,
      sex: "M",
      head_top: 1,
      head_mid: 0,
      head_bottom: 0,
      hair_color: 0,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }
  end
end
