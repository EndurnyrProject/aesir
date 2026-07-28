defmodule Aesir.ZoneServer.Mmo.StatusStorageTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  describe "apply_status_with_entry/4" do
    test "returns nil for insertion and the exact prior entry for replacement" do
      assert {:stored, entry, nil} =
               StatusStorage.apply_status_with_entry(:player, 1, :poison,
                 val1: 7,
                 duration: 30_000,
                 state: %{generation: :first}
               )

      assert %StatusEntry{type: :poison, val1: 7, state: %{generation: :first}} = entry
      assert StatusStorage.get_status(:player, 1, :poison) === entry

      assert {:stored, replacement, ^entry} =
               StatusStorage.apply_status_with_entry(:player, 1, :poison, val1: 8)

      assert StatusStorage.get_status(:player, 1, :poison) === replacement
      assert :ok = StatusStorage.apply_status(:player, 1, :poison, val1: 9)
    end
  end

  describe "store_if_newer/3" do
    test "does not let a lower generation inserted late replace the current entry" do
      lower = status_entry(1)
      higher = status_entry(2)

      assert {:stored, ^higher, nil} = StatusStorage.store_if_newer(:player, 10, higher)
      assert {:superseded, ^higher} = StatusStorage.store_if_newer(:player, 10, lower)
      assert StatusStorage.get_status(:player, 10, :poison) === higher
    end

    test "replaces a lower generation and returns that exact prior entry" do
      lower = status_entry(1)
      higher = status_entry(2)

      assert {:stored, ^lower, nil} = StatusStorage.store_if_newer(:player, 11, lower)
      assert {:stored, ^higher, ^lower} = StatusStorage.store_if_newer(:player, 11, higher)
      assert StatusStorage.get_status(:player, 11, :poison) === higher
    end

    test "treats nil as older than a generated entry" do
      ungenerated = status_entry(nil)
      generated = status_entry(1)

      assert {:stored, ^ungenerated, nil} =
               StatusStorage.store_if_newer(:player, 12, ungenerated)

      assert {:stored, ^generated, ^ungenerated} =
               StatusStorage.store_if_newer(:player, 12, generated)

      assert {:superseded, ^generated} = StatusStorage.store_if_newer(:player, 12, ungenerated)
      assert StatusStorage.get_status(:player, 12, :poison) === generated
    end

    test "concurrent CAS retries report only the exact entry each write replaced" do
      results =
        1..100
        |> Task.async_stream(
          &StatusStorage.store_if_newer(:player, 13, status_entry(&1)),
          max_concurrency: 20,
          timeout: 1_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, fn
               {:stored, %StatusEntry{}, nil} -> true
               {:stored, %StatusEntry{}, %StatusEntry{}} -> true
               {:superseded, %StatusEntry{}} -> true
             end)

      stored =
        results
        |> Enum.flat_map(fn
          {:stored, entry, prior} -> [{entry, prior}]
          {:superseded, _current} -> []
        end)
        |> Enum.sort_by(fn {entry, _prior} -> entry.generation end)

      assert [{_first, nil} | _rest] = stored

      stored
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [{prior_entry, _}, {_entry, reported_prior}] ->
        assert reported_prior === prior_entry
      end)

      assert %StatusEntry{generation: 100} = StatusStorage.get_status(:player, 13, :poison)
    end
  end

  describe "remove_status_if_current/4" do
    test "deletes only the exact expected entry" do
      {:stored, first, nil} =
        StatusStorage.apply_status_with_entry(:player, 2, :poison, state: %{generation: :first})

      {:stored, newer, ^first} =
        StatusStorage.apply_status_with_entry(:player, 2, :poison, state: %{generation: :newer})

      refute StatusStorage.remove_status_if_current(:player, 2, :poison, first)
      assert StatusStorage.get_status(:player, 2, :poison) === newer
      assert StatusStorage.remove_status_if_current(:player, 2, :poison, newer)
      refute StatusStorage.has_status?(:player, 2, :poison)
    end

    test "does not remove a same-key reapplication with otherwise identical fields" do
      {:stored, first, nil} =
        StatusStorage.apply_status_with_entry(:player, 3, :poison, duration: 30_000)

      {:stored, second, ^first} =
        StatusStorage.apply_status_with_entry(:player, 3, :poison, duration: 30_000)

      assert first.generation != second.generation

      :ok =
        StatusStorage.update_status(:player, 3, :poison, fn entry ->
          %{
            entry
            | started_at: first.started_at,
              expires_at: first.expires_at,
              next_tick_at: first.next_tick_at
          }
        end)

      current = StatusStorage.get_status(:player, 3, :poison)
      assert %{first | generation: current.generation} === current

      refute StatusStorage.remove_status_if_current(:player, 3, :poison, first)
      assert StatusStorage.get_status(:player, 3, :poison) === current
    end
  end

  defp status_entry(generation) do
    %StatusEntry{type: :poison, generation: generation}
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
