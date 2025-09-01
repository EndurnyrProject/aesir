defmodule Aesir.ZoneServer.Mmo.MobManagement.MobDrop do
  @moduledoc """
  TypedStruct for mob drop items.
  Represents a single item that can be dropped by a mob.
  """
  use TypedStruct

  typedstruct do
    field :item, String.t(), enforce: true
    field :rate, integer(), enforce: true
    field :steal_protected, boolean(), default: false
    field :random_option_group, String.t()
  end

  @doc """
  Converts a raw map from the configuration file to a MobDrop struct.
  """
  @spec from_map(map()) :: t()
  def from_map(drop_map) when is_map(drop_map) do
    %__MODULE__{
      item: Map.fetch!(drop_map, :item),
      rate: Map.fetch!(drop_map, :rate),
      steal_protected: Map.get(drop_map, :steal_protected, false),
      random_option_group: Map.get(drop_map, :random_option_group)
    }
  end
end
