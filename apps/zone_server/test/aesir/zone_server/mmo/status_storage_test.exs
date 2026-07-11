defmodule Aesir.ZoneServer.Mmo.StatusStorageTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  describe "update_next_tick/4" do
    test "updates next_tick_at while keeping the entry a StatusEntry struct" do
      :ok = StatusStorage.apply_status(:player, 1, :poison, tick: 1000, duration: 30_000)

      :ok = StatusStorage.update_next_tick(:player, 1, :poison, 123_456)

      assert %StatusEntry{type: :poison, next_tick_at: 123_456} =
               StatusStorage.get_status(:player, 1, :poison)
    end

    test "keeps get_unit_statuses returning structs after a tick update" do
      :ok = StatusStorage.apply_status(:player, 2, :poison, tick: 1000, duration: 30_000)

      :ok = StatusStorage.update_next_tick(:player, 2, :poison, 999)

      assert [%StatusEntry{type: :poison, next_tick_at: 999}] =
               StatusStorage.get_unit_statuses(:player, 2)
    end

    test "is a no-op when the status does not exist" do
      assert :ok = StatusStorage.update_next_tick(:player, 3, :poison, 999)
      assert StatusStorage.get_status(:player, 3, :poison) == nil
    end
  end

  describe "get_due_statuses/1" do
    test "excludes tickless statuses from the due set" do
      :ok = StatusStorage.apply_status(:player, 4, :sc_blessing, duration: 30_000)
      :ok = StatusStorage.apply_status(:player, 4, :poison, tick: 1000, duration: 30_000)

      due = StatusStorage.get_due_statuses(System.monotonic_time(:millisecond) + 2_000)

      assert [{{:player, 4, :poison}, %StatusEntry{}}] = due
      assert %StatusEntry{next_tick_at: nil} = StatusStorage.get_status(:player, 4, :sc_blessing)
    end
  end
end
