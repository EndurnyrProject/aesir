defmodule Aesir.ZoneServer.Integration.RidingLifecycleTest do
  @moduledoc """
  End-to-end acceptance coverage for the Knight riding lifecycle (mount,
  restore, death, Cavalier Mastery recompute, job change, skill reset,
  dismount), driving the real `PlayerSession`/`MountHandler`/`StatusStorage`
  stack, mirroring the cart integration coverage style.

  The real Knight skill tree (`priv/db/skill_tree/knight.yml`) backs every
  phase: it inherits Swordman and adds the 10 KN_ entries, including
  `KN_RIDING` (requires `SM_ENDURE` 1) and `KN_CAVALIERMASTERY` (requires
  `KN_RIDING` 1). Each Knight fixture seeds that full prerequisite chain
  (`SM_PROVOKE` 5 -> `SM_ENDURE` 1 -> `KN_RIDING` 1) directly on the
  character row rather than clicking through it, the same way every other
  integration fixture seeds an already-learned skill (`insert_merchant`'s
  `learn_pushcart` being the exception that actually needs the click, because
  that test is about the click itself).

  "Learning Cavalier Mastery while mounted" is the one phase where the click
  itself is the behavior under test, so it drives the real `LearnSkill`
  packet all the way through `SkillLearningHandler.handle_learn_skill/2` ->
  the real (unstubbed) `SkillTree.learn/2` gate -> `MountHandler.recompute/1`.

  Each phase seeds its own fresh Knight character rather than chaining a
  single session end-to-end. That is a readability/isolation choice, not a
  data limitation: relearning `KN_RIDING` after losing it is fully possible
  now via the real prerequisite chain. Keeping phases independent means each
  test's assertions only have to account for that test's own fixture, and a
  failure in one phase can't cascade into a confusing failure in the next.

  Death/respawn uses a small bounded-poll helper (`eventually/2`) rather than
  a fixed sleep, matching the existing precedent in
  `MonkStatusLifecycleIntegrationTest` for the same kill -> respawn shape.
  """

  use Aesir.ZoneServer.IntegrationCase

  import Bitwise

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.MountRequest
  alias Aesir.Net.MountResult
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillList
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnCavaliermastery
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnRiding
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmEndure
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmProvoke
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  # rAthena class ids (matches JobChangeIntegrationTest): 2nd-class Knight,
  # base Swordman (Knight's own skill-tree parent, whose tree still lacks
  # every KN_ skill) and 1st-class Merchant (an unrelated tree, used as the
  # unambiguous "drops the mount" job-change target).
  @knight_class 7
  @swordman_class 1
  @merchant_class 5

  @status_id :sc_riding
  @riding_bit Option.id(:riding)
  @unrelated_bit Option.id(:wedding)
  @base_walk_speed 150

  @jobchange_npc_pos {180, 180}
  @keep_mount_npc_pos {182, 180}
  @skill_reset_npc_pos {181, 180}

  defmodule KnightToMerchantNpc do
    @moduledoc false
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 180, y: 180, dir: 0, sprite: 58, name: "Merchant Master"}]

    @target_job 5

    @impl true
    def on_talk(ctx) do
      ctx
      |> jobchange(@target_job)
      |> mes("Done")
      |> close()
    end
  end

  defmodule SwordmanToKnightNpc do
    @moduledoc false
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 182, y: 180, dir: 0, sprite: 58, name: "Knight Master"}]

    @target_job 7

    @impl true
    def on_talk(ctx) do
      ctx
      |> jobchange(@target_job)
      |> mes("Done")
      |> close()
    end
  end

  defmodule KnightSkillResetNpc do
    @moduledoc false
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 181, y: 180, dir: 0, sprite: 58, name: "Skill Reset"}]

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

    NpcRegistry.reload([KnightToMerchantNpc, SwordmanToKnightNpc, KnightSkillResetNpc])

    :ok
  end

  describe "mount" do
    test "MountRequest applies SC_RIDING, sets the option bit, speeds the player up, and persists the option (other bits kept)" do
      character =
        insert_knight(%{
          option: @unrelated_bit,
          learned_skills: riding_learned_skills()
        })

      session = start_knight_session(character, {150, 150})
      char_id = character.id
      flush_packets()

      refute riding?(get_player_state(session.pid))

      simulate_incoming_message(session.pid, %MountRequest{mount: true})
      assert_receive {:packet_sent, %MountResult{result: :MOUNT_OK}, _}, 1_000

      mounted = get_player_state(session.pid)

      assert riding?(mounted)
      assert band(mounted.option, @riding_bit) != 0
      assert band(mounted.option, @unrelated_bit) != 0
      assert mounted.stats.riding == true
      assert mounted.walk_speed < @base_walk_speed

      assert %StatusEntry{val1: 0} = StatusStorage.get_status(:player, char_id, @status_id)

      assert %{movement_speed: -25, aspd: -50} =
               ModifierCalculator.get_all_modifiers(:player, char_id)

      assert band(StatusDisplay.spawn_state(:player, char_id).effect_state, @riding_bit) != 0

      assert Repo.get(Character, char_id).option == (@unrelated_bit ||| @riding_bit)
    end
  end

  describe "relog restore" do
    test "starting a session with the persisted riding bit re-applies SC_RIDING and its modifiers" do
      character =
        insert_knight(%{
          option: @riding_bit,
          learned_skills: riding_learned_skills(cavalier_level: 2)
        })

      session = start_knight_session(character, {150, 150})

      restored = get_player_state(session.pid)

      assert riding?(restored)
      assert StatusStorage.has_status?(:player, character.id, @status_id)
      assert StatusStorage.get_status(:player, character.id, @status_id).val1 == 2

      assert %{movement_speed: -25, aspd: -30} =
               ModifierCalculator.get_all_modifiers(:player, character.id)

      assert restored.walk_speed < @base_walk_speed
    end
  end

  describe "death and respawn" do
    test "a mounted Peco-Peco survives death (permanent status) and stays mounted after respawn" do
      character =
        insert_knight(%{
          learned_skills: riding_learned_skills(cavalier_level: 1)
        })

      session = start_knight_session(character, {150, 150})
      char_id = character.id
      flush_packets()

      simulate_incoming_message(session.pid, %MountRequest{mount: true})
      assert_receive {:packet_sent, %MountResult{result: :MOUNT_OK}, _}, 1_000

      mounted = get_player_state(session.pid)
      assert riding?(mounted)
      mounted_option = mounted.option

      PlayerSession.apply_damage(session.pid, 999_999_999, nil)

      assert eventually(fn -> get_player_state(session.pid).action_state == :dead end)

      dead = get_player_state(session.pid)
      assert dead.option == mounted_option
      assert riding?(dead)
      assert StatusStorage.has_status?(:player, char_id, @status_id)
      assert StatusStorage.get_status(:player, char_id, @status_id).val1 == 1

      simulate_incoming_message(session.pid, %Respawn{type: 0})

      assert eventually(fn -> get_player_state(session.pid).action_state == :idle end)

      respawned = get_player_state(session.pid)
      assert riding?(respawned)
      assert StatusStorage.has_status?(:player, char_id, @status_id)

      assert %{movement_speed: -25, aspd: -40} =
               ModifierCalculator.get_all_modifiers(:player, char_id)

      assert respawned.walk_speed < @base_walk_speed
    end
  end

  describe "learning Cavalier Mastery while mounted" do
    test "raises the learned level through the real SkillTree gate and shrinks the ASPD penalty immediately" do
      character =
        insert_knight(%{
          option: @riding_bit,
          learned_skills: riding_learned_skills()
        })

      session = start_knight_session(character, {150, 150})
      char_id = character.id
      flush_packets()

      assert %{aspd: -50} = ModifierCalculator.get_all_modifiers(:player, char_id)

      simulate_incoming_message(session.pid, %LearnSkill{skill_id: kn_cavaliermastery_id()})
      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      raised = get_player_state(session.pid)
      assert riding?(raised)

      assert raised.stats.progression.learned_skills[kn_cavaliermastery_id()] == 1
      assert StatusStorage.get_status(:player, char_id, @status_id).val1 == 1

      assert %{movement_speed: -25, aspd: -40} =
               ModifierCalculator.get_all_modifiers(:player, char_id)

      assert Repo.get(Character, char_id).learned_skills[
               Integer.to_string(kn_cavaliermastery_id())
             ] ==
               1
    end
  end

  describe "job change to a non-riding job" do
    test "knight -> merchant force-dismounts the Peco-Peco" do
      {x, y} = @jobchange_npc_pos

      character =
        insert_knight(%{
          option: @riding_bit,
          learned_skills: riding_learned_skills(cavalier_level: 2),
          last_x: x,
          last_y: y,
          save_x: x,
          save_y: y
        })

      session = start_knight_session(character, {x, y})
      char_id = character.id

      assert riding?(get_player_state(session.pid))
      flush_packets()

      {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", x, y)
      gid = NpcRegistry.entity_id(npc_placement)
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      changed = get_player_state(session.pid)

      refute riding?(changed)
      assert band(changed.option, @riding_bit) == 0
      assert changed.stats.riding == false
      assert changed.stats.progression.job_id == @merchant_class
      refute StatusStorage.has_status?(:player, char_id, @status_id)
      assert ModifierCalculator.get_all_modifiers(:player, char_id) == %{}
      assert Repo.get(Character, char_id).option == 0
    end
  end

  describe "job change to a job that still grants KN_RIDING" do
    test "swordman -> knight keeps the mount" do
      {x, y} = @keep_mount_npc_pos

      character =
        insert_knight(%{
          class: @swordman_class,
          option: @riding_bit,
          learned_skills: riding_learned_skills(cavalier_level: 2),
          last_x: x,
          last_y: y,
          save_x: x,
          save_y: y
        })

      session = start_knight_session(character, {x, y})
      char_id = character.id

      assert riding?(get_player_state(session.pid))
      flush_packets()

      {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", x, y)
      gid = NpcRegistry.entity_id(npc_placement)
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      changed = get_player_state(session.pid)

      assert riding?(changed)
      assert band(changed.option, @riding_bit) != 0
      assert changed.stats.riding == true
      assert changed.stats.progression.job_id == @knight_class
      assert Map.has_key?(changed.stats.progression.learned_skills, kn_riding_id())
      assert StatusStorage.has_status?(:player, char_id, @status_id)

      assert %{movement_speed: -25, aspd: -30} =
               ModifierCalculator.get_all_modifiers(:player, char_id)

      assert Repo.get(Character, char_id).option == @riding_bit
    end
  end

  describe "skill reset while mounted" do
    test "dismounts as part of the refund (KN_RIDING is never exempt)" do
      {x, y} = @skill_reset_npc_pos

      character =
        insert_knight(%{
          option: @riding_bit,
          learned_skills: riding_learned_skills(),
          last_x: x,
          last_y: y,
          save_x: x,
          save_y: y
        })

      session = start_knight_session(character, {x, y})
      char_id = character.id

      assert riding?(get_player_state(session.pid))
      flush_packets()

      {:ok, {_module, npc_placement}} = NpcRegistry.module_at("prontera", x, y)
      gid = NpcRegistry.entity_id(npc_placement)
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      reset = get_player_state(session.pid)

      refute riding?(reset)
      assert band(reset.option, @riding_bit) == 0
      assert reset.stats.riding == false
      assert reset.stats.progression.learned_skills == %{}
      refute StatusStorage.has_status?(:player, char_id, @status_id)
      assert Repo.get(Character, char_id).option == 0
    end
  end

  describe "dismount idempotency" do
    test "dismounting while not mounted is a no-op reported as MOUNT_NOT_MOUNTED" do
      character = insert_knight(%{learned_skills: riding_learned_skills()})

      session = start_knight_session(character, {150, 150})
      char_id = character.id
      flush_packets()

      refute riding?(get_player_state(session.pid))

      simulate_incoming_message(session.pid, %MountRequest{mount: false})
      assert_receive {:packet_sent, %MountResult{result: :MOUNT_NOT_MOUNTED}, _}, 1_000

      unchanged = get_player_state(session.pid)
      refute riding?(unchanged)
      assert unchanged.option == 0
      refute StatusStorage.has_status?(:player, char_id, @status_id)
      assert Process.alive?(session.pid)
    end
  end

  defp start_knight_session(character, {x, y}) do
    session = start_player_session(character: character, map_name: "prontera", position: {x, y})
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp insert_knight(overrides) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "knight#{uniq}",
        userid: "knight#{uniq}",
        user_pass: "password",
        email: "knight#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "Knighty#{uniq}",
          class: @knight_class,
          base_level: 50,
          job_level: 50,
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 10,
          luk: 10,
          skill_point: 5,
          last_map: "prontera",
          last_x: 150,
          last_y: 150,
          save_map: "prontera",
          save_x: 150,
          save_y: 150
        },
        overrides
      )

    {:ok, character} =
      %Character{}
      |> Character.changeset(attrs)
      |> Repo.insert()

    character
  end

  # The real KN_RIDING prerequisite chain (SM_PROVOKE 5 -> SM_ENDURE 1 ->
  # KN_RIDING 1), seeded directly rather than clicked through, plus an
  # optional already-learned Cavalier Mastery level for phases that don't
  # test the learn click itself.
  defp riding_learned_skills(opts \\ []) do
    cavalier_level = Keyword.get(opts, :cavalier_level, 0)

    base = [
      {sm_provoke_id(), 5},
      {sm_endure_id(), 1},
      {kn_riding_id(), 1}
    ]

    pairs =
      if cavalier_level > 0, do: base ++ [{kn_cavaliermastery_id(), cavalier_level}], else: base

    learned_skills(pairs)
  end

  defp learned_skills(pairs) do
    Map.new(pairs, fn {skill_id, level} -> {Integer.to_string(skill_id), level} end)
  end

  defp sm_provoke_id, do: SmProvoke.definition().id
  defp sm_endure_id, do: SmEndure.definition().id
  defp kn_riding_id, do: KnRiding.definition().id
  defp kn_cavaliermastery_id, do: KnCavaliermastery.definition().id

  defp riding?(game_state), do: MountHandler.riding?(%{game_state: game_state})
end
