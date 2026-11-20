defmodule Aesir.ZoneServer.Mmo.PetManagement.PetDefinition do
  @moduledoc """
  One imported `pet_db` row: the species keyed by its mob
  id, its items, hunger and intimacy tuning, support AI rates, the parsed bonus
  program and the support-script ops. Item ids of absent items are 0.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.PetManagement.SupportScript

  @typedoc "An item requirement of one evolution."
  @type requirement :: %{item_id: pos_integer(), amount: non_neg_integer()}

  @typedoc "An evolution target with its item requirements, in file order."
  @type evolution :: %{target_mob_id: pos_integer(), requirements: [requirement()]}

  @typedoc "A pet species definition."
  typedstruct enforce: true do
    field :mob_id, pos_integer()
    field :tame_item_id, non_neg_integer()
    field :egg_item_id, pos_integer()
    field :equip_item_id, non_neg_integer()
    field :food_item_id, non_neg_integer()
    field :fullness, 0..100
    field :hungry_delay_ms, non_neg_integer()
    field :hunger_increase, integer()
    field :intimacy_start, 0..10_000
    field :intimacy_fed, integer()
    field :intimacy_overfed, integer()
    field :intimacy_hungry, integer()
    field :intimacy_owner_die, integer()
    field :capture_rate, 0..10_000
    field :special_performance, boolean()
    field :attack_rate, 0..10_001
    field :retaliate_rate, 0..10_001
    field :change_target_rate, 0..10_001
    field :allow_auto_feed, boolean()
    field :bonus_program, EquipScript.compiled()
    field :support_ops, [SupportScript.support_op()]
    field :evolution, [evolution()]
  end
end
