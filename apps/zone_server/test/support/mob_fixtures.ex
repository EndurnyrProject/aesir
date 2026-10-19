defmodule Aesir.TestMob do
  @moduledoc """
  Publishes a base/calculated snapshot for a test-built `%MobState{}`.

  Production builds the snapshot through `MobState.new/6` and
  `configure_summon/2`. Tests that construct a `%MobState{}` literal directly
  call `publish/2` so the calculated readers see the same shape.

  `max_hp`, `max_sp`, `walk_speed` and `stat_bonus` replace the legacy struct
  fields this helper supersedes. `publish/2` rebuilds from the state's current
  definition, so a fixture that mutated `mob_data` observes the rebuilt
  snapshot.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Stats

  @doc """
  A minimal complete `%MobDefinition{}` for fixtures that used a partial
  `mob_data: %{...}` map before the calculated snapshot existed.
  """
  @spec definition(keyword()) :: MobDefinition.t()
  def definition(opts \\ []) do
    %MobDefinition{
      id: Keyword.get(opts, :id, 1002),
      aegis_name: Keyword.get(opts, :aegis_name, "TEST_MOB"),
      name: Keyword.get(opts, :name, "TestMob"),
      level: Keyword.get(opts, :level, 1),
      hp: Keyword.get(opts, :hp, 100),
      sp: Keyword.get(opts, :sp, 0),
      base_exp: 0,
      job_exp: 0,
      atk: Keyword.get(opts, :atk, 10),
      atk2: Keyword.get(opts, :atk2, 10),
      matk: Keyword.get(opts, :matk, 0),
      def: Keyword.get(opts, :def, 0),
      mdef: Keyword.get(opts, :mdef, 0),
      stats: Keyword.get(opts, :stats, %{str: 10, agi: 10, vit: 10, int: 5, dex: 10, luk: 5}),
      attack_range: Keyword.get(opts, :attack_range, 1),
      skill_range: Keyword.get(opts, :skill_range, 10),
      chase_range: Keyword.get(opts, :chase_range, 12),
      element: Keyword.get(opts, :element, {:neutral, 1}),
      race: Keyword.get(opts, :race, :formless),
      size: Keyword.get(opts, :size, :medium),
      walk_speed: Keyword.get(opts, :walk_speed, 200),
      attack_delay: Keyword.get(opts, :attack_delay, 1_000),
      attack_motion: Keyword.get(opts, :attack_motion, 500),
      client_attack_motion: Keyword.get(opts, :client_attack_motion, 500),
      damage_motion: Keyword.get(opts, :damage_motion, 400),
      ai_type: 0,
      class: Keyword.get(opts, :class, MobMode.class(Keyword.get(opts, :modes, []))),
      modes: Keyword.get(opts, :modes, []),
      drops: Keyword.get(opts, :drops, []),
      mvp_exp: 0,
      mvp_drops: []
    }
  end

  @doc """
  Rebuilds `base`/`calculated` from the state's form definition.

  `max_hp`, `max_sp` and `walk_speed` override the derived snapshot defaults.
  A non-empty `stat_bonus` folds its spawn adjustment into the base the same
  way `configure_summon/2` does. A state without a complete `%MobDefinition{}`
  is returned unchanged (its readers are not exercised).
  """
  @spec publish(MobState.t(), keyword()) :: MobState.t()
  def publish(state, opts \\ [])

  def publish(%MobState{mob_data: %MobDefinition{}} = state, opts) do
    # `Stats.prepare_base/2` rebuilds from the definition (never from an
    # existing `state.base`), so a fixture that mutated `mob_data` is refreshed.
    base = Stats.prepare_base(state, Keyword.take(opts, [:stat_bonus]))

    base = %{
      base
      | max_hp: Keyword.get(opts, :max_hp, base.max_hp),
        max_sp: Keyword.get(opts, :max_sp, base.max_sp),
        speed: Keyword.get(opts, :walk_speed, base.speed)
    }

    %{state | base: base, calculated: base}
  end

  # A fixture with no complete definition cannot publish a snapshot; leave it
  # for the reader it actually exercises.
  def publish(%MobState{} = state, _opts), do: state
end
