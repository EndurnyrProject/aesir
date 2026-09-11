defmodule Aesir.ZoneServer.Content.Npc.Woe.StewardTest do
  @moduledoc """
  Covers the Task 10 castle steward: the 20 FE castle placements, and the
  three refusal/greeting dialog paths driven through `Script.Interaction`
  (unowned castle, non-master member, and the master reaching the briefing).
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Content.Npc.Woe.Steward
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @gid 0x5200_0001

  @fe_castle_maps ~w(
    aldeg_cas01 aldeg_cas02 aldeg_cas03 aldeg_cas04 aldeg_cas05
    gefg_cas01 gefg_cas02 gefg_cas03 gefg_cas04 gefg_cas05
    payg_cas01 payg_cas02 payg_cas03 payg_cas04 payg_cas05
    prtg_cas01 prtg_cas02 prtg_cas03 prtg_cas04 prtg_cas05
  )

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    :ok
  end

  test "declares one placement per FE castle map, all unique and on sprite 55" do
    placements = Steward.spawn()

    assert length(placements) == 20
    assert placements |> Enum.map(& &1.map) |> Enum.sort() == Enum.sort(@fe_castle_maps)
    assert Enum.all?(placements, &(&1.sprite == 55))

    unique_names = Enum.map(placements, & &1.unique_name)
    assert Enum.uniq(unique_names) == unique_names
  end

  test "an unowned castle ends after the no-master lines without a select" do
    castle = first_castle()
    ctx = build_ctx(map_name: castle.map)

    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "waiting for a master"
    assert_clean_exit(ref, pid)
  end

  test "a non-master member of the owning guild ends after the dismissal lines" do
    castle = first_castle()
    :ok = CastleStore.hydrate(%{castle.id => row(5)})

    stub(GuildManager, :get, fn 5 ->
      {:ok, %GuildState{guild_id: 5, name: "Baldur Guard", master_char_id: 999}}
    end)

    ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)

    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "I'll still follow my master"
    assert_clean_exit(ref, pid)
  end

  test "the master reaches the three-entry select and briefing shows the seeded values" do
    castle = first_castle()

    :ok =
      CastleStore.hydrate(%{
        castle.id => row(5, %{economy: 12, defense: 34, invested_economy: 1, invested_defense: 0})
      })

    stub(GuildManager, :get, fn 5 ->
      {:ok, %GuildState{guild_id: 5, name: "Baldur Guard", master_char_id: 1}}
    end)

    ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)

    {:ok, pid} = start_interaction(ctx)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}

    assert options == [
             "Castle briefing",
             "Invest in commercial growth",
             "Invest in Castle Defenses"
           ]

    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "12"
    assert text =~ "34"
  end

  defp first_castle, do: CastleDb.all() |> hd()

  defp row(guild_id, overrides \\ %{}) do
    Map.merge(
      %{guild_id: guild_id, economy: 0, defense: 0, invested_economy: 0, invested_defense: 0},
      overrides
    )
  end

  defp assert_clean_exit(ref, pid) do
    assert_receive {:DOWN, ^ref, :process, ^pid, reason}, 500
    assert reason in [:normal, :noproc]
  end

  defp start_interaction(ctx), do: Interaction.start(self(), Steward, ctx)

  defp build_ctx(opts) do
    %Ctx{
      char_id: Keyword.get(opts, :char_id, 1),
      account_id: 100,
      connection_pid: self(),
      game_state: build_game_state(opts),
      source: {:npc, :steward_test},
      npc_gid: @gid
    }
  end

  defp build_game_state(opts) do
    %PlayerState{
      character_id: Keyword.get(opts, :char_id, 1),
      character_name: "TestMaster",
      account_id: 100,
      map_name: Keyword.fetch!(opts, :map_name),
      guild_id: Keyword.get(opts, :guild_id, 0)
    }
  end
end
