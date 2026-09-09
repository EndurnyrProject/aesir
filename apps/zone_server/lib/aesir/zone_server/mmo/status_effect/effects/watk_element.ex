defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElement do
  @moduledoc """
  Weapon Element Property (SC_WATK_ELEMENT).

  Carries a weapon element in `val1` and serves two shapes, chosen by `val2`.

  With no `val2`, it is a full endow: the carrier's physical attack element
  becomes `val1` for the buff duration, exposed as the `attack_element`
  modifier the damage calculator prefers over the weapon's base element. Every
  endow contributes that same modifier and aggregation sums colliding keys, so
  the endows list each other in `end_on_start` (replace-on-cast) to keep two of
  them from ever being live at once.

  With a `val2` percentage, it is a partial property instead: the attack keeps
  its own element and additionally deals `val2` percent of itself as `val1`
  element damage. Magnum Break's ten-second fire aura is this shape. The two
  shapes are mutually exclusive on one instance - a percentage never overrides
  the attack element.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_watk_element,
    no_dispel: false,
    properties: [:buff],
    end_on_start: [
      :sc_aspersio,
      :sc_encpoison,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon
    ],
    no_save: true

  alias Aesir.ZoneServer.Mmo.Element

  @impl true
  def modifiers(%{val2: percent} = instance, _context)
      when is_integer(percent) and percent > 0 do
    %{{:pseudo_element_atk, Element.from_id!(instance.val1)} => percent}
  end

  def modifiers(instance, _context) do
    %{attack_element: Element.from_id!(instance.val1)}
  end
end
