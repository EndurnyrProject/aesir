defmodule Aesir.ZoneServer.Mmo.Skills.Shared.BoltEcho do
  @moduledoc """
  The Double Casting echo shared by Cold Bolt, Fire Bolt and Lightning Bolt.

  After one of those bolts lands, a caster holding `:sc_doublecast` rolls its
  chance and, on success, casts the same bolt at the same level and target once
  more, one attack motion later and for free. The echo fires the bolt directly,
  never through the bolt's own `cast/4`, so it cannot echo again. A caster that
  died or warped since (a newer deferred epoch) or a target that is gone simply
  loses the echo. Identical in both modes.

  A bolt the caster's own Gravitation Field suppressed rolls no echo, and an
  echo is a fresh calculation when it fires: a classic High Wizard whose field
  started in between loses it, even when the first bolt was an exempt equipment
  proc.
  """

  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref

  @doc """
  Rolls Double Casting for a bolt the caster just landed and schedules its echo.

  `rng` is a `(pos_integer() -> pos_integer())` roll, defaulting to `&:rand.uniform/1`.
  """
  @spec maybe_schedule(
          PlayerState.t() | MobState.t(),
          Ref.t() | :suppressed,
          14 | 19 | 20,
          pos_integer(),
          (pos_integer() -> pos_integer())
        ) :: :ok
  def maybe_schedule(caster, target, bolt_id, level, rng \\ &:rand.uniform/1)

  def maybe_schedule(_caster, :suppressed, _bolt_id, _level, _rng), do: :ok

  def maybe_schedule(caster, target, bolt_id, level, rng) do
    type = caster.__struct__.get_unit_type(caster)
    id = caster.__struct__.get_unit_id(caster)

    with %{state: %{chance: chance}} <- StatusStorage.get_status(type, id, :sc_doublecast),
         true <- rng.(100) <= chance do
      payload = %{target: target, bolt_id: bolt_id, level: level, epoch: caster.deferred_epoch}
      Skill.defer(__MODULE__, payload, attack_motion_ms(caster))
    end

    :ok
  end

  @doc """
  Fires a scheduled echo unless the caster's deferred epoch moved on. Called by
  the caster's session for the `Skill.defer/3` message.
  """
  @spec deferred(map(), PlayerState.t() | MobState.t()) :: :ok | {:error, atom()}
  def deferred(%{epoch: epoch} = payload, %{deferred_epoch: epoch} = caster) do
    with {:ok, _ref} <-
           MagicAttack.execute_bolt(caster, payload.target, payload.bolt_id, payload.level, []) do
      :ok
    end
  end

  def deferred(_payload, _caster), do: {:error, :stale}

  defp attack_motion_ms(%PlayerState{stats: %{derived_stats: %{aspd: aspd}}}),
    do: max((200 - aspd) * 10, 0)

  defp attack_motion_ms(%MobState{mob_data: %{attack_motion: motion}}), do: motion
end
