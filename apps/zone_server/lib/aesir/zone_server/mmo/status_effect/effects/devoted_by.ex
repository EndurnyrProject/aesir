defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy do
  @moduledoc """
  Devotion provider bookkeeping (SC_DEVOTED_BY).

  The single entry a Crusader holds while devoting one or more party members.
  Storage keeps one instance per status type per unit, so the whole devotee set
  lives in this one entry's state as a map keyed by devotee id:

      %{links: %{devotee_id => %{peer: {:player, devotee_id}, link_id: ref, slot: 0}},
        slots: %{0 => devotee_id}}

  `links` holds one record per devotee (the map keyed by devotee id), while
  `slots` mirrors the reference's fixed five-slot array. A cast opens only the
  first `min(level, 5)` slots: a devotee already holding one of them keeps it,
  and a new one takes the first free slot among them, so a slot freed by a
  devotion ending is reusable. This deviates from the one-entry-per-devotee
  shape the task text sketched, but keeps the same acceptance semantics: every
  teardown is per devotee. The paired record is the devotee's `sc_devotion`;
  the two are matched by a shared `link_id` per devotee, the Blade Stop / Root
  precedent.

  Teardown is edge-triggered plus convergent, with no coordinator:

    * removing this entry (death, manual) cascades removal of every
      devotee's `sc_devotion`; each devotee's back-reference is cleared first so
      its own `on_expire` finds no peer and the removal echo terminates. The
      Crusader leaving the world drops the entry without that cascade: its
      devotees keep their record until a hit finds no Crusader devoting them;
    * a per-second tick drops any devotee link whose `sc_devotion` record (same
      link id) or whose unit has vanished, removing the whole entry once the map
      empties - the case a terminating session that cleared status storage
      directly leaves behind.

  The entry is permanent: the finite lifetime lives on the devotee's
  `sc_devotion`, and the per-devotee cascade plus the self-heal tick retire this
  entry. It is not persisted (`no_save`). A warp of the Crusader keeps it: a devotee's
  record ends on a hit that finds its Crusader out of range.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_devoted_by,
    no_dispel: true,
    no_clear_buff: true,
    engine_only: true,
    no_save: true,
    permanent: true,
    properties: [:buff],
    target_types: [:player],
    tick_interval: 1_000

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @devotion :sc_devotion
  @max_slots 5

  @doc "The number of slots a cast of `level` opens."
  @spec slots(pos_integer()) :: non_neg_integer()
  def slots(level), do: min(level, @max_slots)

  @doc """
  The slot `devotee_id` holds within the ones a cast of `level` opens, the
  first free one among them, or `:full` when every one of them is taken.

  The slots behave as the reference's fixed array: only the first `min(level, 5)`
  entries are searched, and an entry is free once the devotee holding it is no
  longer linked.
  """
  @spec place(non_neg_integer(), non_neg_integer(), pos_integer()) ::
          {:ok, non_neg_integer()} | :full
  def place(crusader_id, devotee_id, level) do
    occupied = current_slots(crusader_id)
    open = 0..(slots(level) - 1)//1

    case Enum.find(open, &(Map.get(occupied, &1) == devotee_id)) do
      nil ->
        case Enum.find(open, &(not Map.has_key?(occupied, &1))) do
          nil -> :full
          slot -> {:ok, slot}
        end

      slot ->
        {:ok, slot}
    end
  end

  @doc """
  Adds or refreshes `devotee_id`'s link on the Crusader's entry, creating the
  entry on the first devotee. A repeat cast on an already-linked devotee
  overwrites its link id, keeping the map a single entry per devotee, and keeps
  the slot it already held.
  """
  @spec link(non_neg_integer(), non_neg_integer(), reference()) :: :ok | {:error, atom()}
  def link(crusader_id, devotee_id, link_id) do
    case place(crusader_id, devotee_id, @max_slots) do
      {:ok, slot} -> link(crusader_id, devotee_id, link_id, slot)
      :full -> {:error, :no_slot}
    end
  end

  @doc "Adds or refreshes `devotee_id`'s link in `slot`."
  @spec link(non_neg_integer(), non_neg_integer(), reference(), non_neg_integer()) ::
          :ok | {:error, atom()}
  def link(crusader_id, devotee_id, link_id, slot) do
    entry = %{peer: {:player, devotee_id}, link_id: link_id, slot: slot}

    case StatusStorage.get_status(:player, crusader_id, :sc_devoted_by) do
      %StatusEntry{} ->
        StatusStorage.update_status(:player, crusader_id, :sc_devoted_by, fn stored ->
          status_state =
            stored.state
            |> Map.put(:links, Map.put(current_links(crusader_id), devotee_id, entry))
            |> Map.put(:slots, Map.put(current_slots(crusader_id), slot, devotee_id))

          %{stored | state: status_state}
        end)

      _ ->
        Interpreter.apply_status(:player, crusader_id, :sc_devoted_by,
          caster_id: crusader_id,
          state: %{links: %{devotee_id => entry}, slots: %{slot => devotee_id}}
        )
    end
  end

  @doc """
  Removes `devotee_id`'s link (only when its stored link id matches `link_id`),
  retiring the whole entry once the last devotee leaves. The map is emptied
  before the entry is removed so the removal cascade sees no links and does not
  echo back into the departing devotee.
  """
  @spec unlink(non_neg_integer(), non_neg_integer(), reference()) :: :ok
  def unlink(crusader_id, devotee_id, link_id) do
    case StatusStorage.get_status(:player, crusader_id, :sc_devoted_by) do
      %StatusEntry{state: %{links: %{^devotee_id => %{link_id: ^link_id} = link} = links}} ->
        remaining = Map.delete(links, devotee_id)
        slots = release_slot(current_slots(crusader_id), Map.get(link, :slot), devotee_id)

        StatusStorage.update_status(:player, crusader_id, :sc_devoted_by, fn stored ->
          status_state = stored.state |> Map.put(:links, remaining) |> Map.put(:slots, slots)
          %{stored | state: status_state}
        end)

        if map_size(remaining) == 0 do
          Interpreter.remove_status(:player, crusader_id, :sc_devoted_by)
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  @doc "Current number of devotees the Crusader holds."
  @spec count(non_neg_integer()) :: non_neg_integer()
  def count(crusader_id), do: map_size(current_links(crusader_id))

  defp current_links(crusader_id) do
    case StatusStorage.get_status(:player, crusader_id, :sc_devoted_by) do
      %StatusEntry{state: %{links: links}} -> links
      _ -> %{}
    end
  end

  defp current_slots(crusader_id) do
    case StatusStorage.get_status(:player, crusader_id, :sc_devoted_by) do
      %StatusEntry{state: %{slots: slots}} -> slots
      _ -> %{}
    end
  end

  # Ends the devotee's hold on its last slot only; an entry the devotee left in
  # another slot by a later cast stays set, as the reference's array does.
  defp release_slot(slots, slot, devotee_id) do
    case Map.fetch(slots, slot) do
      {:ok, ^devotee_id} -> Map.delete(slots, slot)
      _other -> slots
    end
  end

  @doc "Whether `devotee_id` is already a devotee of the Crusader."
  @spec linked?(non_neg_integer(), non_neg_integer()) :: boolean()
  def linked?(crusader_id, devotee_id) do
    match?(
      %StatusEntry{state: %{links: %{^devotee_id => _}}},
      StatusStorage.get_status(:player, crusader_id, :sc_devoted_by)
    )
  end

  @doc "The ids of every party member the Crusader currently devotes."
  @spec devotee_ids(non_neg_integer()) :: [non_neg_integer()]
  def devotee_ids(crusader_id) do
    case StatusStorage.get_status(:player, crusader_id, :sc_devoted_by) do
      %StatusEntry{state: %{links: links}} -> Map.keys(links)
      _ -> []
    end
  end

  @impl true
  def on_expire(_target, %StatusEntry{state: %{links: links}}, _context) do
    Enum.each(links, fn {devotee_id, %{link_id: link_id}} ->
      close_devotee(devotee_id, link_id)
    end)

    :ok
  end

  def on_expire(_target, _instance, _context), do: :ok

  @impl true
  def on_tick(_target, %StatusEntry{state: %{links: links}} = instance, _context) do
    live =
      Map.filter(links, fn {devotee_id, %{link_id: link_id}} ->
        devotee_intact?(devotee_id, link_id)
      end)

    if map_size(live) == 0 do
      :remove
    else
      {:ok, %{instance | state: %{instance.state | links: live}}}
    end
  end

  def on_tick(_target, instance, _context), do: {:ok, instance}

  # Ends one devotee's `sc_devotion` through the ordinary removal path, clearing
  # its back-reference first so its own `on_expire` sees no peer and the echo
  # into this (departing) entry terminates.
  defp close_devotee(devotee_id, link_id) do
    case StatusStorage.get_status(:player, devotee_id, @devotion) do
      %StatusEntry{state: %{link_id: ^link_id}} ->
        StatusStorage.update_status(:player, devotee_id, @devotion, fn entry ->
          %{entry | state: Map.put(entry.state, :peer, nil)}
        end)

        Interpreter.remove_status(:player, devotee_id, @devotion)

      _ ->
        :ok
    end
  end

  defp devotee_intact?(devotee_id, link_id) do
    match?(
      %StatusEntry{state: %{link_id: ^link_id}},
      StatusStorage.get_status(:player, devotee_id, @devotion)
    ) and alive?(devotee_id)
  end

  defp alive?(unit_id) do
    case UnitRegistry.get_unit(:player, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _ -> false
    end
  end
end
