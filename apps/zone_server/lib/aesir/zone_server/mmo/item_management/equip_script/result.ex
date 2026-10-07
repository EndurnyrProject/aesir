defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipScript.Result do
  @moduledoc """
  Deterministic result of evaluating an equipment-script program.

  Modifiers retain the existing equipment merge representation, while
  autocasts, autobonuses and effects preserve their own source order.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

  @enforce_keys [:modifiers, :auto_casts, :autobonuses, :effects]
  defstruct modifiers: %{}, auto_casts: [], autobonuses: [], effects: []

  @type t() :: %__MODULE__{
          modifiers: map(),
          auto_casts: [EquipScript.auto_cast()],
          autobonuses: [EquipScript.autobonus()],
          effects: [EquipScript.effect()]
        }
end
