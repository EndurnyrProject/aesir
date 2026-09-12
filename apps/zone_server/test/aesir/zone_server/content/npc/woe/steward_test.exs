defmodule Aesir.ZoneServer.Content.Npc.Woe.StewardTest do
  @moduledoc """
  Covers the Task 10 castle steward: the 20 FE castle placements, the
  refusal/greeting dialog paths driven through `Script.Interaction` (unowned
  castle, non-master member, the master reaching the briefing), and the
  Summon Guardian menu (slot listing, already-summoned, research-required,
  insufficient-funds, and successful hire).
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
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Services
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
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

  test "the master reaches the six-entry select and briefing shows the seeded values" do
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
             "Invest in Castle Defenses",
             "Summon Guardian",
             "Hire / Fire a Kafra Employee",
             "Go into Master's room"
           ]

    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "12"
    assert text =~ "34"
  end

  describe "Summon Guardian" do
    test "shows a nine-entry select with the slot types in order and the summoned marker" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5, %{guardians: [0]})})

      stub(GuildManager, :get, fn 5 ->
        {:ok, %GuildState{guild_id: 5, name: "Baldur Guard", master_char_id: 1}}
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      options = reach_guardian_menu(pid)

      expected =
        castle.guardians
        |> Enum.with_index()
        |> Enum.map(fn {slot_def, slot} ->
          type_label(slot_def.type) <> if slot == 0, do: " (Summoned)", else: ""
        end)

      assert options == expected ++ ["Cancel"]

      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 9}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "I'll do as you bid"
      assert_clean_exit(ref, pid)
    end

    test "picking a summoned slot and confirming ends with the already-summoned line" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5, %{guardians: [0]})})
      stub(GuildManager, :get, fn 5 -> {:ok, researched_guild(5)} end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      reach_guardian_menu(pid)
      choose_guardian(pid, 1)
      confirm_summon(pid)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "you already have summoned that Guardian"
      assert_clean_exit(ref, pid)
    end

    test "picking an empty slot with no research ends with the research line after confirming" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})

      stub(GuildManager, :get, fn 5 ->
        {:ok, %GuildState{guild_id: 5, name: "Baldur Guard", master_char_id: 1}}
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      reach_guardian_menu(pid)
      choose_guardian(pid, 1)
      confirm_summon(pid)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "we have not the resources to Summon the Guardian"
      assert_clean_exit(ref, pid)
    end

    test "confirming an empty slot with research but insufficient zeny ends with the funds line" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, researched_guild(5)} end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, zeny: 5_000)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      reach_guardian_menu(pid)
      choose_guardian(pid, 1)
      confirm_summon(pid)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "we don't have funds to summon the Guardian"
      assert_clean_exit(ref, pid)
    end

    test "confirming an empty slot with research and enough zeny completes the hire" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, researched_guild(5)} end)
      stub(Persistence, :persist_guardians, fn _castle_id, _guardians -> :ok end)

      test_pid = self()

      stub(PlayerSession, :script_apply, fn _pid, {:pay_zeny, 10_000} = op ->
        send(test_pid, {:script_apply, op})
        {:ok, %{build_game_state(map_name: castle.map, guild_id: 5, char_id: 1) | zeny: 10_000}}
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, zeny: 20_000)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      reach_guardian_menu(pid)
      choose_guardian(pid, 1)
      confirm_summon(pid)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "We completed the summoning of the Guardian"
      assert_clean_exit(ref, pid)

      assert_received {:script_apply, {:pay_zeny, 10_000}}
      assert 0 in CastleStore.guardians(castle.id)
    end
  end

  describe "Kafra Service" do
    test "not hired, no contract: refusal, zeny unchanged, hire_kafra not applied" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      test_pid = self()

      stub(Services, :hire_kafra, fn castle_id, guild_id ->
        send(test_pid, {:hire_kafra, castle_id, guild_id})
        :ok
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, zeny: 20_000)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      assert reach_kafra_offer(pid) == ["Hire.", "Cancel"]
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "we can't hire a Kafra Employee"
      assert_clean_exit(ref, pid)

      refute_received {:hire_kafra, _castle_id, _guild_id}
    end

    test "not hired, contracted but 9,999 zeny: refusal without hiring" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, contracted_guild(5)} end)

      test_pid = self()

      stub(Services, :hire_kafra, fn castle_id, guild_id ->
        send(test_pid, {:hire_kafra, castle_id, guild_id})
        :ok
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, zeny: 9_999)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      reach_kafra_offer(pid)
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "don't have enough funds"
      assert_clean_exit(ref, pid)

      refute_received {:hire_kafra, _castle_id, _guild_id}
    end

    test "not hired, contracted with 10,000 zeny: pays, hires once, shows the hired dialog" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, contracted_guild(5)} end)

      test_pid = self()

      stub(Services, :hire_kafra, fn castle_id, guild_id ->
        send(test_pid, {:hire_kafra, castle_id, guild_id})
        :ok
      end)

      stub(PlayerSession, :script_apply, fn _pid, {:pay_zeny, 10_000} = op ->
        send(test_pid, {:script_apply, op})
        {:ok, %{build_game_state(map_name: castle.map, guild_id: 5, char_id: 1) | zeny: 0}}
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, zeny: 10_000)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      reach_kafra_offer(pid)
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "Contract terms"
      assert_clean_exit(ref, pid)

      assert_received {:script_apply, {:pay_zeny, 10_000}}
      castle_id = castle.id
      assert_received {:hire_kafra, ^castle_id, 5}
    end

    test "hired: Fire then Cancel keeps her without firing" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      :ok = CastleStore.put_kafra(castle.id, true)
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      test_pid = self()

      stub(Services, :fire_kafra, fn castle_id, guild_id ->
        send(test_pid, {:fire_kafra, castle_id, guild_id})
        :ok
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      assert reach_kafra_offer(pid) == ["Fire", "Cancel"]
      confirm_fire_menu(pid)
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 2}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "I'll work hard for you"
      assert_clean_exit(ref, pid)

      refute_received {:fire_kafra, _castle_id, _guild_id}
    end

    test "hired: Fire then Fire calls fire_kafra/2 once" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      :ok = CastleStore.put_kafra(castle.id, true)
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      test_pid = self()

      stub(Services, :fire_kafra, fn castle_id, guild_id ->
        send(test_pid, {:fire_kafra, castle_id, guild_id})
        :ok
      end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      reach_kafra_offer(pid)
      confirm_fire_menu(pid)
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "I have discharged the Kafra Employee"
      assert_clean_exit(ref, pid)

      castle_id = castle.id
      assert_received {:fire_kafra, ^castle_id, 5}
    end
  end

  describe "Master's room" do
    test "choice 1 warps to the castle's master room for every steward placement" do
      for placement <- Steward.spawn() do
        gid = NpcRegistry.entity_id(placement)
        castle = Enum.find(CastleDb.all(), &(&1.map == placement.map))
        :ok = CastleStore.hydrate(%{castle.id => row(5)})
        stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

        test_pid = self()

        stub(PlayerSession, :script_apply, fn _pid, {:warp, _map, _x, _y} = op ->
          send(test_pid, {:script_apply, op})
          {:ok, build_game_state(map_name: castle.map, guild_id: 5, char_id: 1)}
        end)

        ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1, npc_gid: gid)
        {:ok, pid} = start_interaction(ctx)
        ref = Process.monitor(pid)

        reach_master_room_offer(pid, gid)
        send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 1}}})

        assert_clean_exit(ref, pid)

        {x, y} = master_room(placement.map)
        assert_received {:script_apply, {:warp, map, ^x, ^y}}
        assert map == placement.map
      end
    end

    test "choice 2 closes without a warp" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      stub(GuildManager, :get, fn 5 -> {:ok, guild(5)} end)

      test_pid = self()
      stub(PlayerSession, :script_apply, fn _pid, op -> send(test_pid, {:script_apply, op}) end)

      ctx = build_ctx(map_name: castle.map, guild_id: 5, char_id: 1)
      {:ok, pid} = start_interaction(ctx)
      ref = Process.monitor(pid)

      reach_master_room_offer(pid)
      send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 2}}})

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "produced once a day"
      assert_clean_exit(ref, pid)

      refute_received {:script_apply, {:warp, _map, _x, _y}}
    end
  end

  defp reach_kafra_offer(pid) do
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 5}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}
    options
  end

  defp confirm_fire_menu(pid) do
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:send, _ch,
                    {:npc_dialog, %NpcDialog{expect: :MENU, options: ["Fire", "Cancel"]}}}
  end

  defp reach_master_room_offer(pid, gid \\ @gid) do
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 6}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}
    options
  end

  defp master_room("aldeg_cas01"), do: {113, 223}
  defp master_room("aldeg_cas02"), do: {134, 225}
  defp master_room("aldeg_cas03"), do: {229, 267}
  defp master_room("aldeg_cas04"), do: {83, 17}
  defp master_room("aldeg_cas05"), do: {64, 8}
  defp master_room("gefg_cas01"), do: {152, 117}
  defp master_room("gefg_cas02"), do: {145, 115}
  defp master_room("gefg_cas03"), do: {275, 289}
  defp master_room("gefg_cas04"), do: {116, 123}
  defp master_room("gefg_cas05"), do: {149, 106}
  defp master_room("payg_cas01"), do: {295, 8}
  defp master_room("payg_cas02"), do: {141, 149}
  defp master_room("payg_cas03"), do: {163, 167}
  defp master_room("payg_cas04"), do: {151, 47}
  defp master_room("payg_cas05"), do: {153, 137}
  defp master_room("prtg_cas01"), do: {15, 209}
  defp master_room("prtg_cas02"), do: {207, 229}
  defp master_room("prtg_cas03"), do: {190, 130}
  defp master_room("prtg_cas04"), do: {275, 160}
  defp master_room("prtg_cas05"), do: {281, 176}

  defp guild(id), do: %GuildState{guild_id: id, name: "Baldur Guard", master_char_id: 1}

  defp contracted_guild(id),
    do: %GuildState{
      guild_id: id,
      name: "Baldur Guard",
      master_char_id: 1,
      learned_skills: %{10_001 => 1}
    }

  defp reach_guardian_menu(pid) do
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 4}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}
    options
  end

  defp choose_guardian(pid, choice) do
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, choice}}})

    assert_receive {:send, _ch,
                    {:npc_dialog, %NpcDialog{expect: :MENU, options: ["Summon", "Cancel"]}}}
  end

  defp confirm_summon(pid) do
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 1}}})
  end

  defp type_label(:soldier), do: "Guardian Soldier"
  defp type_label(:archer), do: "Guardian Archer"
  defp type_label(:knight), do: "Guardian Knight"

  defp researched_guild(id),
    do: %GuildState{
      guild_id: id,
      name: "Baldur Guard",
      master_char_id: 1,
      learned_skills: %{10_002 => 1}
    }

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

  defp start_interaction(ctx), do: Interaction.start(self(), Steward, ctx)

  defp build_ctx(opts) do
    %Ctx{
      char_id: Keyword.get(opts, :char_id, 1),
      account_id: 100,
      connection_pid: self(),
      game_state: build_game_state(opts),
      source: {:npc, :steward_test},
      npc_gid: Keyword.get(opts, :npc_gid, @gid)
    }
  end

  defp build_game_state(opts) do
    %PlayerState{
      character_id: Keyword.get(opts, :char_id, 1),
      character_name: "TestMaster",
      account_id: 100,
      map_name: Keyword.fetch!(opts, :map_name),
      guild_id: Keyword.get(opts, :guild_id, 0),
      zeny: Keyword.get(opts, :zeny, 0)
    }
  end
end
