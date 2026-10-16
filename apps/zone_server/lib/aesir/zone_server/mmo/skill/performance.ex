defmodule Aesir.ZoneServer.Mmo.Skill.Performance do
  @moduledoc """
  Capability behaviour for skills that are songs or dances.

  Using this behaviour marks a skill as a performance; its SP cost, Adaptation
  included, resolves through the generic skill cost recipe like any song. A
  module that uses this behaviour must not separately declare
  `Aesir.ZoneServer.Mmo.Skill.Active`, because performance implies the active
  behaviour.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "Options for a maintained performance field in either mode."
  @type field_opt ::
          {:reach, :everyone | :all | :party | :party_or_guild | :enemy}
          | {:upkeep, pos_integer()}
          | {:upkeep_sp, pos_integer()}
          | {:root, :none | :ensemble | :always}
          | {:layout_radius, 3 | 4}
          | {:linger_ms, non_neg_integer()}
          | {:kind, :song | :dance | :ensemble}
          | {:tick, :dissonance | :ugly_dance | :idun_heal | :lullaby | nil}
          | {:tick_interval, pos_integer()}
          | {:no_overlap, boolean()}
          | {:ignore_land_protector, boolean()}
          | {:partners, [integer()]}
          | {:lesson_level, non_neg_integer()}
          | {:caster_vit, non_neg_integer()}

  @doc """
  Runs the renewal snapshot or starts a pre-renewal ground field.

  Pre-renewal options: `:kind` (`:song`, `:dance` or `:ensemble`), positive
  `:upkeep` and `:linger_ms` (the time a recipient keeps a solo song or dance
  after leaving it, zero when it never lingers) are required. `:reach`
  defaults to `:everyone`; `:layout_radius` defaults to 3 (use 4 for ensembles);
  `:tick` defaults to nil and `:tick_interval` (the Unit interval of the
  field's own effect) to 3 seconds; `:no_overlap` (default false) shares that
  interval across every field of the skill; `:ignore_land_protector` defaults to
  true for songs and dances and false for ensembles. `:partners`
  defaults to `[]`, and the frozen `:lesson_level` and `:caster_vit` to zero.
  `:upkeep_sp` defaults to one; `:root` defaults to `:ensemble` for ensembles,
  else `:none`. Use `:always` for an unrelaxable root. `:party_or_guild` reach
  includes same-party, same-guild and allied-guild players.
  Renewal only forwards `:scope`, `:radius`, `:duration` and `:eligible?`.

  A monster may start a pre-renewal song or dance field; renewal performances
  are players' only.
  """
  @spec perform(
          PlayerState.t() | MobState.t(),
          Definition.t(),
          pos_integer(),
          atom() | nil,
          keyword(),
          keyword()
        ) ::
          {:ok, PlayerState.t() | MobState.t()} | {:error, term()}
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

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_place(group), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_interval(group, now), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate field_support(group), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_expire(group), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate cell_profile(group, cell), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate unit_targets(group, cell, refs), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_unit_hit(group, cell, target, now), to: unquote(Field)

      defoverridable on_place: 1, on_interval: 2, field_support: 1, on_expire: 1
    end
  end
end
