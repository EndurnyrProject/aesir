defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Group do
  @moduledoc """
  Struct representing a single ground skill-unit group.

  A group is created once per ground cast (rAthena `skill_unit_group`). It holds
  the footprint cell-set occupied on the map, indexed creation/tick/expiry
  timestamps, optional target identity, visibility, bounded lifecycle policy,
  and per-skill mutable state (e.g. Storm Gust's accumulated hit counts).

  One row per cast is stored in the `:skill_units` ETS table keyed by `group_id`;
  `Skill.Unit.Storage` keeps its secondary keys synchronized.

  `handler` carries the group's tick/trigger module for casters that bypass
  `Skill.Catalog` (e.g. mob ground skills built without a catalog entry). When
  `nil`, `Skill.Unit.Manager` resolves the handler from `skill_name` via
  `Skill.Catalog.ground_module_for/1`.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Unit

  @typedoc "A single map cell occupied by the skill-unit footprint."
  @type cell :: {non_neg_integer(), non_neg_integer()}

  @typedoc "Extensible skill state; Hunter traps embed typed lifecycle metadata at `:trap`."
  @type skill_state :: %{optional(:trap) => TrapState.t(), optional(term()) => term()}

  @typedoc "Controls whether a group is materialized and which observers receive it."
  @type visibility :: :public | :party_only | :none

  @enforce_keys [:group_id, :skill_name]
  defstruct group_id: nil,
            skill_id: nil,
            skill_name: nil,
            level: nil,
            caster_id: nil,
            caster_type: nil,
            party_id: nil,
            target_id: nil,
            target_type: nil,
            map_name: nil,
            center: nil,
            origin: nil,
            cells: [],
            created_at: nil,
            next_tick_at: nil,
            expires_at: nil,
            interval: nil,
            lifecycle_policy: %LifecyclePolicy{},
            visibility: :public,
            state: %{},
            handler: nil

  @type t() :: %__MODULE__{
          group_id: non_neg_integer(),
          skill_id: non_neg_integer() | nil,
          skill_name: atom(),
          level: non_neg_integer() | nil,
          caster_id: integer() | nil,
          caster_type: Unit.unit_type() | nil,
          party_id: integer() | nil,
          target_id: integer() | nil,
          target_type: Unit.unit_type() | nil,
          map_name: String.t() | nil,
          center: cell() | nil,
          origin: cell() | nil,
          cells: [cell()],
          created_at: integer() | nil,
          next_tick_at: integer() | nil,
          expires_at: integer() | nil,
          interval: pos_integer() | nil,
          lifecycle_policy: LifecyclePolicy.t(),
          visibility: visibility(),
          state: skill_state(),
          handler: module() | nil
        }

  @doc "Whether this group owns real cells and appears in the map index."
  @spec materialized?(t()) :: boolean()
  def materialized?(%__MODULE__{visibility: :public}), do: true
  def materialized?(%__MODULE__{visibility: :party_only}), do: true
  def materialized?(%__MODULE__{visibility: :none}), do: false

  @doc "Whether this group is delivered to every observer in range."
  @spec public?(t()) :: boolean()
  def public?(%__MODULE__{visibility: :public}), do: true
  def public?(%__MODULE__{}), do: false

  @doc "Whether this group is visible to an observer and their current party."
  @spec visible_to?(t(), integer(), integer() | nil) :: boolean()
  def visible_to?(%__MODULE__{visibility: :public}, _observer_id, _observer_party_id), do: true
  def visible_to?(%__MODULE__{visibility: :none}, _observer_id, _observer_party_id), do: false

  def visible_to?(
        %__MODULE__{visibility: :party_only, caster_type: :player, caster_id: caster_id},
        observer_id,
        _observer_party_id
      )
      when observer_id == caster_id,
      do: true

  def visible_to?(
        %__MODULE__{visibility: :party_only, party_id: party_id},
        _observer_id,
        observer_party_id
      )
      when is_integer(party_id) and party_id > 0 and party_id == observer_party_id,
      do: true

  def visible_to?(%__MODULE__{}, _observer_id, _observer_party_id), do: false

  @doc "Whether this group is a Land Protector field (suppresses other ground units)."
  @spec land_protector?(t()) :: boolean()
  def land_protector?(%__MODULE__{state: %{land_protector: true}}), do: true
  def land_protector?(%__MODULE__{}), do: false

  @doc """
  Whether this group is exempt from Land Protector destruction and suppression.

  Set by skills whose group is scheduling bookkeeping rather than a real ground
  unit (Meteor Storm's impact marker), which rAthena never materializes as
  skill units at all.
  """
  @spec ignores_land_protector?(t()) :: boolean()
  def ignores_land_protector?(%__MODULE__{state: %{ignore_land_protector: true}}), do: true
  def ignores_land_protector?(%__MODULE__{}), do: false

  @doc """
  Whether this group's ground unit may damage its own caster (Grand Cross),
  overriding the default targeting exclusion of the caster from its own unit.
  """
  @spec hits_caster?(t()) :: boolean()
  def hits_caster?(%__MODULE__{state: %{hits_caster: true}}), do: true
  def hits_caster?(%__MODULE__{}), do: false
end
