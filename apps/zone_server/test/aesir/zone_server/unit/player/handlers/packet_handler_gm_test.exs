defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerGmTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Net.ChatNotice
  alias Aesir.Net.ChatSend
  alias Aesir.Net.GmCommand
  alias Aesir.StatusActionFixture
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
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

  defp state_for(account, attrs \\ []) do
    game_state =
      struct(
        %PlayerState{
          account_id: account.id,
          character_id: @char_id,
          character_name: @char_name,
          visible_players: MapSet.new()
        },
        attrs
      )

    %{game_state: game_state, connection_pid: self(), connection_monitor_ref: nil}
  end

  defp receive_notice(timeout \\ 1000) do
    receive do
      {:send, :world, {:chat_notice, %ChatNotice{} = notice}} -> notice
    after
      timeout -> flunk("Expected a ChatNotice within #{timeout}ms")
    end
  end

  test "a muted player's chat is dropped on every channel while GM commands still dispatch" do
    Registry.register_module(StatusActionFixture)

    :ok =
      StatusStorage.apply_status(:player, @char_id, StatusActionFixture.id(), duration: 30_000)

    party_id = System.unique_integer([:positive])
    Phoenix.PubSub.subscribe(Aesir.PubSub, "party:#{party_id}")
    state = state_for(seed_account(0), party_id: party_id)

    for channel <- [:CHAT_LOCAL, :CHAT_PARTY, :CHAT_WHISPER] do
      message = %ChatSend{channel: channel, text: "hello", whisper_to: @char_name}
      assert {:noreply, ^state} = PacketHandler.handle_message(message, state)
    end

    refute_received {:send, _channel, _payload}
    refute_received {:social, {:chat_line, _line}}

    assert {:noreply, ^state} =
             PacketHandler.handle_message(%GmCommand{command: "item 501 1"}, state)

    assert %ChatNotice{kind: :ERROR, text: "Insufficient permission"} = receive_notice()
  end

  test "a GM giving an item to self gets an info notice and nothing is said aloud" do
    {:ok, item_def} = ItemManagement.get_item_by_id(501)
    state = state_for(seed_account(60))

    {:noreply, ^state} = PacketHandler.handle_message(%GmCommand{command: "item 501 1"}, state)

    assert %ChatNotice{kind: :INFO, text: text} = receive_notice()
    assert text == "Gave 1x #{item_def.name} to #{@char_name}"

    # The give-item delivery runs as a cast to the GM's own session (self()).
    assert_receive {:"$gen_cast", {:inventory, {:give_item, ^item_def, 1}}}

    # The command line is never echoed as speech.
    refute_received {:send, _channel, {:chat_line, _line}}
  end

  test "a non-GM issuing item is denied and nothing is given" do
    state = state_for(seed_account(0))

    {:noreply, ^state} = PacketHandler.handle_message(%GmCommand{command: "item 501 1"}, state)

    assert %ChatNotice{kind: :ERROR, text: "Insufficient permission"} = receive_notice()
    refute_received {:"$gen_cast", {:inventory, {:give_item, _, _}}}
  end
end
