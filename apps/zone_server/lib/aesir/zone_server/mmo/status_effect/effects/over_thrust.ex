defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.OverThrust do
  @moduledoc """
  Percentage physical-attack buff (SC_OVERTHRUST).

  The caster supplies the percent per application in `val1` (the caster's own
  buff is stronger than the party version at the same skill level), so this
  definition carries no per-level table. It adds to every weapon attack's skill
  ratio (`skill_ratio`). The pre-renewal 0.1% weapon-break chance on the
  caster's attacks is not modelled; renewal has none.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_overthrust,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:atk],
    icon: :overthrust

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition

  @impl true
  def modifiers(instance, _context), do: %{skill_ratio: instance.val1}

  @impl true
  def overlap(target, held, incoming),
    do: Definition.self_cast_overlap(target, held, incoming)
end
