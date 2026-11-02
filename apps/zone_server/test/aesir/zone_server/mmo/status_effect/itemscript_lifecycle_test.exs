defmodule Aesir.ZoneServer.Mmo.StatusEffect.ItemscriptLifecycleTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.StatusChange
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    player =
      PlayerState.new(%Character{
        id: 7_712,
        account_id: 7_712,
        name: "Card lifecycle",
        class: 0,
        base_level: 1,
        job_level: 1,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11,
        last_map: "prontera",
        last_x: 100,
        last_y: 100
      })

    :ok = UnitRegistry.register_player(player, self())
    owner = self()
    stub(SpatialIndex, :get_unit_position, fn _, _ -> {:ok, {100, 100, "prontera"}} end)

    stub(Broadcast, :to_in_range, fn _, _, _, _, packet, _ ->
      send(owner, {:area, packet})
      :ok
    end)

    stub(Broadcast, :to_player, fn id, packet ->
      send(owner, {:self, id, packet})
      :ok
    end)

    %{player: player}
  end

  test "current timer expiry removes the held icon and its empty-equipment contribution", %{
    player: player
  } do
    id = player.character_id
    state = %SessionState{game_state: player, connection_pid: self()}

    assert {:reply, :ok, applied} =
             StatusManager.handle_apply_status(
               :sc_itemscript,
               [val1: 4121, val2: 248, duration: 180_000],
               state
             )

    assert applied.game_state.stats.combat_stats.hit == player.stats.combat_stats.hit + 100
    held = StatusStorage.get_status(:player, id, :sc_itemscript)
    due = System.monotonic_time(:millisecond) - 1

    assert StatusStorage.replace_status_if_current(:player, id, :sc_itemscript, held, %{
             held
             | expires_at: due
           })

    key = {:player, id, :sc_itemscript}
    timer_state = %StatusTickManager.State{timers: %{key => {make_ref(), held.generation, due}}}

    assert {:noreply, %{timers: timers}} =
             StatusTickManager.handle_info(
               {:status_timer, key, held.generation, due},
               timer_state
             )

    assert timers == %{}
    refute StatusStorage.has_status?(:player, id, :sc_itemscript)
    assert_received {:area, %StatusChange{efst: 248, on: false, val1: 0, val2: 0, val3: 0}}
    cleared = StatusManager.refresh_status(applied, :sc_itemscript, :removed)
    assert cleared.game_state.stats.combat_stats.hit == player.stats.combat_stats.hit
    assert cleared.game_state.stats.card_unequip_effects == %{}
    assert StatusDisplay.active_icons(:player, id) == []
  end

  test "dynamic card icons replay and end with zero values using visible-area or invisible-self delivery",
       %{player: player} do
    id = player.character_id

    assert {:ok, [{:sc_itemscript, :apply}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_itemscript,
               val1: 4121,
               val2: 248,
               flag: StatusEntry.no_icon_flag(),
               duration: 180_000
             )

    assert_received {:area, %StatusChange{efst: 248, on: true, val1: 0, val2: 0, val3: 0}}

    assert [%StatusChange{efst: 248, on: true, val1: 0, val2: 0, val3: 0}] =
             StatusDisplay.active_icons(:player, id)

    assert {:ok, [{:sc_itemscript, :removed}]} =
             Interpreter.remove_status_with_events(:player, id, :sc_itemscript, [])

    assert_received {:area, %StatusChange{efst: 248, on: false, val1: 0, val2: 0, val3: 0}}

    :ok = UnitRegistry.update_unit_state(:player, id, %{player | option: Option.id(:invisible)})

    assert :ok =
             Interpreter.apply_status(:player, id, :sc_itemscript,
               val1: 4047,
               val2: 302,
               duration: 60_000
             )

    assert_received {:self, ^id, %StatusChange{efst: 302, on: true, val1: 0, val2: 0, val3: 0}}
    assert :ok = Interpreter.remove_status(:player, id, :sc_itemscript)
    assert_received {:self, ^id, %StatusChange{efst: 302, on: false, val1: 0, val2: 0, val3: 0}}
    refute_received {:area, %StatusChange{efst: 302}}

    instance = %StatusEntry{type: :sc_itemscript, val1: 4121, val2: 248}
    assert :ok = StatusDisplay.on_applied(:mob, 42, :sc_itemscript, instance)
    :ok = StatusStorage.apply_status(:mob, 42, :sc_itemscript, val1: 4121, val2: 248)
    assert StatusDisplay.active_icons(:mob, 42) == []
    refute_received {:area, %StatusChange{}}
  end
end

defmodule Aesir.ZoneServer.Mmo.StatusEffect.ItemscriptPersistenceTest do
  use Aesir.DataCase, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.Net.StatusChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  test "persisted card values restore only their remaining duration and ordinary death ends them" do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "card_restore",
        user_pass: "password",
        sex: "M",
        email: "card@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      Character.new(%{
        account_id: account.id,
        char_num: 0,
        name: "CardRestore",
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        max_hp: 40,
        sp: 11,
        max_sp: 11,
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_exp: 0,
        job_exp: 0
      })
      |> Repo.insert()

    player = PlayerState.new(character)
    id = player.character_id
    :ok = UnitRegistry.register_player(player, self())
    owner = self()
    stub(SpatialIndex, :get_unit_position, fn _, _ -> {:ok, {100, 100, "prontera"}} end)

    stub(Broadcast, :to_in_range, fn _, _, _, _, packet, _ ->
      send(owner, {:area, packet})
      :ok
    end)

    state = %SessionState{game_state: player, connection_pid: self()}

    assert {:reply, :ok, applied} =
             StatusManager.handle_apply_status(
               :sc_itemscript,
               [val1: 4121, val2: 248, val3: 7, val4: 8, duration: 180_000],
               state
             )

    held = StatusStorage.get_status(:player, id, :sc_itemscript)
    shortened = %{held | expires_at: System.monotonic_time(:millisecond) + 12_345}
    assert StatusStorage.replace_status_if_current(:player, id, :sc_itemscript, held, shortened)
    assert :ok = StatusPersistence.save_statuses(id)

    assert [%CharacterStatus{val1: 4121, val2: 248, val3: 7, val4: 8, remaining_ms: remaining}] =
             Repo.all(CharacterStatus)

    assert remaining > 0 and remaining <= 12_345
    assert {:reply, :ok, cleared} = StatusManager.handle_remove_status(:sc_itemscript, applied)
    before_restore = System.monotonic_time(:millisecond)
    restored = StatusPersistence.restore_on_spawn(cleared)
    after_restore = System.monotonic_time(:millisecond)
    entry = StatusStorage.get_status(:player, id, :sc_itemscript)
    assert {entry.val1, entry.val2, entry.val3, entry.val4} == {4121, 248, 7, 8}
    assert entry.expires_at >= before_restore + remaining
    assert entry.expires_at <= after_restore + remaining
    assert entry.generation != held.generation
    assert restored.game_state.stats.combat_stats.hit == player.stats.combat_stats.hit + 100
    assert restored.game_state.inventory == player.inventory
    assert Repo.all(CharacterStatus) == []
    assert_received {:area, %StatusChange{efst: 248, on: true, val1: 0, val2: 0, val3: 0}}
    assert_received {:area, %StatusChange{efst: 248, on: false}}
    assert_received {:area, %StatusChange{efst: 248, on: true, val1: 0, val2: 0, val3: 0}}

    assert :ok = Interpreter.remove_on_death(:player, id)
    refute StatusStorage.has_status?(:player, id, :sc_itemscript)
    assert_received {:area, %StatusChange{efst: 248, on: false, val1: 0, val2: 0, val3: 0}}

    assert StatusManager.refresh_status(restored, :sc_itemscript, :removed).game_state.stats.combat_stats.hit ==
             player.stats.combat_stats.hit
  end
end
