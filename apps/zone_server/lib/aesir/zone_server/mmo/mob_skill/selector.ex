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
    2. **Castable** - the row's skill must resolve in the real skill catalog
       (`Skill.Catalog.by_id/1` with an active module) and must not be in
       `MobSkill.Denylist`. Non-castable rows are dropped silently; coverage
       is tracked once globally by the importer's manifest and the sweep
       test, not per-tick here (that would spam).
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
      the `slavele` gate (default `SlaveSummon.count_living_slaves/1`). Like
      `:rng`, this is the escape hatch keeping the module testable: the default
      reads the unit registry (read-only, and only when a `slavele` row is
      actually evaluated), tests inject a pure fun.
  """

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.SlaveSummon
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
        Keyword.get(opts, :count_living_slaves, &SlaveSummon.count_living_slaves/1)
    }

    eligible = eligible_states(mob_state)

    rows
    |> Enum.filter(fn row ->
      row_state_eligible?(row, eligible, mob_state) and castable?(row) and
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

  # Player-owned summons have no combat rotation of their own: their imported
  # rows are their entire behavior, so idle rows stay eligible in every state
  # (a damaged Marine Sphere must still wander and self-destruct while engaged).
  @spec row_state_eligible?(row(), [atom()], MobState.t()) :: boolean()
  defp row_state_eligible?(%{state: :idle}, _eligible, %MobState{owner_player_id: owner})
       when not is_nil(owner),
       do: true

  defp row_state_eligible?(row, eligible, _mob_state), do: row.state in eligible

  @spec castable?(row()) :: boolean()
  defp castable?(%{skill_id: skill_id}) do
    with {:ok, definition} <- SkillCatalog.by_id(skill_id),
         {:ok, _module} <- SkillCatalog.active_module_for(definition.name) do
      not Denylist.denied?(skill_id)
    else
      :error -> false
    end
  end

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

  defp evaluate(
         :alchemist,
         _condition,
         %MobState{owner_player_id: owner_player_id, hp: hp, max_hp: max_hp},
         _env
       ) do
    owner_player_id != nil and hp < max_hp
  end

  defp evaluate(:rudeattacked, _condition, %MobState{rude_attacked?: flag}, _env), do: flag

  defp evaluate(:onspawn, _condition, _mob_state, env), do: env.event == :spawn

  defp evaluate(:casttargeted, _condition, %MobState{target_ref: target_ref}, _env) do
    target_ref != nil
  end

  defp evaluate(:slavele, %{value: value}, %MobState{instance_id: instance_id}, env)
       when is_integer(value) do
    env.count_living_slaves.(instance_id) <= value
  end

  defp evaluate(_type, _condition, _mob_state, _env), do: false
end
