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

  @moduletag :integration

  @moduletag :capture_log

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Npc.Transpiler.Codegen
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Script.NotImplementedError
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @jellopy 909
  @char_id 9101
  @gid 0x5000_0099

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
    def handle_call({:script_apply, op}, _from, state) do
      {reply, new_state} = ScriptEffectHandler.apply_op(op, state)
      {:reply, reply, new_state}
    end

    @impl true
    def handle_call(:game_state, _from, state), do: {:reply, state.game_state, state}
  end

  setup :set_mimic_global
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
    %{npc_module: module}
  end

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(InventoryOps)
    Mimic.copy(Items)

    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)

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

  defp talk(module, opts) do
    game_state = %PlayerState{
      character_id: @char_id,
      account_id: 9100,
      zeny: Keyword.fetch!(opts, :zeny),
      vars: %{},
      temp_vars: %{},
      inventory: %{},
      stats: stats()
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

  defp stats do
    %Aesir.ZoneServer.Unit.Player.Stats{
      current_state: %Aesir.ZoneServer.Unit.Stats.CurrentState{hp: 100, sp: 10},
      derived_stats: %Aesir.ZoneServer.Unit.Stats.DerivedStats{
        max_hp: 500,
        max_sp: 200,
        aspd: 150
      },
      progression: %Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression{
        base_level: 50,
        job_level: 10,
        job_id: 0
      }
    }
  end
end
