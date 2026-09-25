defmodule Aesir.ZoneServer.Mmo.Skill.Performance do
  @moduledoc """
  Capability behaviour for skills that are songs or dances.

  Using this behaviour marks a skill as a performance and supplies its dynamic
  cost through the generic skill cost resolver. A module that uses this behaviour
  must not separately declare `Aesir.ZoneServer.Mmo.Skill.Active`, because
  performance implies the active behaviour.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "Options for a maintained pre-renewal performance field."
  @type field_opt ::
          {:reach, :everyone | :party | :enemy | :mobs}
          | {:upkeep, pos_integer()}
          | {:layout_radius, 3 | 4}
          | {:linger_ms, non_neg_integer()}
          | {:kind, :song | :dance | :ensemble}
          | {:tick, :dissonance | :ugly_dance | :idun_heal | nil}
          | {:tick_interval, pos_integer()}
          | {:partners, [integer()]}
          | {:lesson_level, non_neg_integer()}
          | {:caster_vit, non_neg_integer()}

  @doc """
  Runs the renewal snapshot or starts a pre-renewal ground field.

  Pre-renewal options: `:kind` (`:song`, `:dance` or `:ensemble`) and positive
  `:upkeep` are required. `:reach` defaults to `:everyone`; `:layout_radius`
  defaults to 3 (use 4 for ensembles); `:linger_ms` defaults to 20 seconds;
  `:tick` defaults to nil and `:tick_interval` to 3 seconds. `:partners`
  defaults to `[]`, and the frozen `:lesson_level` and `:caster_vit` to zero.
  Renewal only forwards `:scope`, `:radius`, `:duration` and `:eligible?`.
  """
  @spec perform(
          PlayerState.t(),
          Definition.t(),
          pos_integer(),
          atom() | nil,
          keyword(),
          keyword()
        ) ::
          {:ok, PlayerState.t()} | {:error, term()}
  def perform(caster, definition, level, status_id, status_params, opts) do
    case GameMode.mode() do
      :renewal ->
        Snapshot.snapshot(
          caster,
          definition,
          level,
          status_id,
          status_params,
          Keyword.take(opts, [:scope, :radius, :duration, :eligible?])
        )

      :pre_renewal ->
        Field.start(caster, definition, level, status_id, status_params, opts)
    end
  end

  @doc false
  @callback __performance__() :: true

  defmacro __using__(_opts) do
    quote do
      @behaviour Aesir.ZoneServer.Mmo.Skill.Performance
      @behaviour Aesir.ZoneServer.Mmo.Skill.Active
      @behaviour Aesir.ZoneServer.Mmo.Skill.Ground

      @doc false
      @impl Aesir.ZoneServer.Mmo.Skill.Performance
      def __performance__, do: true

      @impl Aesir.ZoneServer.Mmo.Skill.Active
      def dynamic_cost(caster, _target, level, definition),
        do: unquote(Cost).resolve(caster, definition, level)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_place(group), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_interval(group, now), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate field_support(group), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_expire(group), to: unquote(Field)

      defoverridable on_place: 1, on_interval: 2, field_support: 1, on_expire: 1
    end
  end
end
