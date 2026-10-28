defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExplosionSpirits do
  @moduledoc """
  Fury (SC_EXPLOSIONSPIRITS).

  Grants a level-scaled internal critical bonus for 180 seconds.

  For a Monk-classed player, renewal doubles the natural SP regeneration
  interval and pre-renewal stops natural SP regeneration outright; any other
  holder keeps its regeneration. A Monk Soul Link would lift this; that link is
  not implemented. The critical bonus is shared.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_explosionspirits,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    no_save: true,
    properties: [:buff],
    calc_flags: [:critical, :regen],
    duration: 180_000,
    icon: :explosionspirits,
    opt3: :explosionspirits

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas

  @impl true
  def modifiers(instance, context) do
    critical = %{critical: Formulas.fury_critical_bonus(instance.val1)}

    if JobLineage.monk_classed?(get_in(context, [:target, :job_id])),
      do: Map.merge(critical, regen_modifier(GameMode.mode())),
      else: critical
  end

  defp regen_modifier(:renewal),
    do: %{natural_sp_interval_multiplier: Formulas.fury_regeneration_tick_multiplier()}

  defp regen_modifier(:pre_renewal), do: %{no_natural_sp_regen: true}
end
