defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.LearnSkillResult
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
  @swordman_id swordman_id

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp swordman_state(skill_point, learned_skills) do
    base = PlayerState.new(character())

    stats =
      base.stats
      |> put_in([Access.key!(:progression), Access.key!(:job_id)], @swordman_id)
      |> put_in([Access.key!(:progression), Access.key!(:skill_point)], skill_point)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], learned_skills)

    %{connection_pid: self(), game_state: %{base | stats: stats}}
  end

  defp character do
    %Aesir.Commons.Models.Character{
      id: 1000,
      account_id: 2000,
      name: "Swordy",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 10,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 1
    }
  end

  describe "handle_learn_skill/2 valid request" do
    test "decrements the point, raises the level, persists, and syncs the list + skill_point" do
      sword_id = catalog_id(:sm_sword)
      state = swordman_state(3, %{sword_id => 2})

      stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_params, fn _conn, _params -> :ok end)

      expect(CharacterPersistence, :update_character, fn 1000, attrs, async: true ->
        assert attrs.skill_point == 2
        assert attrs.learned_skills == %{Integer.to_string(sword_id) => 3}
        {:ok, %{}}
      end)

      expect(StatusSync, :send_params, fn _conn, params ->
        assert params == %{StatusParams.skill_point() => 2}
        :ok
      end)

      assert {:noreply, new_state} =
               SkillLearningHandler.handle_learn_skill(sword_id, state)

      assert new_state.game_state.stats.progression.skill_point == 2
      assert new_state.game_state.stats.progression.learned_skills[sword_id] == 3

      assert_received {:send, :bulk, {:skill_list, %SkillList{}}}
    end
  end

  describe "handle_learn_skill/2 invalid request" do
    test "sends LearnSkillResult{ok: false}, spends no point, leaves state unchanged" do
      sword_id = catalog_id(:sm_sword)
      state = swordman_state(0, %{})

      reject(&CharacterPersistence.update_character/3)

      assert {:noreply, ^state} = SkillLearningHandler.handle_learn_skill(sword_id, state)

      assert_received {:send, :gameplay,
                       {:learn_skill_result,
                        %LearnSkillResult{skill_id: ^sword_id, ok: false, reason: 2}}}
    end
  end

  describe "handle_learn_skill/2 recalculates derived stats" do
    test "learning SM_SWORD with a sword equipped raises ATK" do
      sword_id = catalog_id(:sm_sword)

      stub(ItemManagement, :get_item_by_id, fn _nameid ->
        {:ok,
         %ItemDefinition{
           id: 1101,
           aegis_name: "Sword",
           name: "Sword",
           type: :weapon,
           subtype: :one_handed_sword
         }}
      end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_params, fn _conn, _params -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      base = swordman_state(1, %{})

      game_state =
        put_in(
          base.game_state,
          [Access.key!(:stats), Access.key!(:equipment), Access.key!(:right_hand)],
          1101
        )

      state = %{base | game_state: game_state}

      atk_before = state.game_state.stats.combat_stats.atk

      assert {:noreply, new_state} =
               SkillLearningHandler.handle_learn_skill(sword_id, state)

      assert new_state.game_state.stats.combat_stats.atk > atk_before
    end
  end

  describe "packet dispatch" do
    test "a LearnSkill packet casts {:learn_skill, id}" do
      sword_id = catalog_id(:sm_sword)
      state = %{game_state: %PlayerState{character_id: 1000}}

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%LearnSkill{skill_id: sword_id}, state)

      assert_received {:"$gen_cast", {:learn_skill, ^sword_id}}
    end
  end
end
