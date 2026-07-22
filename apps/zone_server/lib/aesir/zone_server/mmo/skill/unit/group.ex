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
  use TypedStruct

  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Unit

  @typedoc "A single map cell occupied by the skill-unit footprint."
  @type cell :: {non_neg_integer(), non_neg_integer()}

  typedstruct do
    field :group_id, non_neg_integer(), enforce: true
    field :skill_id, non_neg_integer()
    field :skill_name, atom(), enforce: true
    field :level, non_neg_integer()
    field :caster_id, integer()
    field :caster_type, Unit.unit_type()
    field :target_id, integer() | nil
    field :target_type, Unit.unit_type() | nil
    field :map_name, String.t()
    field :center, cell()
    field :origin, cell() | nil, default: nil
    field :cells, [cell()], default: []
    field :created_at, integer() | nil
    field :next_tick_at, integer() | nil
    field :expires_at, integer()
    field :interval, pos_integer()
    field :lifecycle_policy, LifecyclePolicy.t(), default: %LifecyclePolicy{}
    field :visible?, boolean(), default: false
    field :state, map(), default: %{}
    field :handler, module() | nil, default: nil
  end

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
end
