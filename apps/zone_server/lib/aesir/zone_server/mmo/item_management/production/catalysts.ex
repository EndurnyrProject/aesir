defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.Catalysts do
  @moduledoc """
  Resolves the optional catalyst items selected for a forge.
  """

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers

  @star_crumb 1000
  @elemental_stones %{994 => :fire, 995 => :water, 996 => :wind, 997 => :earth}

  @typedoc "The selected crumb count, weapon element, and consumed item ids."
  @type resolution :: {0..3, ElementModifiers.element() | nil, [integer()]}

  @doc """
  Resolves the first three selected item ids into forge catalysts.
  """
  @spec resolve([integer()]) :: resolution()
  def resolve(item_ids) when is_list(item_ids) do
    {crumb_count, element, consumed_ids} =
      Enum.reduce(Enum.take(item_ids, 3), {0, nil, []}, fn item_id,
                                                           {crumb_count, element, consumed_ids} ->
        cond do
          item_id == @star_crumb ->
            {crumb_count + 1, element, [item_id | consumed_ids]}

          is_nil(element) and is_map_key(@elemental_stones, item_id) ->
            {crumb_count, Map.fetch!(@elemental_stones, item_id), [item_id | consumed_ids]}

          true ->
            {crumb_count, element, consumed_ids}
        end
      end)

    {crumb_count, element, Enum.reverse(consumed_ids)}
  end
end
