defmodule Aesir.ZoneServer.Mmo.MobManagement.MobDefinition do
  @moduledoc """
  Static mob data: the core attributes and properties of a mob type.
  """

  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
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

  @enforce_keys [
    :id,
    :aegis_name,
    :name,
    :level,
    :hp,
    :stats,
    :attack_range,
    :size,
    :race,
    :element,
    :walk_speed,
    :attack_delay,
    :attack_motion,
    :client_attack_motion,
    :damage_motion
  ]
  defstruct id: nil,
            aegis_name: nil,
            name: nil,
            level: nil,
            hp: nil,
            sp: 0,
            base_exp: 0,
            job_exp: 0,
            atk: 0,
            matk: 0,
            def: 0,
            mdef: 0,
            stats: nil,
            attack_range: nil,
            skill_range: 10,
            chase_range: 12,
            size: nil,
            race: nil,
            race_groups: [],
            element: nil,
            walk_speed: nil,
            attack_delay: nil,
            attack_motion: nil,
            client_attack_motion: nil,
            damage_motion: nil,
            ai_type: 0,
            modes: [],
            drops: [],
            mvp_exp: 0,
            mvp_drops: []

  @type t() :: %__MODULE__{
          id: integer(),
          aegis_name: String.t(),
          name: String.t(),
          level: integer(),
          hp: integer(),
          sp: integer(),
          base_exp: integer(),
          job_exp: integer(),
          atk: integer(),
          matk: integer(),
          def: integer(),
          mdef: integer(),
          stats: map(),
          attack_range: integer(),
          skill_range: integer(),
          chase_range: integer(),
          size: size(),
          race: race(),
          race_groups: [race2()],
          element: element(),
          walk_speed: integer(),
          attack_delay: integer(),
          attack_motion: integer(),
          client_attack_motion: integer(),
          damage_motion: integer(),
          ai_type: integer(),
          modes: [atom()],
          drops: [MobDrop.t()],
          mvp_exp: integer(),
          mvp_drops: [MobDrop.t()]
        }
end
