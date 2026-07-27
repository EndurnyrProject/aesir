defmodule Aesir.ZoneServer.Mmo.MobManagement.MobDrop do
  @moduledoc """
  A single item that can be dropped by a mob.
  """

  @enforce_keys [:item, :rate]
  defstruct item: nil, rate: nil, steal_protected: false, random_option_group: nil

  @type t() :: %__MODULE__{
          item: String.t(),
          rate: integer(),
          steal_protected: boolean(),
          random_option_group: String.t() | nil
        }
end
