defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SubWeaponProperty do
  @moduledoc """
  Secondary Weapon Property (SC_SUB_WEAPONPROPERTY).

  A partial weapon property: the carrier's attacks keep their own element and
  additionally deal `val2` percent of themselves as `val1` element damage,
  resolved against the victim separately from the main hit. Magnum Break
  grants a ten-second fire aura; Enchant Deadly Poison grants a poison aura.

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
    remove_on_death: false,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    icon: :sub_weaponproperty

  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Edp
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec resolve_duration(Definition.target(), StatusEntry.t(), pos_integer()) ::
          {pos_integer(), StatusEntry.t()}
  def resolve_duration(target, %{val3: 378} = entry, duration),
    do: {duration + Edp.duration_bonus(target), entry}

  def resolve_duration(_target, entry, duration), do: {duration, entry}

  @impl true
  def modifiers(%{val1: element_id, val2: percent}, _context)
      when is_integer(percent) and percent > 0 do
    %{{:pseudo_element_atk, Element.from_id!(element_id)} => percent}
  end

  def modifiers(_instance, _context), do: %{}
end
