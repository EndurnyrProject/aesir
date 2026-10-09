defmodule Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror do
  @moduledoc """
  Copies of a Crusader's Guard, Defending Aura, Reflect Shield and Endure on
  the party members it devotes.

  The four statuses call in from their own lifecycle hooks, so every source and
  every end path is covered:

    * `started/4`: a player's own status (not a copy) starting copies itself
      onto every current devotee with the same values and remaining duration.
      Endure is not copied on siege ground or when it is infinite (`val4`).
    * `ended/2`: any end of a player's status (toggle-off, Dispel, Hermode,
      expiry, death) ends that status on every current devotee, whoever started
      the devotee's copy, except an infinite Endure.
    * `copy_to_devotee/2`: a fresh link copies the Crusader's active statuses at
      its level for their full skill duration, without the values the status
      computes when it starts on its own (an inherited Guard never blocks, an
      inherited Defending Aura neither reduces damage nor slows attacks).
    * `end_inherited/1`: a devotee's link ending ends all four statuses on it,
      whoever started them, except an infinite Endure.

  A copy carries `mirrored_from: crusader_id` in its state and never copies
  itself further. Copies of Guard, Reflect Shield and Endure show no icon; an
  inherited Reflect Shield is marked `inherited: true`.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @mirrored_statuses [:sc_autoguard, :sc_defender, :sc_reflectshield, :sc_endure]
  @link_order [:sc_endure, :sc_reflectshield, :sc_defender, :sc_autoguard]

  @doc "The statuses Devotion copies onto devotees."
  @spec mirrored_statuses() :: [atom()]
  def mirrored_statuses, do: @mirrored_statuses

  @doc "Whether `instance` is a devotee's copy of a Crusader's status."
  @spec copy?(StatusEntry.t()) :: boolean()
  def copy?(%StatusEntry{state: %{mirrored_from: _crusader_id}}), do: true
  def copy?(%StatusEntry{}), do: false

  @doc """
  Copies a player's own status, as it starts with `state` and `duration`, onto
  each of its current devotees.
  """
  @spec started({atom(), integer()}, StatusEntry.t(), map(), non_neg_integer() | nil) :: :ok
  def started({:player, crusader_id}, %StatusEntry{type: status_id} = instance, state, duration)
      when status_id in @mirrored_statuses and is_integer(duration) do
    if copied_on_start?(crusader_id, instance) do
      crusader_id
      |> DevotedBy.devotee_ids()
      |> Enum.each(&apply_copy(&1, crusader_id, instance, state, duration))
    end

    :ok
  end

  def started(_holder, _instance, _state, _duration), do: :ok

  @doc "Ends the status `instance` ended on every current devotee of its player holder."
  @spec ended({atom(), integer()}, StatusEntry.t()) :: :ok
  def ended({:player, crusader_id}, %StatusEntry{type: status_id, generation: generation})
      when status_id in @mirrored_statuses and is_integer(generation) do
    crusader_id
    |> DevotedBy.devotee_ids()
    |> Enum.each(&end_status(&1, status_id))
  end

  def ended(_holder, _instance), do: :ok

  @doc """
  Copies every status the Crusader holds onto a freshly linked devotee, at the
  Crusader's level for the status's full skill duration.
  """
  @spec copy_to_devotee(non_neg_integer(), non_neg_integer()) :: :ok
  def copy_to_devotee(crusader_id, devotee_id) do
    @link_order
    |> Enum.reject(&(&1 == :sc_endure and siege_ground?(devotee_id)))
    |> Enum.each(fn status_id ->
      case StatusStorage.get_status(:player, crusader_id, status_id) do
        %StatusEntry{val1: level} -> link_copy(devotee_id, crusader_id, status_id, level)
        nil -> :ok
      end
    end)
  end

  @doc "Ends every mirrored status on a devotee whose link ended."
  @spec end_inherited(non_neg_integer()) :: :ok
  def end_inherited(devotee_id), do: Enum.each(@mirrored_statuses, &end_status(devotee_id, &1))

  # Ending a status this way never ends an infinite Endure.
  defp end_status(player_id, status_id) do
    case StatusStorage.get_status(:player, player_id, status_id) do
      %StatusEntry{type: :sc_endure, val4: val4} when val4 != 0 -> :ok
      %StatusEntry{} -> Interpreter.remove_status(:player, player_id, status_id)
      nil -> :ok
    end
  end

  defp copied_on_start?(crusader_id, %StatusEntry{type: :sc_endure} = instance),
    do: not copy?(instance) and instance.val4 == 0 and not siege_ground?(crusader_id)

  defp copied_on_start?(_crusader_id, instance), do: not copy?(instance)

  defp apply_copy(devotee_id, crusader_id, instance, state, duration) do
    params = [
      val1: instance.val1,
      val2: instance.val2,
      val3: instance.val3,
      val4: instance.val4,
      duration: duration,
      state: copy_state(instance.type, state, crusader_id, false)
    ]

    start_copy(devotee_id, crusader_id, instance.type, params)
  end

  defp link_copy(devotee_id, crusader_id, status_id, level) do
    params = [
      val1: level,
      duration: link_duration(status_id, level),
      state: copy_state(status_id, %{}, crusader_id, true)
    ]

    start_copy(devotee_id, crusader_id, status_id, params)
  end

  defp start_copy(devotee_id, crusader_id, status_id, params) do
    flag = if status_id == :sc_defender, do: 0, else: StatusEntry.no_icon_flag()

    _ =
      Interpreter.apply_status(
        :player,
        devotee_id,
        status_id,
        params ++ [caster_id: crusader_id, no_avoid: true, flag: flag]
      )

    :ok
  end

  # A started copy keeps the values its Crusader's status computed; a link copy
  # starts without them. An inherited Reflect Shield is marked as such.
  defp copy_state(:sc_reflectshield, state, crusader_id, _link?),
    do: Map.merge(state, %{mirrored_from: crusader_id, inherited: true})

  defp copy_state(:sc_autoguard, _state, crusader_id, true),
    do: %{mirrored_from: crusader_id, block_chance: 0}

  defp copy_state(:sc_defender, _state, crusader_id, true),
    do: %{mirrored_from: crusader_id, reduction: 0, aspd_penalty: 0}

  defp copy_state(_status_id, state, crusader_id, _link?),
    do: Map.put(state, :mirrored_from, crusader_id)

  defp link_duration(:sc_endure, level) do
    {:ok, %{duration: durations}} = Catalog.by_name(:sm_endure)
    Enum.at(durations, min(level, length(durations)) - 1)
  end

  defp link_duration(status_id, _level), do: Registry.get_definition(status_id).duration

  defp siege_ground?(player_id) do
    case SpatialIndex.get_unit_position(:player, player_id) do
      {:ok, {_x, _y, map_name}} -> Rules.ground?(map_name)
      _ -> false
    end
  end
end
