defmodule Aesir.ZoneServer.Unit.Emote do
  @moduledoc """
  Emote/emoticon bubble display primitive.

  Unit-agnostic: any system (skills, items, NPCs, GM commands) can fire a
  fire-and-forget emote bubble over a unit. The readable `:et_*`-style atom
  is resolved to its numeric id at send time via `Aesir.ZoneServer.Mmo.Emotion`,
  or a numeric id can be passed directly.

  Always an area broadcast: every player in view range (including the source
  unit itself, whose own cell is within range) sees the bubble. Placed NPCs are
  not registered units, so an `{:npc, gid}` source falls back to its placement
  position in `Npc.Registry`.

  Best-effort: an unknown emote atom is logged and skipped, never raised.
  """

  require Logger

  alias Aesir.Net.Emotion, as: EmotionMsg
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Emotion
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @typedoc """
  A unit identity: a `{unit_type, unit_id}` tuple, the same key used by
  `UnitRegistry` and `SpatialIndex`.
  """
  @type source_unit :: {Unit.unit_type(), integer()}

  @doc """
  Shows an emote bubble originating from `source_unit`.

  `source_unit` is a `{unit_type, unit_id}` tuple. `emote` is either a
  readable atom (e.g. `:surprise`), resolved through `Emotion.id/1`, or a
  numeric emote id used as-is. An atom that fails to resolve logs a warning
  and sends nothing.
  """
  @spec show(source_unit(), atom() | non_neg_integer()) :: :ok
  def show(source_unit, emote) when is_atom(emote) do
    case Emotion.id(emote) do
      nil ->
        Logger.warning("Emote: unknown emote atom #{inspect(emote)}, skipping")
        :ok

      emote_id ->
        show(source_unit, emote_id)
    end
  end

  def show({_unit_type, unit_id} = source_unit, emote_id) when is_integer(emote_id) do
    packet = %EmotionMsg{gid: unit_id, type: emote_id}
    dispatch(source_unit, packet)
  end

  defp dispatch({unit_type, unit_id} = source_unit, packet) do
    case unit_position(source_unit) do
      {:ok, {x, y, map_name}} ->
        Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet, [])

      {:error, :not_found} ->
        Logger.debug("Emote: unit #{inspect({unit_type, unit_id})} has no position")
        :ok
    end
  end

  # Placed NPCs are not registered units: their position comes from the
  # placement index that the script layer resolves NPC ids against.
  defp unit_position({:npc, unit_id}) do
    case SpatialIndex.get_unit_position(:npc, unit_id) do
      {:ok, position} ->
        {:ok, position}

      {:error, :not_found} ->
        case NpcRegistry.module_for_unit(unit_id) do
          {:ok, {_module, placement}} -> {:ok, {placement.x, placement.y, placement.map}}
          :error -> {:error, :not_found}
        end
    end
  end

  defp unit_position({unit_type, unit_id}), do: SpatialIndex.get_unit_position(unit_type, unit_id)
end
