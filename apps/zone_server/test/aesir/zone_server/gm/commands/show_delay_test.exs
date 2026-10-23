defmodule Aesir.ZoneServer.Gm.Commands.ShowDelayTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Auth
  alias Aesir.Commons.Models.Account
  alias Aesir.ZoneServer.Gm.Commands.ShowDelay
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!
  setup :set_mimic_private

  test "toggles the caller's delay notices and names the new setting" do
    stub(Auth, :get_account!, fn 7 -> %Account{group_id: 1} end)
    caller = self()
    expect(PlayerSession, :toggle_show_delay, 2, fn ^caller -> :ok end)

    assert ShowDelay.execute([], ctx(false)) == {:ok, "Skill delay failures are now shown."}
    assert ShowDelay.execute([], ctx(true)) == {:ok, "Skill delay failures will not be shown."}
  end

  test "the Player and VIP groups may not use it" do
    reject(&PlayerSession.toggle_show_delay/1)

    for group_id <- [0, 5] do
      stub(Auth, :get_account!, fn 7 -> %Account{group_id: group_id} end)
      assert ShowDelay.execute([], ctx(false)) == {:error, "Insufficient permission"}
    end
  end

  defp ctx(show_delay?) do
    %{
      game_state: %PlayerState{character_id: 1, account_id: 7, show_delay: show_delay?},
      connection_pid: self()
    }
  end
end
