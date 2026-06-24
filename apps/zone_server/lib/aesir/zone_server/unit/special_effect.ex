defmodule Aesir.ZoneServer.Unit.SpecialEffect do
  @moduledoc """
  One-shot `EF_*` special-effect primitive.

  Status-agnostic: any system (skills, items, NPCs, GM commands, and the status
  apply path) can fire a fire-and-forget sprite burst on a unit. The readable
  `:ef_*` atom is resolved to its rAthena numeric id at send time via
  `Aesir.ZoneServer.Mmo.EffectId`.

  Best-effort: an unknown effect atom is logged and skipped, never raised.
  """

  require Logger

  alias Aesir.Net.SpecialEffect, as: SpecialEffectMsg
  alias Aesir.ZoneServer.Mmo.EffectId
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @view_range 14

  @typedoc """
  A unit identity: a `{unit_type, unit_id}` tuple, the same key used by
  `UnitRegistry` and `SpatialIndex`.
  """
  @type source_unit :: {Unit.unit_type(), integer()}

  @typedoc "Who receives the effect: every in-range player, or only the source unit."
  @type target :: :area | :self

  @doc """
  Plays a one-shot `EF_*` effect originating from `source_unit`.

  `source_unit` is a `{unit_type, unit_id}` tuple. `effect_atom` is a readable
  `:ef_*` atom (e.g. `:hit1`); if it does not resolve through `EffectId.id/1`,
  the call logs a warning and sends nothing.

  `target`:
    - `:area` (default) — broadcasts to every player in view range of the unit.
    - `:self` — sends only to the source unit (treated as a player char id).
  """
  @spec play(source_unit(), atom(), target()) :: :ok
  def play(source_unit, effect_atom, target \\ :area)

  def play({_unit_type, unit_id} = source_unit, effect_atom, target) do
    case EffectId.id(effect_atom) do
      nil ->
        Logger.warning("SpecialEffect: unknown effect atom #{inspect(effect_atom)}, skipping")
        :ok

      effect_id ->
        packet = %SpecialEffectMsg{source_id: unit_id, effect_id: effect_id}
        dispatch(source_unit, packet, target)
    end
  end

  defp dispatch({:player, unit_id}, packet, :self) do
    Broadcast.to_player(unit_id, packet)
  end

  defp dispatch({unit_type, unit_id}, packet, :area) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, map_name}} ->
        Broadcast.to_in_range(map_name, x, y, @view_range, packet, [])

      {:error, :not_found} ->
        Logger.debug("SpecialEffect: unit #{inspect({unit_type, unit_id})} has no position")
        :ok
    end
  end
end
