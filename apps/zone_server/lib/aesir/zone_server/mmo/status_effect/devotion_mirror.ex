defmodule Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror do
  @moduledoc """
  Mirroring of a Crusader's defensive toggles onto its devotees.

  Devotion copies the Crusader's active Guard / Defender / Reflect Shield onto
  every linked party member: the mirrored copy carries the Crusader's own skill
  level and a `mirrored_from: crusader_id` state flag, and it never re-fans
  (fan-out lives only in the Crusader's toggle-skill cast path, so a mirrored
  status on a devotee has no path back into this module).

  Three edges drive the mirror set, all cross-process writes to the devotee's
  status rows (the norm for `StatusStorage`):

    * a fresh link copies the Crusader's currently active toggles onto the new
      devotee (`copy_to_devotee/2`);
    * toggling a mirrored skill on or off fans the same apply/remove to every
      current devotee (`fan_toggle/5`), a no-op when the caster holds none;
    * a breaking link strips that devotee's mirrored entries
      (`remove_from_devotee/2`), leaving any genuinely self-owned copy in place
      and never touching the other devotees.

  Mirrored entries carry no shield requirement (that gate is the Crusader's, at
  cast) and are not persisted (the underlying statuses are already `no_save`).
  """
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @mirrored_statuses [:sc_autoguard, :sc_defender, :sc_reflectshield]

  @doc "The defensive toggles Devotion mirrors onto devotees."
  @spec mirrored_statuses() :: [atom()]
  def mirrored_statuses, do: @mirrored_statuses

  @doc """
  Copies every currently active mirrored toggle from the Crusader onto a
  freshly linked devotee, at the Crusader's own level.
  """
  @spec copy_to_devotee(non_neg_integer(), non_neg_integer()) :: :ok
  def copy_to_devotee(crusader_id, devotee_id) do
    Enum.each(@mirrored_statuses, fn status_id ->
      case StatusStorage.get_status(:player, crusader_id, status_id) do
        %StatusEntry{val1: level} -> apply_mirror(devotee_id, status_id, level, crusader_id)
        _ -> :ok
      end
    end)
  end

  @doc """
  Fans a Crusader's toggle of `status_id` (`:applied` or `:removed`) out to all
  of its current devotees. A no-op for a non-player caster or a Crusader with no
  devotees, keeping it zero-cost off the Devotion path.
  """
  @spec fan_toggle(atom(), non_neg_integer(), atom(), :applied | :removed, pos_integer()) :: :ok
  def fan_toggle(:player, crusader_id, status_id, action, level)
      when status_id in @mirrored_statuses do
    case DevotedBy.devotee_ids(crusader_id) do
      [] -> :ok
      devotee_ids -> Enum.each(devotee_ids, &fan_one(&1, status_id, action, level, crusader_id))
    end
  end

  def fan_toggle(_unit_type, _crusader_id, _status_id, _action, _level), do: :ok

  @doc """
  Removes every mirrored entry this Crusader placed on `devotee_id`, used when
  the link between them breaks. Only entries flagged `mirrored_from: crusader_id`
  are removed; a devotee's own copy of the same status is left untouched.
  """
  @spec remove_from_devotee(non_neg_integer(), non_neg_integer()) :: :ok
  def remove_from_devotee(crusader_id, devotee_id) do
    Enum.each(@mirrored_statuses, &remove_mirror(devotee_id, &1, crusader_id))
  end

  defp fan_one(devotee_id, status_id, :applied, level, crusader_id),
    do: apply_mirror(devotee_id, status_id, level, crusader_id)

  defp fan_one(devotee_id, status_id, :removed, _level, crusader_id),
    do: remove_mirror(devotee_id, status_id, crusader_id)

  defp apply_mirror(devotee_id, status_id, level, crusader_id) do
    Interpreter.apply_status(:player, devotee_id, status_id,
      val1: level,
      state: %{mirrored_from: crusader_id}
    )

    :ok
  end

  defp remove_mirror(devotee_id, status_id, crusader_id) do
    case StatusStorage.get_status(:player, devotee_id, status_id) do
      %StatusEntry{state: %{mirrored_from: ^crusader_id}} ->
        Interpreter.remove_status(:player, devotee_id, status_id)
        :ok

      _ ->
        :ok
    end
  end
end
