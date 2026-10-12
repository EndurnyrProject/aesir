defmodule Aesir.ZoneServer.Mmo.Skill.CastendStrip do
  @moduledoc """
  The equipment lock a player's own Brandish Spear and Grand Cross put on their
  caster when the cast goes off.

  The strip status is started without removing the equipment, so it only bars
  equipping that slot for the duration; Grand Cross adds an immobilise for the
  same time. Nothing starts when the caster already holds the strip for longer.
  Only a player's ordinary and item casts do this; automatic casts and monsters
  do not.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc """
  Starts `strip` and every status in `with` on a player caster for `duration`
  milliseconds, unless the held `strip` outlasts that.
  """
  @spec start(struct(), Active.cast_origin(), atom(), pos_integer(), [atom()]) :: :ok
  def start(caster, origin, strip, duration, with \\ [])

  def start(%PlayerState{character_id: id}, origin, strip, duration, with)
      when origin in [:normal, :item] do
    until = System.monotonic_time(:millisecond) + duration

    case StatusStorage.get_status(:player, id, strip) do
      %StatusEntry{expires_at: expires_at} when is_integer(expires_at) and expires_at > until ->
        :ok

      _held ->
        for status <- [strip | with] do
          StatusInterpreter.apply_status(:player, id, status, caster_id: id, duration: duration)
        end

        :ok
    end
  end

  def start(_caster, _origin, _strip, _duration, _with), do: :ok
end
