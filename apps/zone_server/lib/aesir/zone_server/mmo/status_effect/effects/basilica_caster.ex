defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BasilicaCaster do
  @moduledoc """
  Pre-renewal Basilica caster lock (SC_BASILICA on its caster). `val1` is the
  skill level and `val2` the sanctuary's group id.

  The caster is shielded like every occupant (no damage from non-boss sources),
  cannot attack, cannot move, and cannot cast anything except Basilica, whose
  recast ends the sanctuary. Knockback from non-boss sources cannot move it.
  Ending this status destroys the field, and the field ending removes this
  status, so either side may finish first. It ends on map change and death and
  is never saved or dispelled.

  The reference keeps caster and occupant on one status id with a discriminator;
  Aesir's status properties are static per definition, so the caster has its
  own id. Pre-renewal only.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_basilica_caster,
    no_save: true,
    no_dispel: true,
    remove_on_map_change: true,
    bypass_resistance: true,
    target_types: [:player],
    properties: [:prevents_movement, :prevents_attack, :prevents_skills],
    allow_skills: [362],
    icon: :basilica

  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Basilica
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  defdelegate absorb_damage(target, instance, hit_info, context), to: Basilica

  @impl true
  @spec on_expire(Definition.target(), StatusEntry.t(), Definition.context()) :: :ok
  def on_expire(_target, %StatusEntry{val2: group_id}, _context) when is_integer(group_id),
    do: Unit.destroy_async(group_id)

  def on_expire(_target, _entry, _context), do: :ok
end
