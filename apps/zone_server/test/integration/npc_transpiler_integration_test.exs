defmodule Aesir.ZoneServer.NpcTranspilerIntegrationTest do
  @moduledoc """
  End-to-end proof that transpiled rAthena NPC modules run on the real
  runtime: a fixture script is transpiled by `Codegen`, compiled, and driven
  through the real `Script.Interaction` process with the `NpcInteract`
  messages a client would send. `{:script_apply, op}` calls route to a
  session that genuinely applies them via the production
  `ScriptEffectHandler.apply_op/2` (same harness as the TurbanThief e2e).
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup
  import Bitwise

  @moduletag :integration

  @moduletag :capture_log

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Content.Npc.Functions.FGetplatinumskills
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFalcon
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Transpiler.Codegen
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Script.NotImplementedError
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @jellopy 909
  @char_id 9101
  @gid 0x5000_0099

  @falcon_fixture """
  if (checkfalcon() == 0) setfalcon 1;
  end;
  """

  @fixture """
  mes "[Test Vendor]";
  mes "Buy a Jellopy for 50z?";
  next;
  switch (select("Yes:No:Dance for me")) {
  case 1:
    if (Zeny < 50) {
      mes "No money!";
      close;
    }
    Zeny -= 50;
    getitem 909, 1;
    vendor_q = 1;
    mes "Enjoy!";
    close;
  case 2:
    close;
  case 3:
    showscript "I refuse.";
    close;
  }
  """

  defmodule Session do
    use GenServer

    def start_link(state), do: GenServer.start_link(__MODULE__, state)

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, state) do
      {reply, new_state} = ScriptEffectHandler.apply_op(op, state)
      {:reply, reply, new_state}
    end

    @impl true
    def handle_call(:game_state, _from, state), do: {:reply, state.game_state, state}
  end

  setup {Aesir.MimicMode, :global}
  setup :verify_on_exit!

  setup_all do
    {:ok, source} =
      Codegen.generate(@fixture, %{
        module: "Aesir.ZoneServer.NpcTranspilerIntegrationTest.TestVendor",
        kind: :script,
        source: "fixture.txt:1",
        spawns: [%{map: "prontera", x: 10, y: 10, dir: 0, sprite: 58, name: "Test Vendor"}],
        functions: %{}
      })

    [{module, _}] = Code.compile_string(source)

    {:ok, falcon_source} =
      Codegen.generate(@falcon_fixture, %{
        module: "Aesir.ZoneServer.NpcTranspilerIntegrationTest.TestFalcon",
        kind: :script,
        source: "falcon_fixture.txt:1",
        spawns: [%{map: "prontera", x: 11, y: 11, dir: 0, sprite: 58, name: "Test Falcon"}],
        functions: %{}
      })

    [{falcon_module, _}] = Code.compile_string(falcon_source)
    %{npc_module: module, falcon_module: falcon_module}
  end

  setup :setup_ets_tables

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(InventoryOps)
    Mimic.copy(Items)
    Mimic.copy(UnitRegistry)
    Mimic.copy(SpatialIndex)
    Mimic.copy(Broadcast)

    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)

    stub(UnitRegistry, :get_unit_info, fn _unit_type, unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{level: 50, base_level: 50, str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10}
       }}
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _game_state -> :ok end)

    stub(SpatialIndex, :get_unit_position, fn :player, @char_id -> {:ok, {10, 10, "prontera"}} end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)

    stub(Items, :by_id, fn @jellopy ->
      {:ok, %ItemDefinition{id: @jellopy, aegis_name: "Jellopy", name: "Jellopy", weight: 10}}
    end)

    stub(InventoryOps, :add, fn @char_id, inventory, _stats, definition, qty ->
      index = map_size(inventory)
      added = %InventoryItem{nameid: definition.id, amount: qty}
      {:ok, Map.put(inventory, index, added), {:added, index, added}}
    end)

    :ok
  end

  test "happy path: dialog, choice, zeny debit, item grant, char var", %{npc_module: module} do
    {session, pid} = talk(module, zeny: 100)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT, text: text}}}
    assert text =~ "[Test Vendor]"
    assert text =~ "Buy a Jellopy for 50z?"
    continue(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: opts}}}
    assert opts == ["Yes", "No", "Dance for me"]
    choose(pid, 1)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "Enjoy!"

    gs = GenServer.call(session, :game_state)
    assert gs.zeny == 50
    assert gs.inventory |> Map.values() |> Enum.any?(&(&1.nameid == @jellopy))
    assert gs.vars == %{"vendor_q" => 1}
  end

  test "poor path: the zeny guard closes without debiting", %{npc_module: module} do
    {session, pid} = talk(module, zeny: 10)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    continue(pid)
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    choose(pid, 1)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "No money!"

    gs = GenServer.call(session, :game_state)
    assert gs.zeny == 10
    assert gs.inventory == %{}
  end

  test "stub path: an unimplemented buildin raises and ends the interaction cleanly",
       %{npc_module: module} do
    {session, pid} = talk(module, zeny: 100)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    continue(pid)
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    choose(pid, 3)

    assert_receive {:DOWN, ^ref, :process, ^pid,
                    {%NotImplementedError{buildin: :showscript}, _stack}},
                   500

    assert Process.alive?(session)
    assert GenServer.call(session, :game_state).zeny == 100
  end

  test "the generated platinum function grants lineage skills idempotently without points" do
    game_state = %PlayerState{
      character_id: @char_id,
      account_id: 9100,
      zeny: 0,
      vars: %{},
      temp_vars: %{},
      inventory: %{},
      stats: stats(%{}, 11)
    }

    {:ok, session} = Session.start_link(%{connection_pid: self(), game_state: game_state})

    ctx = %Ctx{
      char_id: @char_id,
      account_id: 9100,
      connection_pid: self(),
      game_state: game_state,
      source: {:npc, 0},
      session_pid: session
    }

    assert {%Ctx{status: :ok} = ctx, nil} = FGetplatinumskills.call(ctx, [])

    gs = GenServer.call(session, :game_state)
    learned = gs.stats.progression.learned_skills

    assert learned[142] == 1
    assert learned[147] == 1
    assert learned[148] == 1
    assert learned[1009] == 1
    refute Map.has_key?(learned, 144)
    refute Map.has_key?(learned, 1001)
    assert gs.stats.progression.skill_point == 0
    assert_received {:send, _ch, {:skill_list, _list}}

    assert {%Ctx{status: :ok}, nil} = FGetplatinumskills.call(%{ctx | game_state: gs}, [])
    assert GenServer.call(session, :game_state).stats.progression.learned_skills == learned
  end

  test "attached Falcon script executes concrete checkfalcon and setfalcon calls", %{
    falcon_module: module
  } do
    {session, pid} = talk(module, zeny: 0, learned_skills: %{HtFalcon.definition().id => 1})
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 500

    game_state = GenServer.call(session, :game_state)
    assert (game_state.option &&& Option.id(:falcon)) != 0
    assert StatusStorage.has_status?(:player, @char_id, :sc_falcon)
  end

  defp talk(module, opts) do
    game_state = %PlayerState{
      character_id: @char_id,
      account_id: 9100,
      zeny: Keyword.fetch!(opts, :zeny),
      vars: %{},
      temp_vars: %{},
      inventory: %{},
      stats: stats(Keyword.get(opts, :learned_skills, %{}))
    }

    {:ok, session} = Session.start_link(%{connection_pid: self(), game_state: game_state})

    ctx = %Ctx{
      char_id: @char_id,
      account_id: 9100,
      connection_pid: self(),
      game_state: game_state,
      source: {:npc, module.npc_id()},
      npc_gid: @gid
    }

    {:ok, pid} = Interaction.start(session, module, ctx)
    {session, pid}
  end

  defp continue(pid),
    do: send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

  defp choose(pid, choice),
    do: send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, choice}}})

  defp stats(learned_skills, class \\ 0) do
    %Character{
      id: @char_id,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      pow: 0,
      sta: 0,
      wis: 0,
      spl: 0,
      con: 0,
      crt: 0,
      base_level: 50,
      job_level: 10,
      base_exp: 0,
      job_exp: 0,
      class: class,
      skill_point: 0,
      status_point: 0,
      trait_point: 0,
      hp: 100,
      sp: 10,
      ap: 0,
      option: 0,
      learned_skills: learned_skills
    }
    |> Aesir.ZoneServer.Unit.Player.Stats.from_character()
  end
end
