defmodule Aesir.ZoneServer.Mmo.PetManagement.PetDefinition do
  @moduledoc """
  One imported `pet_db` row: the species keyed by its mob
  id, its items, hunger and intimacy tuning, support AI rates, the parsed bonus
  program and the support-script ops. Item ids of absent items are 0.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.PetManagement.SupportScript

  @enforce_keys [
    :mob_id,
    :tame_item_id,
    :egg_item_id,
    :equip_item_id,
    :food_item_id,
    :fullness,
    :hungry_delay_ms,
    :hunger_increase,
    :intimacy_start,
    :intimacy_fed,
    :intimacy_overfed,
    :intimacy_hungry,
    :intimacy_owner_die,
    :capture_rate,
    :special_performance,
    :attack_rate,
    :retaliate_rate,
    :change_target_rate,
    :allow_auto_feed,
    :bonus_program,
    :support_ops,
    :evolution
  ]
  defstruct @enforce_keys

  @typedoc "An item requirement of one evolution."
  @type requirement :: %{item_id: pos_integer(), amount: pos_integer()}

  @typedoc "An evolution target with its item requirements, in file order."
  @type evolution :: %{target_mob_id: pos_integer(), requirements: [requirement()]}

  @type t :: %__MODULE__{
          mob_id: pos_integer(),
          tame_item_id: non_neg_integer(),
          egg_item_id: pos_integer(),
          equip_item_id: non_neg_integer(),
          food_item_id: non_neg_integer(),
          fullness: 0..100,
          hungry_delay_ms: non_neg_integer(),
          hunger_increase: integer(),
          intimacy_start: 0..10_000,
          intimacy_fed: integer(),
          intimacy_overfed: integer(),
          intimacy_hungry: integer(),
          intimacy_owner_die: integer(),
          capture_rate: 0..10_000,
          special_performance: boolean(),
          attack_rate: 0..10_001,
          retaliate_rate: 0..10_001,
          change_target_rate: 0..10_001,
          allow_auto_feed: boolean(),
          bonus_program: EquipScript.compiled(),
          support_ops: [SupportScript.support_op()],
          evolution: [evolution()]
        }
end
