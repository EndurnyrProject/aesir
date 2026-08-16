defmodule Aesir.ZoneServer.Guild.TaxTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Tax
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_global
  setup :verify_on_exit!

  defp player(guild_id, tax) do
    %PlayerState{character_id: 1, account_id: 1, guild_id: guild_id, guild_tax: tax}
  end

  describe "apply/2" do
    test "diverts the floored tax share from base exp" do
      assert Tax.apply(player(5, 30), 1_000) == {700, 300}
      assert Tax.apply(player(5, 30), 105) == {74, 31}
      assert Tax.apply(player(5, 7), 10) == {10, 0}
    end

    test "passes through for guildless or untaxed players" do
      assert Tax.apply(player(0, 30), 1_000) == {1_000, 0}
      assert Tax.apply(player(nil, 30), 1_000) == {1_000, 0}
      assert Tax.apply(player(5, 0), 1_000) == {1_000, 0}
      assert Tax.apply(player(5, nil), 1_000) == {1_000, 0}
    end
  end

  describe "contribute_async/2" do
    test "forwards a positive amount to the guild manager off-process" do
      test_pid = self()

      expect(Manager, :contribute_exp, fn 5, 300 ->
        send(test_pid, :contributed)
        :ok
      end)

      assert :ok = Tax.contribute_async(5, 300)
      assert_receive :contributed
    end

    test "zero taxed amount never touches the manager" do
      reject(&Manager.contribute_exp/2)
      assert :ok = Tax.contribute_async(5, 0)
    end
  end
end
