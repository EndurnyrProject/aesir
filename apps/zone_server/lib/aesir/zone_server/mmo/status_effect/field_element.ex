defmodule Aesir.ZoneServer.Mmo.StatusEffect.FieldElement do
  @moduledoc """
  Shared rules for the Sage element fields.

  Volcano, Deluge and Violent Gale each raise their own element's attack by the
  same 10, 14, 17, 19, or 20 points per level: added to the element table's ratio
  in renewal and multiplied into the damage in pre-renewal (the elements family
  applies the mode). Their stat bonuses reach every occupant in renewal but only
  holders of the matching defence element in pre-renewal.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @enchant_eff {10, 14, 17, 19, 20}

  @doc """
  Whether the field's stat bonus reaches this holder. Renewal grants it to every
  occupant; pre-renewal only to a holder whose defence element matches the field.
  """
  @spec stat_bonus?(map(), atom()) :: boolean()
  def stat_bonus?(context, element) do
    GameMode.mode() == :renewal or holder_element(context) == element
  end

  defp holder_element(%{unit_type: unit_type, target_id: unit_id}) do
    case UnitRegistry.get_unit_info(unit_type, unit_id) do
      {:ok, %{element: element}} -> element
      _missing -> :neutral
    end
  end

  defp holder_element(_context), do: :neutral

  @doc """
  Returns the element-ratio bonus, in percentage points, for a field skill level.

  Levels outside 1..5 wrap around the five-entry table.
  """
  @spec enchant_bonus(integer()) :: pos_integer()
  def enchant_bonus(level) when is_integer(level) do
    elem(@enchant_eff, max(rem(level - 1, 5), 0))
  end
end
