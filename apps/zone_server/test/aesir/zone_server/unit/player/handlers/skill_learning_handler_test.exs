defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandlerTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.LearnSkillResult
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(SkillTree)
    StatusStorage.remove_status(:player, 1000, :sc_riding)
    on_exit(fn -> StatusStorage.remove_status(:player, 1000, :sc_riding) end)
    :ok
  end

  {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
  @swordman_id swordman_id

  {:ok, wizard_id} = AvailableJobs.job_name_to_id(:wizard)
  @wizard_id wizard_id

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp swordman_state(skill_point, learned_skills) do
    player_state(@swordman_id, skill_point, learned_skills)
  end

  defp player_state(job_id, skill_point, learned_skills) do
    base = PlayerState.new(character())

    stats =
      base.stats
      |> put_in([Access.key!(:progression), Access.key!(:job_id)], job_id)
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
      test_pid = self()

      stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, game_state ->
        send(test_pid, {:registry_updated, game_state})
        :ok
      end)

      reject(&Manager.sync_member/3)
      stub(StatusSync, :send_params, fn _conn, _params -> :ok end)

      expect(CharacterPersistence, :update_character, fn 1000, attrs, async: true ->
        assert_received {:registry_updated, _game_state}
        send(test_pid, {:persisted, attrs})
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

      stats = new_state.game_state.stats
      assert_received {:persisted, attrs}

      assert attrs == %{
               learned_skills: %{Integer.to_string(sword_id) => 3},
               skill_point: 2,
               hp: stats.current_state.hp,
               max_hp: stats.derived_stats.max_hp,
               sp: stats.current_state.sp,
               max_sp: stats.derived_stats.max_sp,
               ap: stats.current_state.ap,
               max_ap: stats.derived_stats.max_ap
             }

      assert_received {:send, :bulk, {:skill_list, %SkillList{}}}
    end

    test "publishes party-visible maxima changed by learned-skill recalculation" do
      sword_id = catalog_id(:sm_sword)
      state = swordman_state(1, %{})
      game_state = %{state.game_state | party_id: 7}
      state = %{state | game_state: game_state}
      max_hp = game_state.stats.derived_stats.max_hp + 100

      stub(PlayerStats, :calculate_stats, fn stats, 1000 ->
        derived = %{stats.derived_stats | max_hp: max_hp}
        %{stats | derived_stats: derived}
      end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_params, fn _conn, _params -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      expect(Manager, :sync_member, fn 7, 1000, member ->
        assert %Member{char_id: 1000, max_hp: ^max_hp, online: true} = member
        {:ok, %{}}
      end)

      assert {:noreply, _new_state} =
               SkillLearningHandler.handle_learn_skill(sword_id, state)
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

    test "rejects active quest skills outside the normal Wizard tree" do
      state = player_state(@wizard_id, 1, %{})

      reject(&CharacterPersistence.update_character/3)

      for skill_name <- [:wz_estimation, :wz_sightblaster] do
        skill_id = catalog_id(skill_name)

        assert {:noreply, ^state} = SkillLearningHandler.handle_learn_skill(skill_id, state)

        assert_received {:send, :gameplay,
                         {:learn_skill_result,
                          %LearnSkillResult{skill_id: ^skill_id, ok: false, reason: 1}}}
      end
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

  describe "handle_learn_skill/2 riding ASPD recompute" do
    setup do
      stub(UnitRegistry, :get_unit_info, fn :player, 1000 ->
        {:ok,
         %{
           unit_id: 1000,
           unit_type: :player,
           race: :human,
           element: :neutral,
           element_level: 1,
           boss_flag: false,
           size: :medium,
           stats: %{level: 50, base_level: 50, str: 10, agi: 1, vit: 1, int: 1, dex: 1, luk: 1}
         }}
      end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_params, fn _conn, _params -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      :ok
    end

    test "learning KN_CAVALIERMASTERY while mounted shrinks the SC_RIDING ASPD penalty immediately" do
      cavalier_id = catalog_id(:kn_cavaliermastery)
      riding_bit = Option.id(:riding)

      stub(SkillTree, :learn, fn progression, ^cavalier_id ->
        learned = Map.put(progression.learned_skills, cavalier_id, 1)
        {:ok, %{progression | learned_skills: learned, skill_point: progression.skill_point - 1}}
      end)

      :ok = StatusStorage.apply_status(:player, 1000, :sc_riding, val1: 0)

      state = swordman_state(1, %{cavalier_id => 0})
      state = put_in(state.game_state.option, riding_bit)

      assert {:noreply, new_state} = SkillLearningHandler.handle_learn_skill(cavalier_id, state)

      assert MountHandler.riding?(new_state)
      assert StatusStorage.get_status(:player, 1000, :sc_riding).val1 == 1
    end

    test "learning an unrelated skill while mounted leaves SC_RIDING untouched" do
      sword_id = catalog_id(:sm_sword)
      riding_bit = Option.id(:riding)

      :ok = StatusStorage.apply_status(:player, 1000, :sc_riding, val1: 5)

      state = swordman_state(1, %{})
      state = put_in(state.game_state.option, riding_bit)

      assert {:noreply, _new_state} = SkillLearningHandler.handle_learn_skill(sword_id, state)

      assert StatusStorage.get_status(:player, 1000, :sc_riding).val1 == 5
    end

    test "learning KN_CAVALIERMASTERY while not mounted does not apply SC_RIDING" do
      cavalier_id = catalog_id(:kn_cavaliermastery)

      stub(SkillTree, :learn, fn progression, ^cavalier_id ->
        learned = Map.put(progression.learned_skills, cavalier_id, 1)
        {:ok, %{progression | learned_skills: learned, skill_point: progression.skill_point - 1}}
      end)

      state = swordman_state(1, %{cavalier_id => 0})

      assert {:noreply, new_state} = SkillLearningHandler.handle_learn_skill(cavalier_id, state)

      refute MountHandler.riding?(new_state)
      refute StatusStorage.has_status?(:player, 1000, :sc_riding)
    end
  end

  describe "packet dispatch" do
    test "a LearnSkill packet dispatches to the handler with the skill id" do
      sword_id = catalog_id(:sm_sword)
      state = %{game_state: %PlayerState{character_id: 1000}}

      expect(SkillLearningHandler, :handle_learn_skill, fn ^sword_id, st -> {:noreply, st} end)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%LearnSkill{skill_id: sword_id}, state)
    end
  end
end
