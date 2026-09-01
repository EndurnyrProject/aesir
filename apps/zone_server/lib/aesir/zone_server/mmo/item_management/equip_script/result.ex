defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipScript.Result do
  @moduledoc """
  Deterministic result of evaluating an equipment-script program.

  Modifiers retain the existing equipment merge representation, while
  autobonuses and effects preserve their own source order.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

  @enforce_keys [:modifiers, :autobonuses, :effects]
  defstruct modifiers: %{}, autobonuses: [], effects: []

  @type t() :: %__MODULE__{
          modifiers: map(),
          autobonuses: [EquipScript.autobonus()],
          effects: [EquipScript.effect()]
        }
end
