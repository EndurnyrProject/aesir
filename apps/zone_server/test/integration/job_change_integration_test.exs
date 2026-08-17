defmodule Aesir.ZoneServer.Integration.JobChangeIntegrationTest do
  @moduledoc """
  End-to-end coverage that an NPC's `jobchange` DSL call flips a live player's
  job and refreshes the client's skill window, mirroring the merchant-skills
  integration style: a real `PlayerSession`, a real `Npc.Registry` placement
  driven through `Script.Interaction`, and the production
  `ScriptEffectHandler` -> `ProgressionHandler.apply_job_change/2` core.

    1. Talking to the Job Master flips `progression.job_id` to the target job,
       persists `class:` on the character row, and pushes a fresh `SkillList`
       built from the new job's tree.
    2. Talking to a Job Master targeting an unknown job id halts the script
       with `:unknown_job` and leaves the runtime and persisted job untouched.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.SkillList
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry

  @novice_class 0
  @knight_class 7
  @swordman_class 1
  @acolyte_class 4
  @merchant_class 5
  @alchemist_class 18

  defmodule ValidJobMasterNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 160, y: 160, dir: 0, sprite: 58, name: "Job Master"}]

    @target_job 7

    @impl true
    def on_talk(ctx) do
      ctx = jobchange(ctx, @target_job)

      case ctx.status do
        :ok -> ctx |> mes("You are now a #{class(ctx)}!") |> close()
        {:error, reason} -> ctx |> mes("Job change failed: #{inspect(reason)}") |> close()
      end
    end
  end

  defmodule BrokenJobMasterNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 161, y: 160, dir: 0, sprite: 58, name: "Broken Job Master"}]

    @target_job 99_999

    @impl true
    def on_talk(ctx) do
      ctx = jobchange(ctx, @target_job)

      case ctx.status do
        :ok -> ctx |> mes("You are now a #{class(ctx)}!") |> close()
        {:error, reason} -> ctx |> mes("Job change failed: #{inspect(reason)}") |> close()
      end
    end
  end

  defmodule SwordmanJobMasterNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 162, y: 160, dir: 0, sprite: 58, name: "Swordman Master"}]

    @target_job 1

    @impl true
    def on_talk(ctx) do
      ctx
      |> jobchange(@target_job)
      |> mes("Done")
      |> close()
    end
  end

  defmodule AlchemistJobMasterNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 164, y: 160, dir: 0, sprite: 58, name: "Alchemist Master"}]

    @impl true
    def on_talk(ctx) do
      ctx
      |> jobchange(18)
      |> mes("Done")
      |> close()
    end
  end

  defmodule SkillResetNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 163, y: 160, dir: 0, sprite: 58, name: "Skill Reset"}]

    @impl true
    def on_talk(ctx) do
      ctx
      |> reset_skills()
      |> mes("Skills reset")
      |> close()
    end
  end

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)

    NpcRegistry.reload([
      ValidJobMasterNpc,
      BrokenJobMasterNpc,
      SwordmanJobMasterNpc,
      AlchemistJobMasterNpc,
      SkillResetNpc
    ])

    :ok
  end

  describe "jobchange via NPC dialog" do
    test "flips class, persists it, and refreshes the client's SkillList" do
      character = insert_novice()

      session =
        start_player_session(character: character, map_name: "prontera", position: {160, 160})

      on_exit(fn -> end_player_session(session) end)
      flush_packets()

      {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", 160, 160)
      gid = NpcRegistry.entity_id(npc_placement)
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: text}, _}, 1_000
      assert text =~ "knight"

      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      state = get_player_state(session.pid)
      assert state.stats.progression.job_id == @knight_class

      assert Repo.get(Character, character.id).class == @knight_class
    end

    test "Merchant keeps inherited skills and unlocks the Alchemist tree" do
      discount = catalog_id(:mc_discount)
      inccarry = catalog_id(:mc_inccarry)
      bash = catalog_id(:sm_bash)
      pharmacy = catalog_id(:am_pharmacy)
      demonstration = catalog_id(:am_demonstration)
      learning_potion = catalog_id(:am_learningpotion)
      cp_helm = catalog_id(:am_cp_helm)
      cp_shield = catalog_id(:am_cp_shield)
      cp_armor = catalog_id(:am_cp_armor)

      character =
        insert_novice(%{
          class: @merchant_class,
          skill_point: 50,
          learned_skills: %{
            Integer.to_string(discount) => 5,
            Integer.to_string(inccarry) => 3,
            Integer.to_string(bash) => 3
          }
        })

      session =
        start_player_session(character: character, map_name: "prontera", position: {164, 160})

      on_exit(fn -> end_player_session(session) end)
      flush_packets()

      {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", 164, 160)
      gid = NpcRegistry.entity_id(npc_placement)
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      state = get_player_state(session.pid)
      progression = state.stats.progression

      assert progression.job_id == @alchemist_class
      assert progression.learned_skills == %{discount => 5, inccarry => 3}

      assert Repo.get(Character, character.id).learned_skills == %{
               Integer.to_string(discount) => 5,
               Integer.to_string(inccarry) => 3
             }

      assert {:error, :missing_prerequisite} = SkillTree.can_learn(progression, demonstration)

      qualified_progression = %{
        progression
        | learned_skills:
            Map.merge(progression.learned_skills, %{
              learning_potion => 5,
              pharmacy => 6,
              cp_helm => 3,
              cp_shield => 3,
              cp_armor => 3
            })
      }

      for skill <- [
            :am_axemastery,
            :am_learningpotion,
            :am_pharmacy,
            :am_demonstration,
            :am_acidterror,
            :am_potionpitcher,
            :am_cannibalize,
            :am_spheremine,
            :am_cp_helm,
            :am_cp_shield,
            :am_cp_armor,
            :am_cp_weapon
          ] do
        assert :ok = SkillTree.can_learn(qualified_progression, catalog_id(skill))
      end
    end

    test "an invalid job id halts the script without mutating state" do
      character = insert_novice()

      session =
        start_player_session(character: character, map_name: "prontera", position: {161, 160})

      on_exit(fn -> end_player_session(session) end)
      flush_packets()

      {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", 161, 160)
      gid = NpcRegistry.entity_id(npc_placement)
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: text}, _}, 1_000
      assert text =~ "unknown_job"

      refute_receive {:packet_sent, %SkillList{}, _}, 200

      state = get_player_state(session.pid)
      assert state.stats.progression.job_id == @novice_class

      assert Repo.get(Character, character.id).class == @novice_class
    end
  end

  describe "rAthena cleanup via NPC dialog" do
    test "prunes out-of-tree learned skills on job change and persists the result" do
      sm_bash = catalog_id(:sm_bash)
      tf_steal = catalog_id(:tf_steal)

      character =
        insert_novice(%{
          learned_skills: %{Integer.to_string(sm_bash) => 3, Integer.to_string(tf_steal) => 5}
        })

      session =
        start_player_session(character: character, map_name: "prontera", position: {162, 160})

      on_exit(fn -> end_player_session(session) end)
      flush_packets()

      {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", 162, 160)
      gid = NpcRegistry.entity_id(npc_placement)
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      state = get_player_state(session.pid)
      assert state.stats.progression.job_id == @swordman_class
      assert state.stats.progression.learned_skills == %{sm_bash => 3}

      persisted = Repo.get(Character, character.id)
      assert persisted.learned_skills == %{Integer.to_string(sm_bash) => 3}
    end

    test "reset_skills refunds learned levels into skill points and persists" do
      sm_bash = catalog_id(:sm_bash)

      character =
        insert_novice(%{
          class: @swordman_class,
          skill_point: 1,
          learned_skills: %{Integer.to_string(sm_bash) => 4}
        })

      session =
        start_player_session(character: character, map_name: "prontera", position: {163, 160})

      on_exit(fn -> end_player_session(session) end)
      flush_packets()

      {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", 163, 160)
      gid = NpcRegistry.entity_id(npc_placement)
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      state = get_player_state(session.pid)
      assert state.stats.progression.learned_skills == %{}
      assert state.stats.progression.skill_point == 5

      persisted = Repo.get(Character, character.id)
      assert persisted.learned_skills == %{}
      assert persisted.skill_point == 5
    end

    test "ends a dropped-skill status and recomputes stats without its modifiers" do
      al_incagi = catalog_id(:al_incagi)

      character =
        insert_novice(%{
          class: @acolyte_class,
          learned_skills: %{Integer.to_string(al_incagi) => 10}
        })

      session =
        start_player_session(character: character, map_name: "prontera", position: {162, 160})

      on_exit(fn -> end_player_session(session) end)

      StatusInterpreter.apply_status(:player, character.id, :sc_increaseagi,
        val1: 5,
        val2: 12,
        duration: 600_000
      )

      assert StatusStorage.has_status?(:player, character.id, :sc_increaseagi)
      flush_packets()

      {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", 162, 160)
      gid = NpcRegistry.entity_id(npc_placement)
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000

      state = get_player_state(session.pid)
      assert state.stats.progression.job_id == @swordman_class
      refute StatusStorage.has_status?(:player, character.id, :sc_increaseagi)
      assert state.stats.modifiers.status_effects == %{}
    end
  end

  defp insert_novice(overrides \\ %{}) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "jobmaster#{uniq}",
        userid: "jobmaster#{uniq}",
        user_pass: "password",
        email: "jobmaster#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "Novice#{uniq}",
          class: @novice_class,
          base_level: 50,
          job_level: 10,
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 10,
          luk: 10,
          last_map: "prontera",
          last_x: 160,
          last_y: 160,
          save_map: "prontera",
          save_x: 160,
          save_y: 160
        },
        overrides
      )

    {:ok, character} =
      %Character{}
      |> Character.changeset(attrs)
      |> Repo.insert()

    character
  end

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end
end
