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
