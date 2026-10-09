defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElement do
  @moduledoc """
  Weapon Element Property (SC_WATK_ELEMENT), classic Magnum Break's ten-second
  fire aura.

  Carries an element in `val1` and a percentage in `val2`. The attack keeps its
  own element; a classic player's physical hit additionally deals `val2`
  percent of its normal-attack damage taken as `val1` element. It is not an
  endow: it neither ends nor is ended by the weapon endows, only by a newer
  aura.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_watk_element,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    end_on_start: [:sc_watk_element],
    no_save: true

  alias Aesir.ZoneServer.Mmo.Element

  @impl true
  def modifiers(%{val2: percent} = instance, _context) when is_integer(percent) do
    %{{:pseudo_element_atk, Element.from_id!(instance.val1)} => percent}
  end

  def modifiers(_instance, _context), do: %{}
end
