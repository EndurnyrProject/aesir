defmodule Aesir.ZoneServer.Mmo.Skill.Definition do
  @moduledoc """
  Static skill definition (the `skill_db` record).

  Loaded as data from `priv/db/skills/*.yml` into `:persistent_term`; never a
  per-record module. Carries the cross-cutting declarative fields only -
  behavior-specific numbers live in the skill's behavior module.
  """
  use TypedStruct

  @typedoc "How a skill is targeted (rAthena `inf`)."
  @type target_type :: :self | :target_enemy | :target_ally | :ground | :passive

  @typedoc "Whether casting deals damage (rAthena `DamageFlags.NoDamage`)."
  @type damage_type :: :damage | :no_damage

  typedstruct do
    field :id, integer(), enforce: true
    field :name, atom(), enforce: true
    field :display_name, String.t(), enforce: true
    field :max_level, pos_integer(), enforce: true
    field :target_type, target_type(), default: :self
    field :damage_type, damage_type(), default: :no_damage
    field :range, integer(), default: 0
    field :sp_cost, [non_neg_integer()], default: []
    field :duration, [non_neg_integer()], default: []
    field :cast_time, [non_neg_integer()], default: []
    field :after_cast_delay, [non_neg_integer()], default: []
    field :cooldown, [non_neg_integer()], default: []
  end
end
