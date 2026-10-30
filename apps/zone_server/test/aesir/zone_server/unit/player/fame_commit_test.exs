defmodule Aesir.ZoneServer.Unit.Player.FameCommitTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.FameUpdate
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Fame
  alias Aesir.ZoneServer.Mmo.Fame.Store
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    account =
      Repo.insert!(%Account{userid: "fame-commit", user_pass: "unused", email: "fame@test.local"})

    character =
      Repo.insert!(%Character{
        account_id: account.id,
        char_num: 0,
        name: "CommitMaker",
        class: 10
      })

    player = PlayerState.new(character)
    :ok = UnitRegistry.register_unit(:player, character.id, PlayerState, player, self())

    %{
      session: %SessionState{
        connection_pid: self(),
        connection_monitor_ref: make_ref(),
        game_state: player
      },
      character: character
    }
  end

  test "an empty fame queue does not write or send", %{session: session} do
    reject(Store, :persist, 2)
    assert StateCommit.commit(session, session.game_state) == session
    detached = %{game_state: session.game_state}
    assert StateCommit.commit(detached, detached.game_state) == detached
    refute_received {:send, _, {:fame_update, _}}
  end

  test "an already-updated script snapshot still drains its fame queue", %{session: session} do
    id = session.game_state.character_id

    item =
      Repo.insert!(%InventoryItem{
        char_id: id,
        nameid: 1101,
        amount: 1,
        refine: 9,
        craft: ItemCraft.to_map(ItemCraft.forged(:neutral, 0, id))
      })

    session = %{session | game_state: %{session.game_state | inventory: %{0 => item}}}

    assert {:reply, {:ok, _snapshot}, returned} =
             ScriptEffectHandler.handle_script_apply({:successrefitem, 0, 1101, 1}, session)

    assert returned.game_state.fame == 1
    assert returned.game_state.pending_fame_awards == []
    assert {:ok, {PlayerState, published, _pid}} = UnitRegistry.get_unit(:player, id)
    assert published == returned.game_state
    assert Repo.get!(Character, id).fame == 1
    assert_received {:send, _, {:fame_update, %FameUpdate{awarded_points: 1, total_fame: 1}}}
    assert StateCommit.commit(returned, returned.game_state).game_state.pending_fame_awards == []
    refute_received {:send, _, {:fame_update, _}}
  end

  test "failed commits publish pending events then clear them on a later successful commit", %{
    session: session
  } do
    player = Fame.award(session.game_state, 10)
    id = player.character_id
    expect(Store, :persist, fn ^id, 10 -> {:error, :unavailable} end)

    capture_log(fn ->
      returned = StateCommit.commit(session, player)
      assert returned.game_state == player
      assert {:ok, {PlayerState, ^player, _}} = UnitRegistry.get_unit(:player, id)
    end)

    refute_received {:send, _, {:fame_update, _}}
    expect(Store, :persist, fn ^id, 10 -> Mimic.call_original(Store, :persist, [id, 10]) end)
    returned = StateCommit.commit(%{session | game_state: player}, player)
    assert returned.game_state.pending_fame_awards == []
    assert Repo.get!(Character, id).fame == 10
    assert_received {:send, _, {:fame_update, %FameUpdate{total_fame: 10}}}
  end

  test "graceful termination attempts a final fame flush without a live connection", %{
    session: session
  } do
    Mimic.copy(StatusPersistence)
    stub(StatusPersistence, :save_statuses, fn _ -> :ok end)
    player = Fame.award(session.game_state, 10)
    session = %{session | connection_pid: nil, game_state: %{player | action_state: :dead}}
    assert :ok = PlayerSession.terminate(:normal, session)
    assert Repo.get!(Character, player.character_id).fame == 10
    refute_received {:send, _, {:fame_update, _}}
  end

  test "final fame flush failure is logged without an early notification", %{session: session} do
    Mimic.copy(StatusPersistence)
    stub(StatusPersistence, :save_statuses, fn _ -> :ok end)
    player = Fame.award(session.game_state, 10)
    expect(Store, :persist, fn _, 10 -> {:error, :final_failure} end)
    session = %{session | connection_pid: nil, game_state: %{player | action_state: :dead}}

    assert capture_log(fn -> assert :ok = PlayerSession.terminate(:normal, session) end) =~
             "final_failure"

    assert Repo.get!(Character, player.character_id).fame == 0
    refute_received {:send, _, {:fame_update, _}}
  end

  test "completed class changes are visible to ranking reads without clearing fame", %{
    session: session
  } do
    player = Fame.award(session.game_state, 10)
    session = StateCommit.commit(session, player)
    assert {:noreply, changed} = ProgressionHandler.handle_change_job(18, session)
    assert changed.game_state.fame == 10
    assert Repo.get!(Character, player.character_id).class == 18
    assert {:ok, []} = Store.ranking(:blacksmith)
    assert {:ok, [%{fame: 10}]} = Store.ranking(:alchemist)

    expect(CharacterPersistence, :update_character, fn _id, fields, opts ->
      refute Map.has_key?(fields, :class)
      assert opts == [async: true]
      :ok
    end)

    assert {:noreply, _} = ProgressionHandler.handle_add_job_level(1, changed)
  end
end
