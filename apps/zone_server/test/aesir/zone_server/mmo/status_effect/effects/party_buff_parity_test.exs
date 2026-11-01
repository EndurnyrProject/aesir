defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PartyBuffParityTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.StatusChange
  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Assumptio
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseAgi
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule SpiritFixture do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_spirit,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false
  end

  defmodule KaiteFixture do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_kaite,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false
  end

  setup :setup_ets_tables

  setup do
    player =
      PlayerState.new(%Character{
        id: 7_707,
        account_id: 7_707,
        name: "Party buff parity",
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
    %{id: player.character_id}
  end

  test "blessing cures curse before stone and grants no buff on either cure-only exit", %{id: id} do
    :ok = StatusStorage.apply_status(:player, id, :sc_curse)
    :ok = StatusStorage.apply_status(:player, id, :sc_stone)
    params = [val1: 10, duration: 240_000, bypass_resistance: true]

    assert {:ok, [{:sc_curse, :removed}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_blessing, params)

    assert StatusStorage.has_status?(:player, id, :sc_stone)
    refute StatusStorage.has_status?(:player, id, :sc_blessing)

    assert {:ok, [{:sc_stone, :removed}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_blessing, params)

    refute StatusStorage.has_status?(:player, id, :sc_blessing)

    assert {:ok, [{:sc_blessing, :apply}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_blessing, params)

    assert %{val2: 10} = StatusStorage.get_status(:player, id, :sc_blessing)
  end

  test "blessing's cure-only branch precedes stronger held-level protection", %{id: id} do
    :ok = StatusStorage.apply_status(:player, id, :sc_blessing, val1: 10, val2: 10)
    held = StatusStorage.get_status(:player, id, :sc_blessing)
    :ok = StatusStorage.apply_status(:player, id, :sc_curse)

    assert {:ok, [{:sc_curse, :removed}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_blessing,
               val1: 1,
               duration: 60_000,
               bypass_resistance: true
             )

    assert StatusStorage.get_status(:player, id, :sc_blessing) == held
    refute StatusStorage.has_status?(:player, id, :sc_curse)
  end

  test "increase agi direct aspd is renewal only while normal agi still applies", %{id: id} do
    assert :ok =
             Interpreter.apply_status(:player, id, :sc_increaseagi,
               val1: 10,
               duration: 240_000,
               bypass_resistance: true
             )

    held = StatusStorage.get_status(:player, id, :sc_increaseagi)
    assert held.val2 == 12
    modifiers = IncreaseAgi.modifiers(held, %{})
    assert modifiers.agi == 12
    assert modifiers.haste_rate == 25
    assert Map.get(modifiers, :aspd, 0) == if(GameMode.mode() == :renewal, do: 10, else: 0)
  end

  test "high spirit ends before overlap but other links and cure-only starts retain it", %{id: id} do
    :ok = Registry.register_module(SpiritFixture)
    :ok = StatusStorage.apply_status(:player, id, :sc_spirit, val2: 494)
    :ok = StatusStorage.apply_status(:player, id, :sc_blessing, val1: 10, val2: 10)
    held = StatusStorage.get_status(:player, id, :sc_blessing)
    params = [val1: 1, duration: 60_000, bypass_resistance: true]

    assert {:ok, [{:sc_spirit, :removed}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_blessing, params)

    assert StatusStorage.get_status(:player, id, :sc_blessing) == held
    :ok = StatusStorage.apply_status(:player, id, :sc_spirit, val2: 494)
    :ok = StatusStorage.apply_status(:player, id, :sc_curse)

    assert {:ok, [{:sc_curse, :removed}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_blessing, params)

    assert StatusStorage.has_status?(:player, id, :sc_spirit)
    :ok = StatusStorage.apply_status(:player, id, :sc_spirit, val2: 445)

    assert {:ok, []} = Interpreter.apply_status_with_events(:player, id, :sc_blessing, params)
    assert %{val2: 445} = StatusStorage.get_status(:player, id, :sc_spirit)
  end

  test "increase agi's no-avoid start refuses madogear without blocking an ordinary start", %{
    id: id
  } do
    {:ok, {_module, player, _pid}} = UnitRegistry.get_unit(:player, id)
    :ok = UnitRegistry.update_unit_state(:player, id, %{player | option: Option.id(:madogear)})

    assert {:error, :madogear} =
             Interpreter.apply_status(:player, id, :sc_increaseagi,
               val1: 10,
               duration: 240_000,
               no_avoid: true
             )

    assert :ok =
             Interpreter.apply_status(:player, id, :sc_increaseagi, val1: 10, duration: 240_000)
  end

  test "assumptio selects mode icon and exact termination relationships", %{id: id} do
    :ok = Registry.register_module(KaiteFixture)
    :ok = StatusStorage.apply_status(:player, id, :sc_kaite)
    :ok = StatusStorage.apply_status(:player, id, :sc_kyrie)

    assert :ok =
             Interpreter.apply_status(:player, id, :sc_assumptio,
               val1: 5,
               duration: 100_000,
               bypass_resistance: true
             )

    refute StatusStorage.has_status?(:player, id, :sc_kaite)
    assert StatusStorage.has_status?(:player, id, :sc_kyrie) == (GameMode.mode() == :renewal)
    icon = if GameMode.mode() == :renewal, do: :assumptio2, else: :assumptio
    efst = Efst.id(icon)

    assert Enum.any?(
             StatusDisplay.active_icons(:player, id),
             &match?(%StatusChange{efst: ^efst}, &1)
           )

    entry = %StatusEntry{type: :sc_assumptio, val1: 5}

    assert Assumptio.modifiers(entry, %{}) ==
             if(GameMode.mode() == :renewal, do: %{def: 250}, else: %{})
  end

  test "loaded secondary values are preserved for both attribute buffs", %{id: id} do
    for status <- [:sc_blessing, :sc_increaseagi] do
      assert :ok =
               Interpreter.apply_status(:player, id, status,
                 val1: 1,
                 val2: 17,
                 duration: 30_000,
                 loaded: true
               )

      assert %{val2: 17} = StatusStorage.get_status(:player, id, status)
    end
  end
end
