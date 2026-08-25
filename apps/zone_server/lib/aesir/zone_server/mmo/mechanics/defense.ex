defmodule Aesir.ZoneServer.Mmo.Mechanics.Defense do
  @moduledoc """
  Contract for mode-specific physical and magic defense mitigation.
  """

  @typedoc "Inputs to the normal physical defense mitigation leaf."
  @type physical_context :: %{
          hard_def: integer(),
          soft_def: integer(),
          attacker_level: non_neg_integer() | nil,
          ignore_soft_def?: boolean()
        }

  @typedoc "Inputs to the magic defense mitigation leaf."
  @type magic_context :: %{
          hard_mdef: integer(),
          soft_mdef: integer()
        }

  @callback apply_def(number(), physical_context()) :: number()
  @callback apply_mdef(number(), magic_context()) :: number()
end
