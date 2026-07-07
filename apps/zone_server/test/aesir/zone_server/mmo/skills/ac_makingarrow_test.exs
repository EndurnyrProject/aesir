defmodule Aesir.ZoneServer.Mmo.Skills.AcMakingarrowTest do
  @moduledoc """
  Drives the real Arrow Crafting dialog through the real interaction runtime:
  `on_talk/1` runs in a supervised `Script.Interaction`, dialog frames land in
  the test mailbox (the ctx's `connection_pid`), and the crafting ops route
  through a minimal session GenServer that records each `{:script_apply, op}`.
  Only real data is used (arrows.yml + the item catalog).
  """
  use ExUnit.Case, async: false

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AcMakingarrow
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # Branch of Dead Tree -> 40 Mute Arrows (arrows.yml, imported from rAthena).
  @source_id 604
  @product_id 1769
  @dialog_gid 0x6000_0000

  # Records every script op in the test mailbox and leaves the game state
  # untouched; the dialog only reads the inventory before its select.
  defmodule Session do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

    @impl true
    def init({game_state, test_pid}), do: {:ok, {game_state, test_pid}}

    @impl true
    def handle_call({:script_apply, op}, _from, {game_state, test_pid} = state) do
      send(test_pid, {:script_op, op})
      {:reply, {:ok, game_state}, state}
    end
  end

  setup do
    game_state = %PlayerState{
      character_id: 9001,
      account_id: 9000,
      inventory: %{0 => %InventoryItem{nameid: @source_id, amount: 3}}
    }

    {:ok, session_pid} = Session.start_link({game_state, self()})
    %{game_state: game_state, session_pid: session_pid}
  end

  defp start_dialog(game_state, session_pid) do
    ctx =
      Ctx.from_session(
        %{game_state: game_state, connection_pid: self()},
        {:npc, AcMakingarrow}
      )

    {:ok, pid} = Interaction.start(session_pid, AcMakingarrow, %{ctx | npc_gid: @dialog_gid})
    ref = Process.monitor(pid)
    {pid, ref}
  end

  defp interact(pid, response) do
    send(pid, {:npc_interact, %NpcInteract{npc_id: @dialog_gid, response: response}})
  end

  describe "catalog registration & metadata" do
    test "matches the rAthena table" do
      assert {:ok, %{name: :ac_makingarrow}} = Catalog.by_id(147)
      assert {:ok, AcMakingarrow} = Catalog.active_module_for(:ac_makingarrow)

      d = AcMakingarrow.definition()
      assert d.max_level == 1
      assert d.target_type == :self
      assert d.damage_type == :no_damage
      assert d.sp_cost == [10]
    end
  end

  describe "cast/4" do
    test "stages the crafting dialog on pending_interaction" do
      caster = %PlayerState{character_id: 9001}
      {:ok, definition} = Catalog.by_name(:ac_makingarrow)

      assert {:ok, %PlayerState{pending_interaction: AcMakingarrow}} =
               AcMakingarrow.cast(caster, :self, 1, definition)
    end
  end

  describe "on_talk/1" do
    test "lists held materials, crafts the choice, and closes",
         %{game_state: game_state, session_pid: session_pid} do
      {pid, ref} = start_dialog(game_state, session_pid)

      {:ok, %{name: source_name}} = ItemManagement.get_item_by_id(@source_id)
      assert_receive {:send, _, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}
      assert options == [source_name]

      interact(pid, {:choice, 1})

      assert_receive {:script_op, {:delitem, @source_id, 1}}
      assert_receive {:script_op, {:give_item, @product_id, 40}}
      assert_receive {:send, _, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "40x"
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end

    test "closes with a notice when no material is held", %{session_pid: session_pid} do
      {pid, ref} = start_dialog(%PlayerState{character_id: 9001, account_id: 9000}, session_pid)

      assert_receive {:send, _, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
      assert text =~ "no materials"
      refute_received {:script_op, _}
      # The dialog closes without ever suspending, so the process may already
      # be gone when the monitor attaches (:noproc instead of :normal).
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    end

    test "an out-of-range choice crafts nothing",
         %{game_state: game_state, session_pid: session_pid} do
      {pid, ref} = start_dialog(game_state, session_pid)

      assert_receive {:send, _, {:npc_dialog, %NpcDialog{expect: :MENU}}}
      interact(pid, {:choice, 99})

      assert_receive {:send, _, {:npc_dialog, %NpcDialog{expect: :CLOSE}}}
      refute_received {:script_op, _}
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end

    test "cancel ends the interaction without crafting",
         %{game_state: game_state, session_pid: session_pid} do
      {pid, ref} = start_dialog(game_state, session_pid)

      assert_receive {:send, _, {:npc_dialog, %NpcDialog{expect: :MENU}}}
      interact(pid, {:cancel, true})

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      refute_received {:script_op, _}
    end
  end
end
