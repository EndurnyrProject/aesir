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

  `require_weapon` restricts ordinary player casts to the listed equipped
  right-hand weapon subtypes. An empty list (the default) accepts any weapon.

  `vulture_range` marks a skill whose cast range grows with the caster's
  Vulture's Eye: the interpreter adds that skill's learned level to the
  declared range for a player caster. It is mode-invariant.

  Any mode-keyable option (see `resolve_mode/2`) may be given as
  `[renewal: value, pre_renewal: value]` instead of a plain value, so a skill
  whose renewal and pre-renewal numbers diverge declares both from the same
  `use Skill` call. `<SkillModule>.definition/1` selects the resolved
  `Definition` for a given `Aesir.Commons.GameMode.t()`; `definition/0` resolves
  the booted mode (`Aesir.Commons.GameMode.mode/0`).

  Use `build!/2` to construct a validated definition from `use` options.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.DefinitionValidation
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Requirement

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

  @typedoc """
  Which value feeds the physical base-damage step: the equipped weapon
  (`:weapon`, the default) or the equipped shield (`:shield`, base
  `batk + 4×refine + shield_weight`). A shield-based skill cast by a mob, which
  has no shield, falls back to the plain weapon/batk base.
  """
  @type damage_base :: :weapon | :shield

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

  @enforce_keys [:id, :name, :display_name, :max_level]
  defstruct id: nil,
            name: nil,
            display_name: nil,
            max_level: nil,
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
            hp_cost_rate: [],
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
            damage_base: :weapon,
            item_cost: [],
            # Caster facilities this skill requires (see `Skill.Requirement`). Silence means
            # PLAYER-ONLY: an un-annotated skill defaults to `[:player_state]`, which no mob
            # can provide, so a mob never casts it. Caster-generic skills MUST opt in with an
            # explicit `requires: []` (or a narrower set). This default makes the
            # crash-a-MobSession class structurally impossible.
            requires: [:player_state],
            requires_ammo: false,
            require_weapon: [],
            vulture_range: false,
            status: nil,
            quest_skill: false,
            quest_owner_job: nil

  @type t() :: %__MODULE__{
          id: integer(),
          name: atom(),
          display_name: String.t(),
          max_level: pos_integer(),
          target_type: target_type(),
          damage_type: damage_type(),
          range: range(),
          element: element(),
          knockback: non_neg_integer(),
          hit_count: pos_integer(),
          splash_radius: non_neg_integer(),
          hit_interval: non_neg_integer(),
          unit_duration: [non_neg_integer()],
          hp_cost: [non_neg_integer()],
          hp_cost_rate: [non_neg_integer()],
          sp_cost: [non_neg_integer() | :all],
          sphere_cost: [non_neg_integer() | :all],
          zeny_cost: [non_neg_integer()],
          duration: [non_neg_integer()],
          cast_time: [non_neg_integer()],
          fixed_cast_time: [non_neg_integer()],
          ignore_dex: boolean(),
          after_cast_delay: [non_neg_integer()],
          cooldown: [non_neg_integer()],
          damage_kind: damage_kind(),
          damage_base: damage_base(),
          item_cost: [item_cost_entry()],
          requires: [Requirement.t()],
          requires_ammo: boolean(),
          require_weapon: [atom()],
          vulture_range: boolean(),
          status: atom() | nil,
          quest_skill: boolean(),
          quest_owner_job: atom() | nil
        }

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
    hp_cost_rate: {:list, {:integer, {:gte, 0}}},
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
    damage_base: {:enum, [:weapon, :shield]},
    item_cost: {:list, %{id: {:required, :integer}, amount: {:required, {:integer, {:gt, 0}}}}},
    requires: {:list, {:enum, Requirement.all()}},
    requires_ammo: :boolean,
    require_weapon: {:list, :atom},
    vulture_range: :boolean,
    status: :atom,
    quest_skill: :boolean,
    quest_owner_job: :atom
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
    hp_cost_rate: [],
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
    damage_base: :weapon,
    item_cost: [],
    requires: [:player_state],
    requires_ammo: false,
    require_weapon: [],
    vulture_range: false,
    status: nil,
    quest_skill: false,
    quest_owner_job: nil
  }

  @mode_keyable [
    :target_type,
    :range,
    :element,
    :knockback,
    :hit_count,
    :splash_radius,
    :hit_interval,
    :unit_duration,
    :hp_cost,
    :hp_cost_rate,
    :sp_cost,
    :sphere_cost,
    :zeny_cost,
    :duration,
    :cast_time,
    :fixed_cast_time,
    :after_cast_delay,
    :cooldown,
    :item_cost,
    :require_weapon,
    :requires_ammo,
    :max_level
  ]

  @doc """
  Builds a validated `Definition` from `use`-macro options.

  Validates against the metadata schema and fills defaults; raises
  `ArgumentError` at compile time on unknown keys or invalid values, naming the
  offending module.
  """
  @spec build!(keyword(), module()) :: t()
  def build!(opts, module) do
    metadata = DefinitionValidation.validate!(@metadata_schema, opts, module, @defaults)
    validate_quest_owner!(metadata, module)
    struct!(__MODULE__, metadata)
  end

  @doc """
  Resolves mode-keyed values in `opts` for `mode`.

  A value on a field listed in `@mode_keyable` is mode-keyed only when it is
  a keyword list whose keys are exactly `:renewal` and `:pre_renewal`, in
  either order; such a value resolves to its entry for `mode`. Every other
  value - a plain value, a malformed keyed list, or a keyed value on a field
  that isn't mode-keyable - passes through unchanged, so `build!/2`'s schema
  validation rejects it downstream and names the offending module.
  """
  @spec resolve_mode(keyword(), GameMode.t()) :: keyword()
  def resolve_mode(opts, mode) do
    Enum.map(opts, fn {field, value} -> {field, resolve_value(field, value, mode)} end)
  end

  defp resolve_value(field, value, mode) when field in @mode_keyable do
    if mode_keyed?(value), do: Keyword.fetch!(value, mode), else: value
  end

  defp resolve_value(_field, value, _mode), do: value

  defp mode_keyed?(value) do
    Keyword.keyword?(value) and Enum.sort(Keyword.keys(value)) == [:pre_renewal, :renewal]
  end

  defp validate_quest_owner!(%{quest_skill: true, quest_owner_job: nil}, module) do
    raise ArgumentError, "quest skill in #{inspect(module)} requires quest_owner_job"
  end

  defp validate_quest_owner!(%{quest_owner_job: nil}, _module), do: :ok

  defp validate_quest_owner!(%{quest_owner_job: owner}, module) do
    case AvailableJobs.job_name_to_id(owner) do
      {:ok, _job_id} ->
        :ok

      {:error, :unknown_job} ->
        raise ArgumentError, "unknown quest_owner_job #{inspect(owner)} in #{inspect(module)}"
    end
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
