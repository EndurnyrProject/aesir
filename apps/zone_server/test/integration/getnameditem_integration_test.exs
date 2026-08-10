defmodule Aesir.ZoneServer.Integration.GetNamedItemIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.SessionManager
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

  @jellopy 909

  setup do
    suffix = System.unique_integer([:positive])
    recipient = character_fixture("recipient#{suffix}")
    creator = character_fixture("creator#{suffix}")

    session =
      start_player_session(character: recipient, map_name: "prontera", position: {150, 150})

    on_exit(fn -> end_player_session(session) end)

    %{creator: creator, recipient: recipient, session: session}
  end

  test "adds a signed item for an online creator", %{creator: creator, session: session} do
    set_online(creator)

    ctx = session |> ctx_for() |> Dsl.get_named_item(@jellopy, creator.name)

    assert ctx.status == :ok

    assert Enum.any?(ctx.game_state.inventory, fn {_slot, item} ->
             item.nameid == @jellopy and
               item.identify == 1 and
               item.craft == ItemCraft.to_map(ItemCraft.signed(creator.id))
           end)
  end

  test "adds nothing for an offline creator", %{creator: creator, session: session} do
    ctx = session |> ctx_for() |> Dsl.get_named_item(@jellopy, creator.name)

    assert ctx.status == {:error, :not_online}
    assert ctx.game_state.inventory == %{}
  end

  defp ctx_for(session) do
    session
    |> Map.take([:connection_pid])
    |> Map.put(:game_state, get_player_state(session.pid))
    |> Ctx.from_session({:npc, :getnameditem_test})
    |> Map.put(:session_pid, session.pid)
  end

  defp set_online(%Character{account_id: account_id, id: character_id, account: account}) do
    :ok =
      SessionManager.create_session(account_id, %{
        login_id1: 1,
        login_id2: 2,
        auth_code: "auth",
        username: account.userid
      })

    :ok = SessionManager.set_user_online(account_id, :zone_server, character_id, "prontera")
    on_exit(fn -> SessionManager.end_session(account_id) end)
  end

  defp character_fixture(prefix) do
    account =
      %Account{}
      |> Account.changeset(%{
        userid: prefix,
        user_pass: "password",
        email: "#{prefix}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: String.capitalize(prefix),
      class: 0
    })
    |> Repo.insert!()
    |> Repo.preload(:account)
  end
end
