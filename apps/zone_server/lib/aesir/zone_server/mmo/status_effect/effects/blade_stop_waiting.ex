defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BladeStopWaiting do
  @moduledoc """
  Root ready stance (SC_BLADESTOP_WAIT).

  A single-use waiting entry applied to the Monk by MO_BLADESTOP, carrying the
  Monk's Root level and immobilizing them while armed. The next eligible swing
  against the Monk claims it atomically and establishes the paired `sc_bladestop`
  Root on both the Monk and the attacker, suppressing that swing. A lost race
  leaves the entry intact and the hit resolves normally.

  Eligibility, per the Renewal source: a player attacker is always caught (ranged
  weapons included); a monster attacker is caught only when it swings from within
  two cells. A boss attacker is caught too, but the pair only lasts two seconds.

  Establishment happens synchronously inside the attacking unit's swing: the
  claim is the same atomic single-use take the Lex Aeterna hit path uses, and the
  paired records are written through the ordinary cross-process status path every
  debuff already uses. There is no coordinator, offer, or cross-session message.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_bladestop_wait,
    no_dispel: false,
    no_save: true,
    remove_on_map_change: true,
    properties: [:buff, :prevents_movement],
    flags: [:no_move],
    icon: :bladestopready

  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit

  # Renewal `check_distance_bl(src, target, 2)`: a monster attacker is caught only
  # when it swings from within this cell distance. Players bypass the gate.
  @mob_catch_distance 2

  @impl true
  @spec before_weapon_hit(
          {Unit.unit_type(), integer()},
          StatusEntry.t(),
          map(),
          map()
        ) :: :continue | {:intercept, :blade_stop}
  def before_weapon_hit({unit_type, unit_id}, _instance, attack_info, _context) do
    if eligible?(attack_info) do
      claim(unit_type, unit_id, attack_info)
    else
      :continue
    end
  end

  # Only a basic weapon swing arms the catch; weapon skills tagged
  # `basic_attack?: false` pass through. A player attacker is always eligible; a
  # monster attacker only within cell distance. Boss-ness does not gate
  # eligibility - it only shortens the pair.
  defp eligible?(attack_info) do
    Map.get(attack_info, :basic_attack?, true) and eligible_attacker?(attack_info)
  end

  defp eligible_attacker?(%{attacker: {:player, _}}), do: true

  defp eligible_attacker?(%{attacker: {:mob, _}, distance: distance}) when is_integer(distance),
    do: distance <= @mob_catch_distance

  defp eligible_attacker?(_attack_info), do: false

  defp claim(unit_type, unit_id, attack_info) do
    case StatusStorage.take_status(unit_type, unit_id, :sc_bladestop_wait) do
      nil ->
        :continue

      %StatusEntry{val1: monk_root_level} ->
        establish(unit_type, unit_id, monk_root_level, attack_info)
    end
  end

  defp establish(monk_type, monk_id, monk_root_level, attack_info) do
    %{
      attacker: {attacker_type, attacker_id} = attacker,
      attacker_boss?: boss?,
      attacker_root_level: attacker_root_level
    } = attack_info

    link_id = make_ref()
    monk = {monk_type, monk_id}
    duration = Formulas.root_duration(boss?)

    apply_pair(monk_type, monk_id, monk_id, duration, %{
      peer: attacker,
      link_id: link_id,
      root_level: monk_root_level
    })

    apply_pair(attacker_type, attacker_id, monk_id, duration, %{
      peer: monk,
      link_id: link_id,
      root_level: attacker_root_level
    })

    {:intercept, :blade_stop}
  end

  # Applies one side of the pair. The Monk is always the caster and always a
  # player, so `source_type: :player` keeps a cross-type application (a caught
  # mob) resolving its caster correctly. Each side stores its OWN Root level: the
  # Monk's cast level and the attacker's own learned level (0 for a non-Monk, 5
  # for a monster), so a caught Monk can drive their own follow-ups.
  # NOTE: the claim already consumed the waiting entry, so the swing is caught
  # even if one side's application fails; the per-tick peer check converges any
  # half-open pair rather than trying to unwind here.
  defp apply_pair(unit_type, unit_id, monk_id, duration, state) do
    Interpreter.apply_status(unit_type, unit_id, :sc_bladestop,
      caster_id: monk_id,
      source_type: :player,
      duration: duration,
      state: state
    )
  end
end
