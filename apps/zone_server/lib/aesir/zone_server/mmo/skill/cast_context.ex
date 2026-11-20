defmodule Aesir.ZoneServer.Mmo.Skill.CastContext do
  @moduledoc """
  Per-phase cast data used internally by the skill interpreter.

  Contexts are rebuilt at cast completion so adapter-derived values reflect the
  current caster state. Skill modules continue to receive the existing `cast/4`
  arguments rather than this struct.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Lifecycle
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  typedstruct do
    field :caster, Lifecycle.state(), enforce: true
    field :kind, Caster.kind(), enforce: true
    field :adapter, module(), enforce: true
    field :id, integer(), enforce: true
    field :position, {String.t(), integer(), integer()}, enforce: true
    field :definition, Definition.t(), enforce: true
    field :module, module(), enforce: true
    field :level, pos_integer(), enforce: true
    field :target, Active.target(), enforce: true
    field :phase, Lifecycle.phase(), enforce: true
    field :cost, Lifecycle.prepared() | nil, default: nil
    field :stats, Lifecycle.cast_stats(), enforce: true
  end

  @doc """
  Builds a context from the caster's current state for one cast phase.

  Resource cost preparation happens later in the validation pipeline, so
  `cost` is initially `nil`.
  """
  @spec build(
          Lifecycle.state(),
          Definition.t(),
          pos_integer(),
          Active.target(),
          Lifecycle.phase()
        ) ::
          t()
  def build(caster, definition, level, target, phase) do
    adapter = Caster.for(caster)
    {:ok, module} = Catalog.active_module_for(definition.name)

    %__MODULE__{
      caster: caster,
      kind: adapter.kind(),
      adapter: adapter,
      id: adapter.id(caster),
      position: adapter.position(caster),
      definition: definition,
      module: module,
      level: level,
      target: target,
      phase: phase,
      # Dynamic dispatch keeps the caster extension point open (a new kind is one
      # adapter, no edit here). The context is only ever built for owned-unit
      # (Player/Homunculus) casters that implement `Caster.Lifecycle`; a direct call
      # would warn because `Caster.for/1`'s type includes `Caster.Mob`, which has no
      # `cast_stats/2`.
      stats: :erlang.apply(adapter, :cast_stats, [caster, definition.id])
    }
  end
end
