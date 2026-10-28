defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExtremityFistRecovery do
  @moduledoc """
  Asura recovery (SC_EXTREMITYFIST).

  The self-inflicted aftermath of an Asura Strike. It is non-persistent and
  cannot be dispelled, and while it lasts a Monk-classed player's natural SP
  regeneration stops, so the drained pool cannot immediately refill (skill SP
  regeneration continues). Any other holder is unaffected. A Monk Soul Link
  would lift the stop; that link is not implemented. The equivalent freeze on
  the caster's actions is the skill's after-cast delay, committed by the skill
  interpreter, not this status.

  Renewal halts SP regeneration for 3 s after the strike; pre-renewal for 5 minutes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_extremityfist,
    no_dispel: true,
    no_clear_buff: false,
    clear_buff_flags: [:debuff],
    no_save: true,
    bypass_resistance: true,
    properties: [:debuff],
    calc_flags: [:regen],
    duration: 3_000,
    icon: :extremityfist

  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage

  @impl true
  def modifiers(_instance, context) do
    if JobLineage.monk_classed?(get_in(context, [:target, :job_id])),
      do: %{no_natural_sp_regen: true},
      else: %{}
  end
end
