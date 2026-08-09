defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Shrink do
  @moduledoc """
  Shrink (SC_SHRINK).

  The shield-gated toggle applied by CR_SHRINK. On its own it changes nothing;
  it only augments a successful Guard block. Whenever the holder blocks a weapon
  hit with the Guard stance, Shrink gives a fixed 50% chance to Stun the blocked
  attacker for five seconds.

  The proc is driven from the Guard block hook, which calls
  `maybe_stun_attacker/2` after it intercepts a swing; the roll and stun only
  happen when the guarding unit actually holds this status. Applying the stun to
  another unit's status rows cross-process is the norm for the status store, so
  no session hand-off is needed.

  The status is a permanent toggle (`permanent: true`) that is not persisted
  across logout (`no_save: true`). The shield requirement is checked by the skill
  at cast time, and `:remove_on_unequip_shield` drops the stance if the shield is
  later unequipped without a replacement.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_shrink,
    no_dispel: false,
    no_save: true,
    permanent: true,
    properties: [:buff],
    flags: [:remove_on_unequip_shield],
    icon: :cr_shrink

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit

  # Fixed chance to stun the attacker on a Guard block, and the stun duration.
  @stun_chance 50
  @stun_duration 5_000

  @doc """
  Rolls the Shrink stun against `attacker` after `guarder` blocked a weapon hit.

  A no-op unless the guarding unit currently holds Shrink. On a successful roll
  the attacker is stunned for five seconds, sourced back to the guarder.
  """
  @spec maybe_stun_attacker(
          {Unit.unit_type(), integer()},
          {Unit.unit_type(), integer()}
        ) :: :ok
  def maybe_stun_attacker(
        {guarder_type, guarder_id},
        {attacker_type, attacker_id}
      ) do
    if StatusStorage.get_status(guarder_type, guarder_id, :sc_shrink) &&
         :rand.uniform(100) <= @stun_chance do
      StatusInterpreter.apply_status(attacker_type, attacker_id, :sc_stun,
        duration: @stun_duration,
        caster_id: guarder_id,
        source_type: guarder_type
      )
    end

    :ok
  end

  def maybe_stun_attacker(_guarder, _attacker), do: :ok
end
