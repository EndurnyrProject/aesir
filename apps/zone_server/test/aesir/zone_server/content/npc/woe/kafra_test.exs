defmodule Aesir.ZoneServer.Content.Npc.Woe.KafraTest do
  @moduledoc """
  Covers the Task 3 castle Kafra: the 20 FE castle placements and the
  refusal/member dialog paths driven through `Script.Interaction` (unowned
  castle, non-member guild, storage, teleport, and pushcart rental).
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Net.Cutin
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Content.Npc.Woe.Kafra
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @gid 0x5300_0001

  @fe_castle_maps ~w(
    aldeg_cas01 aldeg_cas02 aldeg_cas03 aldeg_cas04 aldeg_cas05
    gefg_cas01 gefg_cas02 gefg_cas03 gefg_cas04 gefg_cas05
    payg_cas01 payg_cas02 payg_cas03 payg_cas04 payg_cas05
    prtg_cas01 prtg_cas02 prtg_cas03 prtg_cas04 prtg_cas05
  )

  @cell_dir %{
    "aldeg_cas01" => {218, 170, 0},
    "aldeg_cas02" => {84, 74, 0},
    "aldeg_cas03" => {118, 76, 0},
    "aldeg_cas04" => {45, 88, 0},
    "aldeg_cas05" => {31, 190, 0},
    "gefg_cas01" => {83, 47, 3},
    "gefg_cas02" => {23, 66, 3},
    "gefg_cas03" => {116, 89, 5},
    "gefg_cas04" => {59, 70, 3},
    "gefg_cas05" => {61, 52, 5},
    "payg_cas01" => {128, 58, 3},
    "payg_cas02" => {22, 275, 5},
    "payg_cas03" => {9, 263, 5},
    "payg_cas04" => {40, 235, 1},
    "payg_cas05" => {276, 227, 1},
    "prtg_cas01" => {96, 173, 0},
    "prtg_cas02" => {71, 36, 4},
    "prtg_cas03" => {181, 215, 4},
    "prtg_cas04" => {258, 247, 4},
    "prtg_cas05" => {52, 41, 4}
  }

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    :ok
  end

  test "declares one placement per FE castle map, sprite 117, cells and dirs matching the table" do
    placements = Kafra.spawn()

    assert length(placements) == 20
    assert placements |> Enum.map(& &1.map) |> Enum.sort() == Enum.sort(@fe_castle_maps)
    assert Enum.all?(placements, &(&1.sprite == 117))

    unique_names = Enum.map(placements, & &1.unique_name)
    assert Enum.uniq(unique_names) == unique_names
    assert Enum.all?(unique_names, &String.starts_with?(&1, "Kafra Employee#"))

    for placement <- placements do
      assert placement.unique_name == "Kafra Employee##{placement.map}"
      assert {placement.x, placement.y, placement.dir} == Map.fetch!(@cell_dir, placement.map)
    end
  end

  test "an unowned castle ends after the refusal naming the guild, no select" do
    castle = first_castle()
    ctx = build_ctx(map_name: castle.map)

    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "Guild. Please try another Kafra Employee"
    assert_clean_exit(ref, pid)
  end

  test "a non-member of the owning guild ends after the refusal naming the owner guild" do
    castle = first_castle()
    :ok = CastleStore.hydrate(%{castle.id => row(5)})

    stub(GuildManager, :get, fn 5 ->
      {:ok, %GuildState{guild_id: 5, name: "Baldur Guard", master_char_id: 1}}
    end)

    ctx = build_ctx(map_name: castle.map, guild_id: 7, char_id: 2)

    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "Baldur Guard"
    assert text =~ "Guild. Please try another Kafra Employee"
    assert_clean_exit(ref, pid)
  end

  test "an owning-guild member reaches the four-entry menu" do
    castle = first_castle()
    :ok = CastleStore.hydrate(%{castle.id => row(5)})

    stub(GuildManager, :get, fn 5 ->
      {:ok, %GuildState{guild_id: 5, name: "Baldur Guard", master_char_id: 1}}
    end)

    ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)
    {:ok, pid} = start_interaction(ctx)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}

    assert options == [
             "Use Storage",
             "Use Teleport Service",
             "Rent a Pushcart",
             "Cancel"
           ]
  end

  describe "Storage" do
    test "basic skill too low ends with a refusal and no openstorage op" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      test_pid = self()
      stub(PlayerSession, :script_apply, fn _pid, op -> send(test_pid, {:script_apply, op}) end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      choose_menu(pid, 1)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "Basic Skill Level 6"
      assert_clean_exit(ref, pid)

      refute_received {:script_apply, {:openstorage}}
    end

    test "with the basic skill, opens storage through the session" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      test_pid = self()

      stub(PlayerSession, :script_apply, fn _pid, {:openstorage} = op ->
        send(test_pid, {:script_apply, op})
        {:ok, build_game_state(map_name: castle.map, guild_id: 5, char_id: 1)}
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, novice_basic: 6)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      choose_menu(pid, 1)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "Thank you for using"
      assert_clean_exit(ref, pid)

      assert_received {:script_apply, {:openstorage}}
    end
  end

  describe "Teleport" do
    test "with 199 zeny ends with a refusal and zeny unchanged" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      test_pid = self()
      stub(PlayerSession, :script_apply, fn _pid, op -> send(test_pid, {:script_apply, op}) end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, zeny: 199)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      choose_menu(pid, 2)
      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}
      assert [town_option, "Cancel"] = options
      assert town_option =~ "-> 200z"

      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "don't have"
      assert_clean_exit(ref, pid)

      refute_received {:script_apply, {:pay_zeny, 200}}
    end

    test "with 200 zeny pays and warps to the prefix's town cell" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      test_pid = self()

      stub(PlayerSession, :script_apply, fn _pid, op ->
        send(test_pid, {:script_apply, op})
        {:ok, build_game_state(map_name: castle.map, guild_id: 5, char_id: 1, zeny: 0)}
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, zeny: 200)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      choose_menu(pid, 2)
      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})
      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}

      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

      assert_clean_exit(ref, pid)
      assert_received {:script_apply, {:pay_zeny, 200}}
      town = expected_town(castle.map)
      assert_received {:script_apply, {:warp, ^town, _x, _y}}
    end
  end

  describe "Cart" do
    test "without the pushcart skill ends with a merchant-only refusal" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      choose_menu(pid, 3)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "only available to Merchants"
      assert_clean_exit(ref, pid)
    end

    test "already having a cart ends with an already-equipped refusal" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      ctx =
        build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, pushcart_lv: 1, cart_type: 1)

      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      choose_menu(pid, 3)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "already have"
      assert_clean_exit(ref, pid)
    end

    test "with the skill and 800 zeny pays, sets the cart, and resets the cutin" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      test_pid = self()

      stub(PlayerSession, :script_apply, fn _pid, op ->
        send(test_pid, {:script_apply, op})
        {:ok, build_game_state(map_name: castle.map, guild_id: 5, char_id: 1, zeny: 0)}
      end)

      stub(Broadcast, :to_player, fn _char_id, packet ->
        send(test_pid, {:broadcast, packet})
      end)

      ctx =
        build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, pushcart_lv: 1, zeny: 800)

      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      choose_menu(pid, 3)
      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

      assert_receive {:send, _ch,
                      {:npc_dialog,
                       %NpcDialog{expect: :MENU, options: ["Rent a Pushcart.", "Cancel"]}}}

      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

      assert_clean_exit(ref, pid)
      assert_received {:script_apply, {:pay_zeny, 800}}
      assert_received {:script_apply, {:setcart, 1}}
      assert_received {:broadcast, %Cutin{image: "", type: 255}}
    end
  end

  defp choose_menu(pid, choice) do
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, choice}}})
  end

  defp expected_town("aldeg" <> _), do: "aldebaran"
  defp expected_town("gefg" <> _), do: "geffen"
  defp expected_town("payg" <> _), do: "payon"
  defp expected_town("prtg" <> _), do: "prontera"

  defp guild(id), do: %GuildState{guild_id: id, name: "Baldur Guard", master_char_id: 1}

  defp first_castle, do: CastleDb.all() |> hd()

  defp row(guild_id, overrides \\ %{}) do
    Map.merge(
      %{
        guild_id: guild_id,
        economy: 0,
        defense: 0,
        invested_economy: 0,
        invested_defense: 0,
        guardians: []
      },
      overrides
    )
  end

  defp assert_clean_exit(ref, pid) do
    assert_receive {:DOWN, ^ref, :process, ^pid, reason}, 500
    assert reason in [:normal, :noproc]
  end

  defp start_interaction(ctx), do: Interaction.start(self(), Kafra, ctx)

  defp build_ctx(opts) do
    %Ctx{
      char_id: Keyword.get(opts, :char_id, 1),
      account_id: 100,
      connection_pid: self(),
      game_state: build_game_state(opts),
      source: {:npc, :kafra_test},
      npc_gid: @gid
    }
  end

  defp build_game_state(opts) do
    {:ok, %{id: pushcart_id}} = Catalog.by_name(:mc_pushcart)

    novice_basic = Keyword.get(opts, :novice_basic, 0)
    pushcart_lv = Keyword.get(opts, :pushcart_lv, 0)

    learned_skills =
      %{1 => novice_basic, pushcart_id => pushcart_lv}
      |> Map.reject(fn {_id, lv} -> lv == 0 end)

    %PlayerState{
      character_id: Keyword.get(opts, :char_id, 1),
      character_name: "TestMember",
      account_id: 100,
      map_name: Keyword.fetch!(opts, :map_name),
      guild_id: Keyword.get(opts, :guild_id, 0),
      zeny: Keyword.get(opts, :zeny, 0),
      cart_type: Keyword.get(opts, :cart_type, 0),
      stats: %Stats{progression: %PlayerProgression{learned_skills: learned_skills}}
    }
  end
end
