defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy do
  @moduledoc """
  Devotion provider bookkeeping (SC_DEVOTED_BY).

  The single entry a Crusader holds while devoting one or more party members.
  Storage keeps one instance per status type per unit, so the whole devotee set
  lives in this one entry's state as a map keyed by devotee id:

      %{links: %{devotee_id => %{peer: {:player, devotee_id}, link_id: ref}}}

  This deviates from the one-entry-per-devotee shape the task text sketched,
  but keeps the same acceptance semantics: the slot cap is the map size, and
  every teardown is per devotee. The paired record is the devotee's
  `sc_devotion`; the two are matched by a shared `link_id` per devotee, the
  Blade Stop / Root precedent.

  Teardown is edge-triggered plus convergent, with no coordinator:

    * removing this entry (map change, death, manual) cascades removal of every
      devotee's `sc_devotion`; each devotee's back-reference is cleared first so
      its own `on_expire` finds no peer and the removal echo terminates;
    * a per-second tick drops any devotee link whose `sc_devotion` record (same
      link id) or whose unit has vanished, removing the whole entry once the map
      empties - the case a terminating session that cleared status storage
      directly leaves behind.

  The entry is permanent: the finite lifetime lives on the devotee's
  `sc_devotion`, and the per-devotee cascade plus the self-heal tick retire this
  entry. It is not persisted (`no_save`) and ends on a cross-map warp
  (`remove_on_map_change`): the pairing is tied to live units on one map.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_devoted_by,
    no_dispel: false,
    no_save: true,
    remove_on_map_change: true,
    permanent: true,
    properties: [:buff],
    target_types: [:player],
    tick_interval: 1_000

  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @devotion :sc_devotion

  @doc """
  Adds or refreshes `devotee_id`'s link on the Crusader's entry, creating the
  entry on the first devotee. A repeat cast on an already-linked devotee
  overwrites its link id, keeping the map a single entry per devotee.
  """
  @spec link(non_neg_integer(), non_neg_integer(), reference()) :: :ok | {:error, atom()}
  def link(crusader_id, devotee_id, link_id) do
    entry = %{peer: {:player, devotee_id}, link_id: link_id}

    case StatusStorage.get_status(:player, crusader_id, :sc_devoted_by) do
      %StatusEntry{state: %{links: links}} ->
        StatusStorage.update_status(:player, crusader_id, :sc_devoted_by, fn stored ->
          %{stored | state: %{stored.state | links: Map.put(links, devotee_id, entry)}}
        end)

      _ ->
        Interpreter.apply_status(:player, crusader_id, :sc_devoted_by,
          caster_id: crusader_id,
          state: %{links: %{devotee_id => entry}}
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
      %StatusEntry{state: %{links: %{^devotee_id => %{link_id: ^link_id}} = links}} ->
        remaining = Map.delete(links, devotee_id)

        StatusStorage.update_status(:player, crusader_id, :sc_devoted_by, fn stored ->
          %{stored | state: %{stored.state | links: remaining}}
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
  def count(crusader_id) do
    case StatusStorage.get_status(:player, crusader_id, :sc_devoted_by) do
      %StatusEntry{state: %{links: links}} -> map_size(links)
      _ -> 0
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
  def on_expire({_type, crusader_id}, %StatusEntry{state: %{links: links}}, _context) do
    Enum.each(links, fn {devotee_id, %{link_id: link_id}} ->
      close_devotee(crusader_id, devotee_id, link_id)
    end)

    :ok
  end

  def on_expire(_target, _instance, _context), do: :ok

  @impl true
  def on_tick({_type, crusader_id}, %StatusEntry{state: %{links: links}} = instance, _context) do
    {live, stale} =
      Map.split_with(links, fn {devotee_id, %{link_id: link_id}} ->
        devotee_intact?(devotee_id, link_id)
      end)

    Enum.each(stale, fn {devotee_id, _link} ->
      DevotionMirror.remove_from_devotee(crusader_id, devotee_id)
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
  defp close_devotee(crusader_id, devotee_id, link_id) do
    case StatusStorage.get_status(:player, devotee_id, @devotion) do
      %StatusEntry{state: %{link_id: ^link_id}} ->
        DevotionMirror.remove_from_devotee(crusader_id, devotee_id)

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
