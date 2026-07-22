defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerGmTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.ChatRequest
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :setup_ets_tables

  @char_id 1000
  @char_name "GmChar"

  defp seed_account(gm_level) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "gm#{System.unique_integer([:positive])}",
        userid: "gm#{System.unique_integer([:positive])}",
        user_pass: "password",
        email: "gm@test.com",
        gm_level: gm_level
      })
      |> Repo.insert()

    account
  end

  defp state_for(account) do
    game_state = %PlayerState{
      account_id: account.id,
      character_id: @char_id,
      character_name: @char_name,
      visible_players: MapSet.new()
    }

    %{game_state: game_state, connection_pid: self(), connection_monitor_ref: nil}
  end

  defp chat(text), do: %ChatRequest{message: "#{@char_name} : #{text}"}

  defp receive_chat_message(timeout \\ 1000) do
    receive do
      {:send, _channel, {:chat_message, %ChatMessage{} = message}} -> message
    after
      timeout -> flunk("Expected a ChatMessage within #{timeout}ms")
    end
  end

  test "a GM giving an item to self gets a feedback ChatMessage and no broadcast" do
    {:ok, item_def} = ItemManagement.get_item_by_id(501)
    state = state_for(seed_account(60))

    {:noreply, ^state} = PacketHandler.handle_message(chat("@item 501 1"), state)

    assert %ChatMessage{gid: @char_id, message: message} = receive_chat_message()
    assert message == "Gave 1x #{item_def.name} to #{@char_name}"

    # The give-item delivery runs as a cast to the GM's own session (self()).
    assert_receive {:"$gen_cast", {:inventory, {:give_item, ^item_def, 1}}}

    # The raw command is never broadcast.
    refute_received {:send, _channel,
                     {:chat_message, %ChatMessage{message: "#{@char_name} : @item 501 1"}}}
  end

  test "a non-GM issuing @item is denied and nothing is given" do
    state = state_for(seed_account(0))

    {:noreply, ^state} = PacketHandler.handle_message(chat("@item 501 1"), state)

    assert %ChatMessage{gid: @char_id, message: "Insufficient permission"} =
             receive_chat_message()

    refute_received {:"$gen_cast", {:inventory, {:give_item, _, _}}}
  end
end
