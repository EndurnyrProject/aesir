defmodule Aesir.ZoneServer.Script.DslNpcBuildinsTest do
  @moduledoc """
  Covers the rAthena buildins `getvariableofnpc` (cross-NPC `.` variable
  read/write), `ismounting` (riding-bit read) and `attachrid` (re-attach the
  script to a different online player).
  """

  use ExUnit.Case, async: false

  @moduletag :capture_log

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule VarTargetNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{
          map: "prontera",
          x: 70,
          y: 70,
          sprite: 58,
          name: "VarTarget",
          unique_name: "VarTargetNpc"
        }
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule StubSession do
    use GenServer

    def start_link(_opts), do: GenServer.start_link(__MODULE__, nil)

    @impl true
    def init(_), do: {:ok, nil}
  end

  setup :setup_ets_tables

  setup do
    NpcRegistry.reload([VarTargetNpc])
    :ok
  end

  defp ctx do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: self(),
      game_state: %PlayerState{character_id: 1, account_id: 100},
      source: {:npc, :caller_npc}
    }
  end

  describe "getvariableofnpc" do
    test "round-trips another NPC's . variable by name" do
      assert %Ctx{} = Dsl.set_npc_var_of(ctx(), "counter", "VarTargetNpc", 7)
      assert Dsl.get_npc_var_of(ctx(), "counter", "VarTargetNpc", 0) == 7
    end

    test "reads a string var (trailing $) and defaults an unset one" do
      assert Dsl.get_npc_var_of(ctx(), "name$", "VarTargetNpc", "") == ""

      Dsl.set_npc_var_of(ctx(), "name$", "VarTargetNpc", "Spring")
      assert Dsl.get_npc_var_of(ctx(), "name$", "VarTargetNpc", "") == "Spring"
    end

    test "is isolated from the calling NPC's own . scope" do
      Dsl.set_npc_var_of(ctx(), "counter", "VarTargetNpc", 7)
      assert Dsl.get_npc_var(ctx(), "counter", 0) == 0
    end

    test "returns the default for an unknown NPC" do
      assert Dsl.get_npc_var_of(ctx(), "counter", "NoSuchNpc", 42) == 42
    end

    test "an unknown-NPC write no-ops and returns the ctx" do
      assert %Ctx{} = Dsl.set_npc_var_of(ctx(), "counter", "NoSuchNpc", 9)
      assert Dsl.get_npc_var_of(ctx(), "counter", "NoSuchNpc", 0) == 0
    end
  end

  describe "ismounting" do
    test "reads the riding option bit" do
      mounted = %{ctx() | game_state: %{ctx().game_state | option: Option.id(:riding)}}
      assert Dsl.ismounting(mounted) == 1
      assert Dsl.ismounting(ctx()) == 0
    end

    test "reports 0 on a detached ctx" do
      assert Dsl.ismounting(%{ctx() | game_state: nil}) == 0
    end
  end

  describe "attachrid" do
    test "re-points ctx at the target online player" do
      target_gs = %PlayerState{character_id: 7, account_id: 777}
      target_pid = start_supervised!({StubSession, nil})
      UnitRegistry.register_player(target_gs, target_pid)

      {attached, ok} = Dsl.attachrid(ctx(), 777)

      assert ok == 1
      assert attached.char_id == 7
      assert attached.account_id == 777
      assert attached.session_pid == target_pid
      assert attached.game_state.character_id == 7
      assert attached.connection_pid == nil
      assert attached.source == {:npc, :caller_npc}
    end

    test "returns {ctx, 0} for an offline account" do
      {unchanged, ok} = Dsl.attachrid(ctx(), 999_999)

      assert ok == 0
      assert unchanged.char_id == 1
      assert unchanged.account_id == 100
      assert unchanged.session_pid == self()
    end

    test "defaults force to true via attachrid/2" do
      target_gs = %PlayerState{character_id: 8, account_id: 888}
      target_pid = start_supervised!({StubSession, nil})
      UnitRegistry.register_player(target_gs, target_pid)

      {attached, ok} = Dsl.attachrid(ctx(), 888)
      assert ok == 1
      assert attached.session_pid == target_pid
    end
  end
end
