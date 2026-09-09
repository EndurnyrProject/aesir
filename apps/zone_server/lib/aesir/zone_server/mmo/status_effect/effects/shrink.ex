defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Shrink do
  @moduledoc """
  Shrink (SC_SHRINK). The shield-gated toggle applied by CR_SHRINK; on its own it
  changes nothing and only augments a successful Guard block, driven from the Guard
  block hook through `maybe_stun_attacker/3`.

  Renewal: a blocked attacker is stunned for 5 s half of the time. Pre-renewal: a
  blocked attacker is pushed 2 cells away 5% per Guard level of the time. The
  status is a permanent, unsaved toggle dropped when the shield is unequipped.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_shrink,
    no_dispel: false,
    no_save: true,
    permanent: true,
    properties: [:buff],
    flags: [:remove_on_unequip_shield],
    icon: :cr_shrink

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrShrink
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit

  # Renewal: a fixed chance to stun the attacker on a Guard block, and the stun
  # duration. Classic: a per-Guard-level chance to push the attacker back instead.
  @stun_chance 50
  @stun_duration 5_000

  @doc """
  Reacts to `guarder` blocking a weapon hit from `attacker` with Guard at
  `guard_level`.

  A no-op unless the guarding unit currently holds Shrink. Renewal stuns the
  attacker for five seconds half of the time; pre-renewal pushes it two cells away
  from the guarder 5% per Guard level of the time.
  """
  @spec maybe_stun_attacker(
          {Unit.unit_type(), integer()},
          {Unit.unit_type(), integer()},
          pos_integer()
        ) :: :ok
  def maybe_stun_attacker({guarder_type, guarder_id} = guarder, attacker, guard_level) do
    if StatusStorage.get_status(guarder_type, guarder_id, :sc_shrink) do
      case GameMode.mode() do
        :renewal -> maybe_stun(guarder, attacker)
        :pre_renewal -> maybe_push(guarder, attacker, guard_level)
      end
    end

    :ok
  end

  def maybe_stun_attacker(_guarder, _attacker, _guard_level), do: :ok

  defp maybe_stun({guarder_type, guarder_id}, {attacker_type, attacker_id}) do
    if :rand.uniform(100) <= @stun_chance do
      StatusInterpreter.apply_status(attacker_type, attacker_id, :sc_stun,
        duration: @stun_duration,
        caster_id: guarder_id,
        source_type: guarder_type
      )
    end
  end

  defp maybe_push(guarder, {attacker_type, attacker_id}, guard_level) do
    with true <- :rand.uniform(100) <= 5 * guard_level,
         {:ok, _type, {x, y, _map_name}} <- TargetResolver.resolve_target_position(guarder) do
      Combat.knockback(attacker_type, attacker_id, x, y, CrShrink.definition().knockback)
    end
  end
end
