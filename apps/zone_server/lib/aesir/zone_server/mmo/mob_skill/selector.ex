defmodule Aesir.ZoneServer.Mmo.MobSkill.Selector do
  @moduledoc """
  Pure skill picker for a mob's AI tick.

  Given a mob's `MobState`, the skill rows applicable to its class (from
  `MobSkill.Db.rows_for/1`), and per-tick options, returns `{:cast, row}` for the
  first row that clears every gate, or `nil`. It reads state but never mutates
  it; the `MobSession` cast phase (Task P2-6) acts on the result.

  Gates are applied in order:

    1. **State** - the row's `state` must be eligible for the mob's current
       `ai_state` (see `eligible_states/1`, an approximation of rAthena states).
    2. **Stub** - rows whose skill has no archetype (`Catalog.archetype_for/1`
       returns `:stub`) are dropped silently. Stub coverage is tracked once
       globally by the importer's manifest; per-tick logging here would spam.
    3. **Condition** - the row's `condition` predicate must hold.
    4. **Delay** - the row's skill must be off cooldown (`MobState.skill_ready?/3`).
    5. **Rate** - each surviving row rolls `rng.(10_000) <= row.rate` in order;
       the first success wins.

  `opts`:

    * `:now` - millisecond timestamp for the delay gate (default: current system
      time). The cast site passes the same clock it writes cooldowns with.
    * `:rng` - a 1-arg fun `(pos_integer -> pos_integer)` for the rate roll
      (default `&:rand.uniform/1`); injected so tests are deterministic.
    * `:event` - the AI event driving this selection (default `:tick`); set to
      `:spawn` on the spawn tick so `onspawn` rows can fire.
    * `:count_living_slaves` - a 1-arg fun `(master instance id -> count)` for
      the `slavele` gate (default `SummonSlave.count_living_slaves/1`). Like
      `:rng`, this is the escape hatch keeping the module testable: the default
      reads the unit registry (read-only, and only when a `slavele` row is
      actually evaluated), tests inject a pure fun.
  """

  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.SummonSlave
  alias Aesir.ZoneServer.Mmo.MobSkill.Catalog
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @typedoc "A mob skill row as produced by `MobSkill.Db`."
  @type row :: map()

  @spec select(MobState.t(), [row()], keyword()) :: {:cast, row()} | nil
  def select(%MobState{} = mob_state, rows, opts \\ []) when is_list(rows) do
    now = Keyword.get(opts, :now, System.system_time(:millisecond))
    rng = Keyword.get(opts, :rng, &:rand.uniform/1)

    env = %{
      event: Keyword.get(opts, :event, :tick),
      count_living_slaves:
        Keyword.get(opts, :count_living_slaves, &SummonSlave.count_living_slaves/1)
    }

    eligible = eligible_states(mob_state)

    rows
    |> Enum.filter(&(&1.state in eligible))
    |> Enum.reject(&stub?/1)
    |> Enum.filter(fn row ->
      condition_holds?(row, mob_state, env) and
        MobState.skill_ready?(mob_state, row.skill_id, now)
    end)
    |> Enum.find_value(fn row -> if rng.(10_000) <= row.rate, do: {:cast, row} end)
  end

  # Approximation of rAthena mob-skill states (`idle/walk/attack/chase/angry/
  # follow/loot/dead/any/anytarget`) mapped onto our 5-state FSM
  # (`:idle/:alert/:combat/:chase/:return`). rAthena `:any` = any state except
  # dead; `:anytarget` = attack+angry+chase+follow. `:walk`/`:loot`/`:follow`/
  # `:dead` rows only ever match via `:any`/`:anytarget`, which is fine - we never
  # actively drive those states here.
  @spec eligible_states(MobState.t()) :: [atom()]
  defp eligible_states(%MobState{ai_state: :idle}), do: [:idle, :any]
  defp eligible_states(%MobState{ai_state: :alert}), do: [:idle, :any]

  defp eligible_states(%MobState{ai_state: :chase, initiated_by_self?: true}),
    do: [:chase, :anytarget, :any, :angry]

  defp eligible_states(%MobState{ai_state: :chase}), do: [:chase, :anytarget, :any]

  defp eligible_states(%MobState{ai_state: :combat, initiated_by_self?: true}),
    do: [:angry, :anytarget, :any]

  defp eligible_states(%MobState{ai_state: :combat}), do: [:attack, :anytarget, :any]

  defp eligible_states(%MobState{ai_state: :return}), do: [:any]

  @spec stub?(row()) :: boolean()
  defp stub?(%{skill: skill}), do: Catalog.archetype_for(skill) == :stub

  @spec condition_holds?(row(), MobState.t(), map()) :: boolean()
  defp condition_holds?(%{condition: condition}, mob_state, env) do
    evaluate(condition.type, condition, mob_state, env)
  end

  @spec evaluate(atom(), map(), MobState.t(), map()) :: boolean()
  defp evaluate(:always, _condition, _mob_state, _env), do: true

  defp evaluate(:myhpltmaxrate, %{value: value}, %MobState{hp: hp, max_hp: max_hp}, _env)
       when is_integer(value) and max_hp > 0 do
    hp / max_hp * 100 <= value
  end

  defp evaluate(:rudeattacked, _condition, %MobState{rude_attacked?: flag}, _env), do: flag

  defp evaluate(:onspawn, _condition, _mob_state, env), do: env.event == :spawn

  defp evaluate(:casttargeted, _condition, %MobState{target_id: target_id}, _env) do
    target_id != nil
  end

  defp evaluate(:slavele, %{value: value}, %MobState{instance_id: instance_id}, env)
       when is_integer(value) do
    env.count_living_slaves.(instance_id) <= value
  end

  defp evaluate(_type, _condition, _mob_state, _env), do: false
end
