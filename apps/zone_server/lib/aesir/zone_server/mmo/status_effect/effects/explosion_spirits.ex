defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExplosionSpirits do
  @moduledoc """
  Fury (SC_EXPLOSIONSPIRITS).

  Grants a level-scaled internal critical bonus for 180 seconds.

  Renewal doubles the SP regeneration interval; pre-renewal stops natural SP
  regeneration outright. The critical bonus is shared.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_explosionspirits,
    no_dispel: false,
    no_save: true,
    properties: [:buff],
    calc_flags: [:critical, :regen],
    duration: 180_000,
    icon: :explosionspirits,
    opt3: :explosionspirits

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas

  @impl true
  def modifiers(instance, _context) do
    critical = Formulas.fury_critical_bonus(instance.val1)

    case GameMode.mode() do
      :renewal ->
        %{
          critical: critical,
          regen_interval_multiplier: Formulas.fury_regeneration_tick_multiplier()
        }

      :pre_renewal ->
        %{critical: critical, sp_regen: -100}
    end
  end
end
