defmodule Aesir.ZoneServer.Integration.ConsumableVisibilityWaveTest do
  use Aesir.ZoneServer.IntegrationCase

  import Bitwise, only: [band: 2]

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.EquipItem
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UnitSpawn
  alias Aesir.Net.UnitStateChange
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @head_top EquipLocation.location_bit(:head_top)

  setup do
    ScriptCompiler.compile_all!()
    :ok
  end

  test "sunlight reveals only its observer and equipment/status overlap survives either source ending" do
    character = character()

    assert {:ok, _} =
             Persistence.insert_item(character.id, %{nameid: 12_033, amount: 3, identify: 1})

    assert {:ok, hat} =
             Persistence.insert_item(character.id, %{
               nameid: 2221,
               amount: 1,
               identify: 1,
               card0: 4198
             })

    observer = start_player_session(character: character)

    plain =
      start_player_session(character: character(), position: {151, 150}, connection_pid: self())

    hidden = start_player_session(character: character(), position: {152, 150})

    for session <- [observer, plain, hidden] do
      on_exit(fn -> if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal) end)
    end

    target = hidden.character.id
    observer_id = observer.character.id
    hide = Option.id(:hide)

    assert eventually(fn ->
             MapSet.member?(get_player_state(observer.pid).visible_players, target) and
               MapSet.member?(get_player_state(plain.pid).visible_players, target)
           end)

    assert :ok =
             PlayerSession.apply_status(hidden.pid, :sc_hiding,
               duration: 300_000,
               val1: 10,
               bypass_resistance: true
             )

    assert_receive {:send, :world,
                    {:unit_state_change,
                     %UnitStateChange{unit_id: ^target, effect_state: concealed}}}

    assert band(concealed, hide) != 0
    flush_packets()

    use_sunlight(observer)
    assert %{val1: 0} = StatusStorage.get_status(:player, observer_id, :sc_intravision)
    assert_receive {:packet_sent, %UnitStateChange{unit_id: ^target, effect_state: revealed}, _}
    assert band(revealed, hide) == 0

    refute_receive {:send, :world,
                    {:unit_state_change, %UnitStateChange{unit_id: ^target, effect_state: 0}}},
                   0

    assert StatusStorage.has_status?(:player, target, :sc_hiding)

    PlayerSession.notify_entered_view(observer.pid, target)
    PlayerSession.get_state(observer.pid)
    assert_receive {:packet_sent, %UnitSpawn{gid: ^target, effect_state: entering}, _}
    assert band(entering, hide) == 0
    drain_plain_packets()
    PlayerSession.notify_entered_view(plain.pid, target)
    PlayerSession.get_state(plain.pid)

    assert_receive {:send, :world,
                    {:unit_spawn, %UnitSpawn{gid: ^target, effect_state: plain_bits}}}

    assert band(plain_bits, hide) != 0

    equip(observer, hat.id)
    expire_sight(observer)
    assert PlayerState.intravision?(get_player_state(observer.pid))
    use_sunlight(observer)
    unequip(observer, hat.id)
    assert PlayerState.intravision?(get_player_state(observer.pid))
    flush_packets()
    expire_sight(observer)
    refute PlayerState.intravision?(get_player_state(observer.pid))

    assert_receive {:packet_sent, %UnitStateChange{unit_id: ^target, effect_state: hidden_again},
                    _}

    assert band(hidden_again, hide) != 0
    assert StatusStorage.has_status?(:player, target, :sc_hiding)
    assert Enum.find(Persistence.load_inventory(character.id), &(&1.nameid == 12_033)).amount == 1
  end

  defp use_sunlight(observer) do
    {index, _} =
      Enum.find(get_player_state(observer.pid).inventory, fn {_index, row} ->
        row.nameid == 12_033
      end)

    simulate_incoming_message(observer.pid, %UseItem{index: PlayerState.client_index(index)})
    PlayerSession.get_state(observer.pid)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    assert PlayerState.intravision?(get_player_state(observer.pid))
  end

  defp equip(observer, row_id) do
    {index, _} =
      Enum.find(get_player_state(observer.pid).inventory, fn {_index, row} -> row.id == row_id end)

    simulate_incoming_message(observer.pid, %EquipItem{
      index: PlayerState.client_index(index),
      position: @head_top
    })

    assert eventually(fn ->
             Enum.any?(get_player_state(observer.pid).stats.worn_items, &(&1.id == row_id))
           end)
  end

  defp unequip(observer, row_id) do
    {index, _} =
      Enum.find(get_player_state(observer.pid).inventory, fn {_index, row} -> row.id == row_id end)

    simulate_incoming_message(observer.pid, %UnequipItem{index: PlayerState.client_index(index)})

    assert eventually(fn ->
             Enum.all?(get_player_state(observer.pid).stats.worn_items, &(&1.id != row_id))
           end)
  end

  defp expire_sight(observer) do
    id = observer.character.id

    :ok =
      StatusStorage.update_status(
        :player,
        id,
        :sc_intravision,
        &%{&1 | expires_at: System.monotonic_time(:millisecond) - 1}
      )

    StatusTickManager.force_tick()

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, id, :sc_intravision) and
               get_player_state(observer.pid).stats.modifiers.status_effects[:intravision] in [
                 nil,
                 0
               ]
           end)
  end

  defp drain_plain_packets do
    receive do
      {:send, _channel, _packet} -> drain_plain_packets()
    after
      0 -> :ok
    end
  end

  defp character do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "cv#{unique}",
        user_pass: "password",
        email: "cv#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "CV#{unique}",
      class: 0,
      base_level: 50,
      job_level: 1,
      learned_skills: %{"1" => 3},
      hp: 200,
      sp: 50,
      str: 1,
      agi: 1,
      vit: 0,
      int: 1,
      dex: 1,
      luk: 0,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    })
    |> Repo.insert!()
  end
end
