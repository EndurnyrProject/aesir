defmodule Aesir.ZoneServer.Integration.FalconLifecycleTest do
  @moduledoc """
  End-to-end acceptance coverage for the durable Falcon lifecycle, driving the
  real `PlayerSession`/`FalconHandler`/`StatusStorage` stack and mirroring
  `RidingLifecycleTest`'s shape.

  There is no script/client enable entry point yet (that is Task 7's
  `setfalcon`), so every phase seeds the persisted `option` bit and the
  learned `HT_FALCON` directly on the character row and exercises the
  lifecycle surfaces that already exist: spawn restore, stale-bit cleanup,
  death/respawn, cross-map warp, reconnect, skill reset, and job change.
  """

  use Aesir.ZoneServer.IntegrationCase

  import Bitwise

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillList
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFalcon
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @hunter_class 11
  @merchant_class 5

  @status_id :sc_falcon
  @falcon_bit Option.id(:falcon)

  @jobchange_npc_pos {184, 180}
  @skill_reset_npc_pos {185, 180}

  defmodule HunterToMerchantNpc do
    @moduledoc false
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 184, y: 180, dir: 0, sprite: 58, name: "Merchant Master"}]

    @target_job 5

    @impl true
    def on_talk(ctx) do
      ctx
      |> jobchange(@target_job)
      |> mes("Done")
      |> close()
    end
  end

  defmodule HunterSkillResetNpc do
    @moduledoc false
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 185, y: 180, dir: 0, sprite: 58, name: "Skill Reset"}]

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

    NpcRegistry.reload([HunterToMerchantNpc, HunterSkillResetNpc])

    :ok
  end

  describe "relog restore" do
    test "a valid persisted Falcon bit re-applies SC_FALCON and folds the sprite into effect_state" do
      character = insert_hunter(%{option: @falcon_bit, learned_skills: falcon_learned_skills()})

      session = start_hunter_session(character, {150, 150})
      char_id = character.id

      restored = get_player_state(session.pid)

      assert falcon?(restored)
      assert StatusStorage.has_status?(:player, char_id, @status_id)
      assert band(StatusDisplay.spawn_state(:player, char_id).effect_state, @falcon_bit) != 0
      assert band(restored.option, @falcon_bit) != 0
    end

    test "a stale Falcon bit without Falconry Mastery is cleared and persisted, not mirrored" do
      character = insert_hunter(%{option: @falcon_bit, learned_skills: %{}})

      session = start_hunter_session(character, {150, 150})
      char_id = character.id

      cleaned = get_player_state(session.pid)

      refute falcon?(cleaned)
      assert cleaned.option == 0
      refute StatusStorage.has_status?(:player, char_id, @status_id)
      assert band(StatusDisplay.spawn_state(:player, char_id).effect_state, @falcon_bit) == 0

      # IntegrationCase runs character persistence inline, so the cleanup is
      # already durable by the time init returns.
      assert Repo.get(Character, char_id).option == 0
    end
  end

  describe "death and respawn" do
    test "the Falcon survives death (permanent status) and respawn" do
      character = insert_hunter(%{option: @falcon_bit, learned_skills: falcon_learned_skills()})

      session = start_hunter_session(character, {150, 150})
      char_id = character.id

      assert falcon?(get_player_state(session.pid))

      PlayerSession.apply_damage(session.pid, 999_999_999, nil)
      assert eventually(fn -> get_player_state(session.pid).action_state == :dead end)

      dead = get_player_state(session.pid)
      assert falcon?(dead)
      assert StatusStorage.has_status?(:player, char_id, @status_id)

      simulate_incoming_message(session.pid, %Respawn{type: 0})
      assert eventually(fn -> get_player_state(session.pid).action_state == :idle end)

      respawned = get_player_state(session.pid)
      assert falcon?(respawned)
      assert StatusStorage.has_status?(:player, char_id, @status_id)
      assert band(StatusDisplay.spawn_state(:player, char_id).effect_state, @falcon_bit) != 0
    end
  end

  describe "map change" do
    test "the Falcon survives a cross-map warp" do
      character = insert_hunter(%{option: @falcon_bit, learned_skills: falcon_learned_skills()})

      session = start_hunter_session(character, {150, 150})
      char_id = character.id

      assert falcon?(get_player_state(session.pid))

      PlayerSession.warp(session.pid, "prt_fild01", 100, 100)
      assert eventually(fn -> get_player_state(session.pid).map_name == "prt_fild01" end)

      warped = get_player_state(session.pid)
      assert falcon?(warped)
      assert StatusStorage.has_status?(:player, char_id, @status_id)
      assert band(StatusDisplay.spawn_state(:player, char_id).effect_state, @falcon_bit) != 0
    end
  end

  describe "reconnect" do
    test "logout persists nothing extra (SC_FALCON is no_save) and the next spawn restores from the option bit" do
      character = insert_hunter(%{option: @falcon_bit, learned_skills: falcon_learned_skills()})

      first = start_hunter_session(character, {150, 150})
      char_id = character.id

      assert falcon?(get_player_state(first.pid))
      assert StatusStorage.has_status?(:player, char_id, @status_id)

      end_player_session(first)
      refute StatusStorage.has_status?(:player, char_id, @status_id)

      reloaded = Repo.get(Character, char_id)
      assert band(reloaded.option, @falcon_bit) != 0

      second = start_hunter_session(reloaded, {150, 150})
      on_exit(fn -> end_player_session(second) end)

      restored = get_player_state(second.pid)
      assert falcon?(restored)
      assert StatusStorage.has_status?(:player, char_id, @status_id)
      assert band(StatusDisplay.spawn_state(:player, char_id).effect_state, @falcon_bit) != 0
    end
  end

  describe "skill reset" do
    test "dropping HT_FALCON through the refund force-dismisses the Falcon and persists the cleared bit" do
      {x, y} = @skill_reset_npc_pos

      character =
        insert_hunter(%{
          option: @falcon_bit,
          learned_skills: falcon_learned_skills(),
          last_x: x,
          last_y: y,
          save_x: x,
          save_y: y
        })

      session = start_hunter_session(character, {x, y})
      char_id = character.id

      assert falcon?(get_player_state(session.pid))
      flush_packets()

      gid = NpcRegistry.entity_id(%Placement{map: "prontera", x: x, y: y, sprite: 58})
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      reset = get_player_state(session.pid)

      refute falcon?(reset)
      assert band(reset.option, @falcon_bit) == 0
      refute Map.has_key?(reset.stats.progression.learned_skills, ht_falcon_id())
      refute StatusStorage.has_status?(:player, char_id, @status_id)
      assert band(Repo.get(Character, char_id).option, @falcon_bit) == 0
    end
  end

  describe "job change to a non-falcon job" do
    test "hunter -> merchant force-dismisses the Falcon and persists the cleared bit" do
      {x, y} = @jobchange_npc_pos

      character =
        insert_hunter(%{
          option: @falcon_bit,
          learned_skills: falcon_learned_skills(),
          last_x: x,
          last_y: y,
          save_x: x,
          save_y: y
        })

      session = start_hunter_session(character, {x, y})
      char_id = character.id

      assert falcon?(get_player_state(session.pid))
      flush_packets()

      gid = NpcRegistry.entity_id(%Placement{map: "prontera", x: x, y: y, sprite: 58})
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      changed = get_player_state(session.pid)

      refute falcon?(changed)
      assert band(changed.option, @falcon_bit) == 0
      assert changed.stats.progression.job_id == @merchant_class
      refute StatusStorage.has_status?(:player, char_id, @status_id)
      assert band(Repo.get(Character, char_id).option, @falcon_bit) == 0
    end
  end

  defp start_hunter_session(character, {x, y}) do
    session = start_player_session(character: character, map_name: "prontera", position: {x, y})
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp insert_hunter(overrides) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "hunter#{uniq}",
        userid: "hunter#{uniq}",
        user_pass: "password",
        email: "hunter#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "Hunty#{uniq}",
          class: @hunter_class,
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

  defp falcon_learned_skills do
    %{Integer.to_string(ht_falcon_id()) => 1}
  end

  defp ht_falcon_id, do: HtFalcon.definition().id

  defp falcon?(game_state), do: FalconHandler.falcon?(%{game_state: game_state})
end
