defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SubWeaponProperty do
  @moduledoc """
  Secondary Weapon Property (SC_SUB_WEAPONPROPERTY).

  A partial weapon property: the carrier's attacks keep their own element and
  additionally deal `val2` percent of themselves as `val1` element damage,
  resolved against the victim separately from the main hit. Magnum Break's
  ten-second fire aura is the only source today.

  This is deliberately *not* an endow. It sits beside the weapon endows rather
  than replacing them, so it neither lists them in `end_on_start` nor appears in
  theirs: a swordsman under Aspersio who casts Magnum Break keeps both, exactly
  as the aura and an endow stack in renewal. Recasting refreshes it, since
  applying a status that is already live replaces the live instance.

  Renewal only. Classic has no separate slot for this and expresses the same
  aura through the shared weapon-element property status, which does collide
  with endows; Magnum Break selects between the two by mode.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sub_weaponproperty,
    no_dispel: false,
    properties: [:buff],
    icon: :sub_weaponproperty,
    no_save: true

  alias Aesir.ZoneServer.Mmo.Element

  @impl true
  def modifiers(%{val1: element_id, val2: percent}, _context)
      when is_integer(percent) and percent > 0 do
    %{{:pseudo_element_atk, Element.from_id!(element_id)} => percent}
  end

  def modifiers(_instance, _context), do: %{}
end
