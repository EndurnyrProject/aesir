defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipScript.Result do
  @moduledoc """
  Deterministic result of evaluating an equipment-script program.

  Modifiers retain the existing equipment merge representation, while
  autocasts, autobonuses, pet autobonuses, on-hit status bonuses (`EquipAddEff`) and effects
  preserve their own source order.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.Combat.EquipAddEff
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

  @typedoc "The evaluated modifiers, procs and effects of one equipment script."
  typedstruct enforce: true do
    field :modifiers, map()
    field :auto_casts, [EquipScript.auto_cast()]
    field :autobonuses, [EquipScript.autobonus()]
    field :pet_autobonuses, [EquipScript.pet_autobonus()], default: []
    field :add_effs, [EquipAddEff.bonus()], default: []
    field :effects, [EquipScript.effect()]
  end
end
