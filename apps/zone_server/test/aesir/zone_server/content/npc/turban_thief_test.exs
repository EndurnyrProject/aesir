defmodule Aesir.ZoneServer.Content.Npc.Morocc.TurbanThiefTest do
  @moduledoc """
  End-to-end Sphinx Mask quest: drives the real `Turban Thief` through the real
  interaction runtime by sending the `NpcInteract` messages a client would, and
  routes its `{:npc, {:script_apply, op}}` calls through a session that genuinely applies
  them via the production `ScriptEffectHandler.apply_op/2`.

  The interaction process, dialog DSL, registry, verifier, and effect seam are
  all real; only the I/O leaves are stubbed (the same collaborators
  `ScriptEffectHandlerTest` stubs): `CharacterPersistence` (DB write-through),
  `InventoryOps` (inventory row persistence), and `Items` (item catalog lookup).

  MAP NOTE: the Turban Thief spawns on the rAthena cell `morocc (208,90)`. Our
  map cache has no `morocc` town map yet, but the verifier no longer requires a
  walkable/loaded cell (NPCs are objects) — it only rejects cell collisions — so
  the placement verifies fine. The interaction scenarios below drive the runtime
  directly and don't depend on the map being loaded.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Content.Npc.Morocc.TurbanThief
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Npc.Verifier
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @reward_item_id 7114
  @char_id 9001
  @account_id 9000

  # A real, minimal player session: the single writer that genuinely applies
  # every {:script_apply, op} against its own PlayerState via the production
  # ScriptEffectHandler. connection_pid is the controlling test process, so the
  # client-bound protos land in its mailbox as {:send, _, _} tuples.
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

  # Global mode: the stubbed I/O leaves are called from the spawned Session and
  # Interaction processes, not the test process, so the stubs must cross process
  # boundaries. Safe because this suite is async: false.
  setup {Aesir.MimicMode, :global}
  setup :verify_on_exit!

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(InventoryOps)
    Mimic.copy(Items)

    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)

    stub(Items, :by_id, fn @reward_item_id ->
      {:ok,
       %ItemDefinition{
         id: @reward_item_id,
         aegis_name: "Tutankhamen's_Mask",
         name: "Masque of Tutankhamen",
         weight: 10
       }}
    end)

    stub(InventoryOps, :add, fn @char_id, inventory, _stats, definition, qty ->
      index = map_size(inventory)
      added = %InventoryItem{nameid: definition.id, amount: qty}
      {:ok, Map.put(inventory, index, added), {:added, index, added}}
    end)

    :ok
  end

  describe "registry + verifier (boot path)" do
    test "reload discovers the Turban Thief and resolves its spawn cell" do
      on_exit(fn -> :persistent_term.erase(Registry) end)
      Registry.reload([TurbanThief])

      assert {:ok, {TurbanThief, %Placement{map: "morocc", x: 208, y: 90, dir: 6}}} =
               Registry.module_at("morocc", 208, 90)
    end

    test "the verifier passes for the spawn cell (walkability not required)" do
      assert :ok = Verifier.verify([{TurbanThief, hd(TurbanThief.spawn())}])
    end
  end

  describe "first visit" do
    test "buying at the 500,000z tier debits, rewards 7114, sets sphmask_q" do
      {session, ctx} = start_quest(zeny: 600_000, vars: %{})
      pid = start_interaction(session, ctx)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: opts}}}
      assert opts == ["Pay 1,000,000z", "Pay 750,000z", "Pay 500,000z", "No deal"]

      choose(pid, 3)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "it's a deal"

      gs = game_state(session)
      assert gs.zeny == 100_000
      assert gs.inventory |> Map.values() |> Enum.any?(&(&1.nameid == @reward_item_id))
      assert gs.vars == %{"sphmask_q" => 1}
    end
  end

  describe "second visit (already completed)" do
    test "the one-time gate sends 'go away' with no menu and no reward" do
      {session, ctx} = start_quest(zeny: 600_000, vars: %{"sphmask_q" => 1})
      _pid = start_interaction(session, ctx)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "go away"
      refute_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}

      gs = game_state(session)
      assert gs.zeny == 600_000
      assert gs.inventory == %{}
      assert gs.vars == %{"sphmask_q" => 1}
    end
  end

  describe "insufficient zeny" do
    test "the chosen tier costs more than held: 'no money', nothing debited or given" do
      {session, ctx} = start_quest(zeny: 400_000, vars: %{})
      pid = start_interaction(session, ctx)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
      choose(pid, 3)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "money"

      gs = game_state(session)
      assert gs.zeny == 400_000
      assert gs.inventory == %{}
      assert gs.vars == %{}
    end
  end

  defp start_quest(opts) do
    game_state = %PlayerState{
      character_id: @char_id,
      account_id: @account_id,
      zeny: Keyword.fetch!(opts, :zeny),
      vars: Keyword.get(opts, :vars, %{}),
      temp_vars: %{},
      inventory: %{},
      stats: stats()
    }

    {:ok, session} = Session.start_link(%{connection_pid: self(), game_state: game_state})

    ctx = %Ctx{
      char_id: @char_id,
      account_id: @account_id,
      connection_pid: self(),
      game_state: game_state,
      source: {:npc, TurbanThief.npc_id()},
      npc_gid: npc_gid()
    }

    {session, ctx}
  end

  # Interaction.start/3 stamps ctx.session_pid + ctx.session_ref from its first
  # arg, so the DSL's {:script_apply, op} calls route to the real Session.
  defp start_interaction(session, ctx) do
    {:ok, pid} = Interaction.start(session, TurbanThief, ctx)
    pid
  end

  defp choose(pid, choice) do
    send(pid, {:npc_interact, %NpcInteract{npc_id: npc_gid(), response: {:choice, choice}}})
  end

  defp npc_gid, do: Registry.entity_id(hd(TurbanThief.spawn()))

  defp game_state(session), do: GenServer.call(session, :game_state)

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
