defmodule Aesir.ZoneServer.Mmo.JobManagement.JobChangeIntegrationTest do
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
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry

  @novice_class 0
  @knight_class 7

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

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([ValidJobMasterNpc, BrokenJobMasterNpc])
    :ok
  end

  describe "jobchange via NPC dialog" do
    test "flips class, persists it, and refreshes the client's SkillList" do
      character = insert_novice()

      session =
        start_player_session(character: character, map_name: "prontera", position: {160, 160})

      on_exit(fn -> end_player_session(session) end)
      flush_packets()

      gid = NpcRegistry.entity_id(%Placement{map: "prontera", x: 160, y: 160, sprite: 58})
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: text}, _}, 1_000
      assert text =~ "knight"

      assert_receive {:packet_sent, %SkillList{}, _}, 1_000

      state = get_player_state(session.pid)
      assert state.stats.progression.job_id == @knight_class

      assert Repo.get(Character, character.id).class == @knight_class
    end

    test "an invalid job id halts the script without mutating state" do
      character = insert_novice()

      session =
        start_player_session(character: character, map_name: "prontera", position: {161, 160})

      on_exit(fn -> end_player_session(session) end)
      flush_packets()

      gid = NpcRegistry.entity_id(%Placement{map: "prontera", x: 161, y: 160, sprite: 58})
      simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: text}, _}, 1_000
      assert text =~ "unknown_job"

      refute_receive {:packet_sent, %SkillList{}, _}, 200

      state = get_player_state(session.pid)
      assert state.stats.progression.job_id == @novice_class

      assert Repo.get(Character, character.id).class == @novice_class
    end
  end

  defp insert_novice do
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

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
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
      })
      |> Repo.insert()

    character
  end
end
