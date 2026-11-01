defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ElementalChange do
  @moduledoc """
  Elemental Change (SC_ELEMENTALCHANGE).

  Overrides only the carrier's defense element, never its weapon element, in
  both game modes. Converter skills and consumable armor scrolls share it.

  `val1` holds the element level and `val2` the element id. A level-one skill
  application (`val3 == 0`) rolls a level from 1 through 4; a script's nonzero
  `val3` keeps its fixed level. A zero element rolls an element from 0 through 9.
  The initialization marker is then cleared. Levels above four are capped.
  Saved applications retain their initialized values on restore.

  Death ends it unless its element is Holy or Dark.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_elementalchange,
    remove_on_death: false,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:def_ele],
    icon: :armor_property

  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  def on_apply(_target, instance, %{loaded: true}), do: {:ok, instance}

  def on_apply(_target, instance, _context) do
    element = if instance.val2 == 0, do: :rand.uniform(10) - 1, else: instance.val2

    level =
      if instance.val1 == 1 and instance.val3 == 0,
        do: :rand.uniform(4),
        else: min(instance.val1, 4)

    {:ok, %{instance | val1: level, val2: element, val3: 0}}
  end

  @impl true
  def modifiers(instance, _context) do
    element = Element.from_id!(instance.val2)
    %{element_override: {element, instance.val1}}
  end

  @doc "Death ends it unless its element is Holy or Dark."
  @impl true
  @spec ends_on_death?(StatusEntry.t()) :: boolean()
  def ends_on_death?(instance), do: Element.from_id!(instance.val2) not in [:holy, :shadow]
end
