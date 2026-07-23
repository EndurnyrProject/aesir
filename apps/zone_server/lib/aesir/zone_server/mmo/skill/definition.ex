defmodule Aesir.ZoneServer.Mmo.Skill.Definition do
  @moduledoc """
  Static skill definition (the `skill_db` record).

  Declared inline by each skill module through the single `use Skill` macro and
  validated with Peri at compile time - never loaded from external data. Carries
  every value a skill needs: the cross-cutting fields the interpreter reads
  uniformly (targeting, costs, timing) plus the combat columns mirroring
  rAthena's `skill_db` (`element`, `knockback`, `hit_count`, `splash_radius`,
  `hit_interval`, `unit_duration`) and the optional `status` SC the skill grants
  its caster (mirroring rAthena's skill_db `Status:` / `skill_get_sc`), read by the
  job-change/reset cleanup to end a dropped skill's lingering self-buff. A skill's
  behaviour callbacks read these from `definition/0` instead of hardcoding module
  constants.

  Use `build!/2` to construct a validated definition from `use` options.
  """
  use TypedStruct

  alias Aesir.ZoneServer.Mmo.DefinitionValidation

  @typedoc "How a skill is targeted (rAthena `inf`)."
  @type target_type ::
          :self
          | :target_enemy
          | :target_ally
          | :target_any
          | :target_corpse
          | :target_resurrection
          | :ground
          | :passive

  @typedoc "Whether casting deals damage (rAthena `DamageFlags.NoDamage`)."
  @type damage_type :: :damage | :no_damage

  @typedoc "Which damage calculator a skill dispatches to (rAthena skill type)."
  @type damage_kind :: :weapon | :magic | :misc

  @typedoc "Attack element atom (rAthena `Element`)."
  @type element :: atom()

  @typedoc "A catalyst item consumed on cast (rAthena `RequiredItems`)."
  @type item_cost_entry :: %{id: integer(), amount: pos_integer()}

  @typedoc """
  A skill's cast range: a flat cell count, or a per-level list (index 0 is
  level 1) for a skill whose reach grows with level. Read through
  `range_at_level/2` rather than off the struct directly, so both shapes
  resolve the same way.
  """
  @type range :: integer() | [integer()]

  typedstruct do
    field :id, integer(), enforce: true
    field :name, atom(), enforce: true
    field :display_name, String.t(), enforce: true
    field :max_level, pos_integer(), enforce: true
    field :target_type, target_type(), default: :self
    field :damage_type, damage_type(), default: :no_damage
    field :range, range(), default: 0
    field :element, element(), default: :neutral
    field :knockback, non_neg_integer(), default: 0
    field :hit_count, pos_integer(), default: 1
    field :splash_radius, non_neg_integer(), default: 0
    field :hit_interval, non_neg_integer(), default: 0
    field :unit_duration, [non_neg_integer()], default: []
    field :hp_cost, [non_neg_integer()], default: []
    field :sp_cost, [non_neg_integer() | :all], default: []
    field :sphere_cost, [non_neg_integer() | :all], default: []
    field :zeny_cost, [non_neg_integer()], default: []
    field :duration, [non_neg_integer()], default: []
    field :cast_time, [non_neg_integer()], default: []
    field :fixed_cast_time, [non_neg_integer()], default: []
    field :ignore_dex, boolean(), default: false
    field :after_cast_delay, [non_neg_integer()], default: []
    field :cooldown, [non_neg_integer()], default: []
    field :damage_kind, damage_kind(), default: :weapon
    field :item_cost, [item_cost_entry()], default: []
    field :requires_ammo, boolean(), default: false
    field :status, atom() | nil, default: nil
  end

  @metadata_schema %{
    id: {:required, :integer},
    name: {:required, :atom},
    display_name: {:required, :string},
    max_level: {:required, {:integer, {:gt, 0}}},
    target_type: {
      :enum,
      [
        :self,
        :target_enemy,
        :target_ally,
        :target_any,
        :target_corpse,
        :target_resurrection,
        :ground,
        :passive
      ]
    },
    damage_type: {:enum, [:damage, :no_damage]},
    range: {:oneof, [:integer, {:list, :integer}]},
    element: :atom,
    knockback: :integer,
    hit_count: {:integer, {:gt, 0}},
    splash_radius: :integer,
    hit_interval: :integer,
    unit_duration: {:list, :integer},
    hp_cost: {:list, {:integer, {:gte, 0}}},
    sp_cost: {:list, {:oneof, [{:integer, {:gte, 0}}, {:literal, :all}]}},
    sphere_cost: {:list, {:oneof, [{:integer, {:gte, 0}}, {:literal, :all}]}},
    zeny_cost: {:list, :integer},
    duration: {:list, :integer},
    cast_time: {:list, :integer},
    fixed_cast_time: {:list, :integer},
    ignore_dex: :boolean,
    after_cast_delay: {:list, :integer},
    cooldown: {:list, :integer},
    damage_kind: {:enum, [:weapon, :magic, :misc]},
    item_cost: {:list, %{id: {:required, :integer}, amount: {:required, {:integer, {:gt, 0}}}}},
    requires_ammo: :boolean,
    status: :atom
  }

  @defaults %{
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    element: :neutral,
    knockback: 0,
    hit_count: 1,
    splash_radius: 0,
    hit_interval: 0,
    unit_duration: [],
    hp_cost: [],
    sp_cost: [],
    sphere_cost: [],
    zeny_cost: [],
    duration: [],
    cast_time: [],
    fixed_cast_time: [],
    ignore_dex: false,
    after_cast_delay: [],
    cooldown: [],
    damage_kind: :weapon,
    item_cost: [],
    requires_ammo: false,
    status: nil
  }

  @doc """
  Builds a validated `Definition` from `use`-macro options.

  Validates against the metadata schema and fills defaults; raises
  `ArgumentError` at compile time on unknown keys or invalid values, naming the
  offending module.
  """
  @spec build!(keyword(), module()) :: t()
  def build!(opts, module) do
    @metadata_schema
    |> DefinitionValidation.validate!(opts, module, @defaults)
    |> then(&struct!(__MODULE__, &1))
  end

  @doc """
  Resolves a skill's declared range to a plain cell count for `level`.

  A flat `range` (the common case, including the `-1` "use the weapon's
  range" sentinel) is returned unchanged regardless of level. A per-level
  list is indexed at `level - 1`; an unlearned preview (`level` `0`) reads
  the first level's entry rather than wrapping to the list's last element.
  """
  @spec range_at_level(t(), non_neg_integer()) :: integer()
  def range_at_level(%__MODULE__{range: range}, _level) when is_integer(range), do: range

  def range_at_level(%__MODULE__{range: range}, level) when is_list(range) do
    Enum.at(range, max(level - 1, 0), List.last(range))
  end
end
