defmodule Aesir.ZoneServer.Mmo.MobManagement.MobDefinition do
  @moduledoc """
  Static mob data: the core attributes and properties of a mob type.

  A monster always has at least 1 SP; one without an SP value has exactly 1.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.Race
  alias Aesir.ZoneServer.Mmo.Size

  @typedoc """
  Mob size categories
  """
  @type size :: Size.t()

  @typedoc """
  Mob race types, including the distinct player races used by training dummies.
  """
  @type race :: Race.t()

  @typedoc """
  Secondary mob group classifications
  """
  @type race2 :: atom()

  @typedoc """
  Element types with level
  """
  @type element :: {Element.t(), Element.level()}

  @typedoc "Primary stats keyed by their database names."
  @type stats :: %{optional(:str | :agi | :vit | :int | :dex | :luk) => integer()}

  typedstruct do
    @typedoc "A monster's static definition."
    field :id, integer(), enforce: true
    field :aegis_name, String.t(), enforce: true
    field :name, String.t(), enforce: true
    field :japanese_name, String.t()
    field :level, integer(), enforce: true
    field :hp, integer(), enforce: true
    field :sp, integer(), default: 1
    field :base_exp, integer(), default: 0
    field :job_exp, integer(), default: 0
    field :atk, integer(), default: 0
    field :atk2, integer(), default: 0
    field :matk, integer(), default: 0
    field :def, integer(), default: 0
    field :mdef, integer(), default: 0
    field :class, MobMode.class(), default: :normal
    field :stats, stats(), enforce: true
    field :attack_range, integer(), enforce: true
    field :skill_range, integer(), default: 10
    field :chase_range, integer(), default: 12
    field :size, size(), enforce: true
    field :race, race(), enforce: true
    field :race_groups, [race2()], default: []
    field :element, element(), enforce: true
    field :walk_speed, integer(), enforce: true
    field :attack_delay, integer(), enforce: true
    field :attack_motion, integer(), enforce: true
    field :client_attack_motion, integer(), enforce: true
    field :damage_motion, integer(), enforce: true
    field :ai_type, integer(), default: 0
    field :modes, [atom()], default: []
    field :drops, [MobDrop.t()], default: []
    field :mvp_exp, integer(), default: 0
    field :mvp_drops, [MobDrop.t()], default: []
  end
end
