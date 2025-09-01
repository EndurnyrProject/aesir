defmodule Aesir.ZoneServer.Mmo.MobManagement.MobDefinition do
  @moduledoc """
  TypedStruct for mob static data definitions.
  Represents the core attributes and properties of a mob type.
  """
  use TypedStruct

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop

  @typedoc """
  Mob size categories
  """
  @type size :: :small | :medium | :large

  @typedoc """
  Mob race types
  """
  @type race ::
          :formless
          | :undead
          | :brute
          | :plant
          | :insect
          | :fish
          | :demon
          | :demihuman
          | :angel
          | :dragon

  @typedoc """
  Element types with level
  """
  @type element :: {atom(), integer()}

  typedstruct do
    field :id, integer(), enforce: true
    field :aegis_name, atom(), enforce: true
    field :name, String.t(), enforce: true
    field :level, integer(), enforce: true
    field :hp, integer(), enforce: true
    field :sp, integer(), default: 0
    field :base_exp, integer(), default: 0
    field :job_exp, integer(), default: 0
    field :atk_min, integer(), enforce: true
    field :atk_max, integer(), enforce: true
    field :def, integer(), default: 0
    field :mdef, integer(), default: 0
    field :stats, map(), enforce: true
    field :attack_range, integer(), enforce: true
    field :skill_range, integer(), default: 10
    field :chase_range, integer(), default: 12
    field :size, size(), enforce: true
    field :race, race(), enforce: true
    field :element, element(), enforce: true
    field :walk_speed, integer(), enforce: true
    field :attack_delay, integer(), enforce: true
    field :attack_motion, integer(), enforce: true
    field :client_attack_motion, integer(), enforce: true
    field :damage_motion, integer(), enforce: true
    field :ai_type, integer(), default: 0
    field :modes, [atom()], default: []
    field :drops, [MobDrop.t()], default: []
  end
end
