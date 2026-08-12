defmodule Aesir.ZoneServer.Script.DslVarsTest do
  @moduledoc """
  Covers the shared script variable scopes (rAthena `$`, `$@`, `#`/`##`, `.`):
  server/account permanent vars are Postgres write/read-through, server-temp and
  NPC vars are in-memory ETS, and account vars are no-ops without a player.
  """

  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :setup_ets_tables

  defmodule StubSession do
    # A stand-in session answering {:script_apply, op} with the configured
    # game_state, forwarding the op to the probe so tests can assert the
    # write routed through the seam.
    use GenServer

    def start_link({probe, game_state}),
      do: GenServer.start_link(__MODULE__, {probe, game_state})

    @impl true
    def init({probe, game_state}), do: {:ok, {probe, game_state}}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, {probe, game_state}) do
      send(probe, {:script_apply, op})
      {:reply, {:ok, game_state}, {probe, game_state}}
    end
  end

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "varsuser",
        userid: "varsuser",
        user_pass: "password",
        email: "vars@test.com"
      })
      |> Repo.insert()

    %{account: account}
  end

  defp ctx(opts \\ []) do
    account_id = Keyword.get(opts, :account_id, 100)

    %Ctx{
      char_id: 1,
      account_id: account_id,
      connection_pid: self(),
      session_pid: self(),
      game_state: %PlayerState{character_id: 1, account_id: account_id},
      source: Keyword.get(opts, :source, {:npc, :test_npc})
    }
  end

  describe "server permanent vars ($)" do
    test "round-trips and upserts through Postgres" do
      c = ctx()
      assert Dsl.get_server_var(c, "donate", 0) == 0

      assert %Ctx{} = Dsl.set_server_var(c, "donate", 500)
      assert Dsl.get_server_var(c, "donate", 0) == 500

      Dsl.set_server_var(c, "donate", 1500)
      assert Dsl.get_server_var(c, "donate", 0) == 1500
    end

    test "stores string values (rAthena $var$)" do
      c = ctx()
      Dsl.set_server_var(c, "event_name$", "spring")
      assert Dsl.get_server_var(c, "event_name$", "") == "spring"
    end

    test "works on a detached ctx (no player needed)" do
      detached = %{ctx() | game_state: nil, account_id: nil}
      Dsl.set_server_var(detached, "boot_count", 3)
      assert Dsl.get_server_var(detached, "boot_count", 0) == 3
    end
  end

  describe "server temp vars ($@)" do
    test "round-trips through ETS and defaults when unset" do
      c = ctx()
      assert Dsl.get_server_temp_var(c, "stage", 0) == 0

      Dsl.set_server_temp_var(c, "stage", 3)
      assert Dsl.get_server_temp_var(c, "stage", 0) == 3
    end
  end

  describe "account vars (#/##)" do
    test "round-trip keyed by the attached account", %{account: account} do
      c = ctx(account_id: account.id)
      assert Dsl.get_account_var(c, "#points", 0) == 0

      Dsl.set_account_var(c, "#points", 5)
      assert Dsl.get_account_var(c, "#points", 0) == 5
    end

    test "# and ## stay distinct", %{account: account} do
      c = ctx(account_id: account.id)
      Dsl.set_account_var(c, "#points", 5)
      Dsl.set_account_var(c, "##points", 9)

      assert Dsl.get_account_var(c, "#points", 0) == 5
      assert Dsl.get_account_var(c, "##points", 0) == 9
    end

    test "are isolated per account", %{account: account} do
      Dsl.set_account_var(ctx(account_id: account.id), "#points", 5)
      assert Dsl.get_account_var(ctx(account_id: account.id + 999), "#points", 0) == 0
    end

    test "default/no-op without a player" do
      detached = %{ctx() | account_id: nil}
      assert Dsl.get_account_var(detached, "#points", 42) == 42
      assert %Ctx{} = Dsl.set_account_var(detached, "#points", 5)
    end
  end

  describe "npc vars (.)" do
    test "round-trip scoped to the running NPC script" do
      c = ctx(source: {:npc, :kafra})
      assert Dsl.get_npc_var(c, "counter", 0) == 0

      Dsl.set_npc_var(c, "counter", 7)
      assert Dsl.get_npc_var(c, "counter", 0) == 7
    end

    test "are isolated per NPC script" do
      Dsl.set_npc_var(ctx(source: {:npc, :kafra}), "counter", 7)
      assert Dsl.get_npc_var(ctx(source: {:npc, :cool_event}), "counter", 0) == 0
    end
  end

  describe "getd/setd dynamic names" do
    test "server scope ($): scalar and array via a runtime-built name" do
      c = ctx()
      assert Dsl.getd(c, "$donate") == 0
      assert %Ctx{} = Dsl.setd(c, "$donate", 500)
      assert Dsl.getd(c, "$donate") == 500

      # same name as static access
      assert Dsl.get_server_var(c, "donate", 0) == 500

      Dsl.setd(c, "$arr[0]", 7)
      Dsl.setd(c, "$arr[2]", 9)
      assert Dsl.getd(c, "$arr[0]") == 7
      assert Dsl.getd(c, "$arr[1]") == 0
      assert Dsl.getd(c, "$arr[2]") == 9
      assert Dsl.getd(c, "$arr") == [7, 0, 9]
    end

    test "server string vars ($name$): whole reads and string-array pads" do
      c = ctx()
      Dsl.setd(c, "$ma_name01$", "Spring")
      assert Dsl.getd(c, "$ma_name01$") == "Spring"

      Dsl.setd(c, "$list$[0]", "a")
      Dsl.setd(c, "$list$[1]", "b")
      assert Dsl.getd(c, "$list$[1]") == "b"
      assert Dsl.getd(c, "$list$[2]") == ""
    end

    test "server temp scope ($@)" do
      c = ctx()
      Dsl.setd(c, "$@stage", 3)
      assert Dsl.getd(c, "$@stage") == 3
    end

    test "account scope (# / ## stay distinct)", %{account: account} do
      c = ctx(account_id: account.id)
      Dsl.setd(c, "#points", 5)
      Dsl.setd(c, "##points", 9)

      assert Dsl.getd(c, "#points") == 5
      assert Dsl.getd(c, "##points") == 9
    end

    test "npc scope (.)" do
      c = ctx(source: {:npc, :kafra})
      Dsl.setd(c, ".counter", 7)
      assert Dsl.getd(c, ".counter") == 7
    end

    test "local scope (.@): array writes land in the ctx vars map" do
      c = ctx()
      c = Dsl.setd(c, ".@msg[0]", "a")
      c = Dsl.setd(c, ".@msg[1]", "b")

      assert Dsl.getd(c, ".@msg[0]") == "a"
      assert Dsl.getd(c, ".@msg[1]") == "b"
      assert Dsl.getd(c, ".@msg") == ["a", "b"]
      assert Dsl.get_local(c, :msg, []) == ["a", "b"]
    end

    test "temp scope (@): writes route through the session seam" do
      gs = %{ctx().game_state | temp_vars: %{"buffs" => ["x"]}}
      session = start_supervised!({StubSession, {self(), gs}})
      c = %{ctx() | session_pid: session, game_state: gs}

      result = Dsl.setd(c, "@buffs[1]", "haste")

      assert result.status == :ok
      assert_received {:script_apply, {:set_temp_var, :buffs, ["x", "haste"]}}
    end

    test "char scope (bare name): reads the snapshot, writes via the seam" do
      gs = %{ctx().game_state | vars: %{"quest" => 1, "arr" => []}}
      session = start_supervised!({StubSession, {self(), gs}})
      c = %{ctx() | session_pid: session, game_state: gs}

      assert Dsl.getd(c, "quest") == 1

      assert Dsl.setd(c, "arr[1]", 9).status == :ok
      assert_received {:script_apply, {:set_char_var, :arr, [0, 9]}}

      assert Dsl.setd(c, "quest", 2).status == :ok
      assert_received {:script_apply, {:set_char_var, :quest, 2}}
    end

    test "char/temp getd raises no_player on a detached ctx; other scopes work" do
      detached = %{ctx() | game_state: nil, account_id: nil, session_pid: nil}

      assert Dsl.getd(detached, "$boot_count") == 0
      assert_raise ArgumentError, fn -> Dsl.getd(detached, "@t") end
      assert_raise ArgumentError, fn -> Dsl.getd(detached, "quest") end
    end

    test "char/temp setd halts :no_player on a detached ctx" do
      detached = %{ctx() | game_state: nil, account_id: nil, session_pid: nil}
      assert Dsl.setd(detached, "@t", 1).status == {:error, :no_player}
      assert Dsl.setd(detached, "quest", 1).status == {:error, :no_player}
    end

    test "instance scope (' ) raises via Todo" do
      c = ctx()

      assert_raise Aesir.ZoneServer.Script.NotImplementedError, fn ->
        Dsl.getd(c, "'box_a")
      end
    end

    test "an errored ctx short-circuits setd" do
      halted = Ctx.halt(ctx(), :boom)
      assert Dsl.setd(halted, "$x", 1) == halted
    end
  end

  describe "errored ctx short-circuits writes" do
    test "set ops return the halted ctx untouched" do
      halted = Ctx.halt(ctx(), :boom)
      assert Dsl.set_server_var(halted, "x", 1) == halted
      assert Dsl.set_server_temp_var(halted, "x", 1) == halted
      assert Dsl.set_account_var(halted, "x", 1) == halted
      assert Dsl.set_npc_var(halted, "x", 1) == halted
    end
  end
end
