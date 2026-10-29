defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElement do
  @moduledoc """
  Weapon Element Property (SC_WATK_ELEMENT), classic Magnum Break's and Enchant
  Deadly Poison's aura.

  Carries an element in `val1` and a percentage in `val2`. The attack keeps its
  own element. In classic, a player's physical hit additionally deals `val2`
  percent of its normal-attack damage taken as `val1` element. In renewal no
  skill starts it (Magnum Break and Enchant Deadly Poison use the secondary
  weapon property instead), but a script can: there it raises each hand's weapon
  ATK by `val2` percent after the cards, on every physical hit but Meteor
  Assault, with no elemental part. It is not an endow: it neither ends nor is
  ended by the weapon endows, only by a newer aura.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_watk_element,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    end_on_start: [:sc_watk_element],
    no_save: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Element

  @impl true
  def modifiers(%{val2: percent} = instance, _context) when is_integer(percent) do
    case GameMode.mode() do
      :renewal -> %{watk_element_rate: percent}
      :pre_renewal -> %{{:pseudo_element_atk, Element.from_id!(instance.val1)} => percent}
    end
  end

  def modifiers(_instance, _context), do: %{}
end
