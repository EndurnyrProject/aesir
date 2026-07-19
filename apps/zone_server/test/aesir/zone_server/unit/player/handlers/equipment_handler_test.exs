defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context

  test "publishes recalculated maxima and clamped resources after equipment changes" do
    game_state = PlayerState.new(character())
    item = %InventoryItem{nameid: 501, amount: 1, equip: 2}
    game_state = %{game_state | party_id: 7, inventory: %{0 => item}}

    recalculated =
      game_state.stats
      |> put_in([Access.key!(:current_state), Access.key!(:hp)], 80)
      |> put_in([Access.key!(:current_state), Access.key!(:sp)], 40)
      |> put_in([Access.key!(:current_state), Access.key!(:ap)], 10)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_hp)], 80)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_sp)], 40)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_ap)], 10)

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    expect(InventoryOps, :apply_change, fn 1000, _old, _new, {:unequipped, 0} ->
      {:ok, %{}}
    end)

    expect(Stats, :calculate_stats, fn _stats, 1000, [] -> recalculated end)

    expect(Manager, :sync_member, fn 7, 1000, member ->
      assert member == %Member{
               char_id: 1000,
               name: "Equipper",
               job_id: recalculated.progression.job_id,
               base_level: recalculated.progression.base_level,
               hp: 80,
               max_hp: 80,
               sp: 40,
               max_sp: 40,
               ap: 10,
               max_ap: 10,
               online: true,
               map_name: "prontera"
             }

      {:ok, %{}}
    end)

    state = %{connection_pid: self(), game_state: game_state}

    assert {:noreply, %{game_state: %{stats: ^recalculated}}} =
             EquipmentHandler.handle_unequip(0, state)
  end

  test "refreshes and publishes walk speed after an equipment change" do
    game_state = PlayerState.new(character())
    item = %InventoryItem{nameid: 501, amount: 1, equip: 2}
    game_state = %{game_state | inventory: %{0 => item}, walk_speed: 150}

    speeded =
      put_in(game_state.stats, [Access.key!(:modifiers), Access.key!(:equipment)], %{
        movement_speed: 25
      })

    test_pid = self()

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)

    stub(StatusSync, :send_params, fn _connection, params ->
      send(test_pid, {:params, params})
      :ok
    end)

    expect(InventoryOps, :apply_change, fn 1000, _old, _new, {:unequipped, 0} -> {:ok, %{}} end)
    expect(Stats, :calculate_stats, fn _stats, 1000, [] -> speeded end)

    state = %{connection_pid: self(), game_state: game_state}

    assert {:noreply, %{game_state: %{walk_speed: 112}}} =
             EquipmentHandler.handle_unequip(0, state)

    assert_receive {:params, params}
    assert params[StatusParams.speed()] == 112
  end

  defp character do
    %Character{
      id: 1000,
      account_id: 2000,
      name: "Equipper",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
