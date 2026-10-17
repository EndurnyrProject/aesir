defmodule Aesir.ZoneServer.Mmo.MobSkill.Selector do
  @moduledoc """
  Pure skill picker for a mob's AI tick.

  Given a mob's `MobState`, the skill rows applicable to its class (from
  `MobSkill.Db.rows_for/1`), and per-tick options, returns `{:cast, row}` for the
  first row that clears every gate, or `nil`. It reads state but never mutates
  it; the `MobSession` cast phase (Task P2-6) acts on the result.

  Gates are applied in order:

    1. **State** - the row's `state` must match the mob's skill state
       (`state_matches?/2`): `any` matches every state but dead, `anytarget`
       every state but dead and loot while the mob has a target.
    2. **Castable** - the row's skill must resolve in the real skill catalog
       (`Skill.Catalog.by_id/1` with an active module) and satisfy its declared
       requirements for a mob caster. Non-castable rows are dropped silently;
       coverage is tracked once globally by the importer's manifest and the
       sweep test, not per-tick here (that would spam).
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
      `:spawn` for the spawn event use, where only `onspawn` rows fire, and to
      `:rudeattacked` for the rude-attacked event use, where only `rudeattacked`
      rows fire. On a `:tick`, a `rudeattacked` row needs a rude-attack count of
      at least 1; the caller resets the count when such a row is picked.
    * `:count_living_slaves` - a 1-arg fun `(master instance id -> count)` for
      the `slavele` gate (default `SlaveSummon.count_living_slaves/1`). Like
      `:rng`, this is the escape hatch keeping the module testable: the default
      reads the unit registry (read-only, and only when a `slavele` row is
      actually evaluated), tests inject a pure fun.
    * `:hp_rate_friend` - a 3-arg fun `(mob, min_rate, max_rate -> ref | nil)`
      for the `friendhpltmaxrate` (`0..value`) and `friendhpinrate`
      (`value..val1`) gates (default `MobSkill.Executor.hp_rate_friend/3`, which
      the `friend` target resolves with too); injected like
      `:count_living_slaves`.
    * `:status_friend` - a 3-arg fun `(mob, on?, status -> ref | nil)` for the
      `friendstatuson`/`friendstatusoff` gates (default
      `MobSkill.Executor.status_friend/3`).
    * `:mob_statuses` - a 1-arg fun `(mob -> [status atoms])` for the
      `mystatuson`/`mystatusoff` gates (default reads `StatusStorage`).
    * `:targeted_count` - a 1-arg fun `(ref -> count)` of the units with an
      attack order on `ref`, for `attackpcgt`/`attackpcge`/`masterattacked`
      (default `MobSkill.Executor.count_targeting/1`).
    * `:living_unit` - a 1-arg fun `(ref -> boolean)` for the master checks
      (default reads the unit registry).
    * `:nearby_mobs` - a 1-arg fun `(mob -> count)` of the monsters within the
      visual area, the mob included, for `mobnearbygt` (default
      `MobSkill.Executor.count_nearby_mobs/1`).

  Event conditions (`casttargeted`, `skillused`, `closedattacked`,
  `longrangeattacked`, `groundattacked`, `damagedgt`) fire only from their
  events, never from a periodic check. `trickcasting` holds while the mob
  keeps a trick cast (`MobState.trickcasting`); `alchemist` needs a
  player-owned, hurt mob without one.
  """

  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.SlaveSummon
  alias Aesir.ZoneServer.Mmo.StatusStorage
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
        Keyword.get(opts, :count_living_slaves, &SlaveSummon.count_living_slaves/1),
      hp_rate_friend: Keyword.get(opts, :hp_rate_friend, &Executor.hp_rate_friend/3),
      status_friend: Keyword.get(opts, :status_friend, &Executor.status_friend/3),
      mob_statuses: Keyword.get(opts, :mob_statuses, &mob_statuses/1),
      targeted_count: Keyword.get(opts, :targeted_count, &Executor.count_targeting/1),
      living_unit: Keyword.get(opts, :living_unit, &Executor.living_unit?/1),
      nearby_mobs: Keyword.get(opts, :nearby_mobs, &Executor.count_nearby_mobs/1)
    }

    rows
    |> Enum.filter(fn row ->
      row_state_eligible?(row, mob_state) and castable?(row) and
        condition_holds?(row, mob_state, env) and
        MobState.skill_ready?(mob_state, row.skill_id, now)
    end)
    |> Enum.find_value(fn row -> if rng.(10_000) <= row.rate, do: {:cast, row} end)
  end

  # Player-owned summons have no combat rotation of their own: their imported
  # rows are their entire behavior, so idle rows stay eligible in every state
  # (a damaged Marine Sphere must still wander and self-destruct while engaged).
  @spec row_state_eligible?(row(), MobState.t()) :: boolean()
  defp row_state_eligible?(%{state: :idle}, %MobState{owner_player_id: owner})
       when not is_nil(owner),
       do: true

  defp row_state_eligible?(row, mob_state), do: state_matches?(row.state, mob_state)

  # Row states are named as imported: `attack` is the berserk state and
  # `chase` the rush state.
  @row_states %{attack: :berserk, chase: :rush}

  @spec state_matches?(atom(), MobState.t()) :: boolean()
  defp state_matches?(:any, %MobState{skill_state: skill_state}), do: skill_state != :dead

  defp state_matches?(:anytarget, %MobState{skill_state: skill_state, target_ref: target_ref}),
    do: target_ref != nil and skill_state not in [:dead, :loot]

  defp state_matches?(row_state, %MobState{skill_state: skill_state}),
    do: Map.get(@row_states, row_state, row_state) == skill_state

  @spec castable?(row()) :: boolean()
  defp castable?(%{skill_id: skill_id}) do
    with {:ok, definition} <- SkillCatalog.by_id(skill_id),
         {:ok, _module} <- SkillCatalog.active_module_for(definition.name) do
      Castability.check(definition, :mob) == :ok
    else
      :error -> false
    end
  end

  @spec condition_holds?(row(), MobState.t(), map()) :: boolean()
  defp condition_holds?(%{condition: %{type: type}}, _mob_state, %{event: :rudeattacked})
       when type != :rudeattacked,
       do: false

  defp condition_holds?(%{condition: %{type: type}}, _mob_state, %{event: :spawn})
       when type != :onspawn,
       do: false

  defp condition_holds?(%{condition: condition}, mob_state, env) do
    evaluate(condition.type, condition, mob_state, env)
  end

  @spec evaluate(atom(), map(), MobState.t(), map()) :: boolean()
  defp evaluate(:always, _condition, _mob_state, _env), do: true

  defp evaluate(:myhpltmaxrate, %{value: value}, %MobState{hp: hp, max_hp: max_hp}, _env)
       when is_integer(value) and max_hp > 0 do
    hp_rate(hp, max_hp) <= value
  end

  defp evaluate(:myhpinrate, %{value: low, val1: high}, %MobState{hp: hp, max_hp: max_hp}, _env)
       when is_integer(low) and is_integer(high) and max_hp > 0 do
    rate = hp_rate(hp, max_hp)
    rate >= low and rate <= high
  end

  defp evaluate(type, %{value: status}, mob_state, env)
       when type in [:mystatuson, :mystatusoff] do
    case env.mob_statuses.(mob_state) do
      [] -> false
      statuses -> status_matches?(statuses, type == :mystatuson, status)
    end
  end

  defp evaluate(
         :alchemist,
         _condition,
         %MobState{
           owner_player_id: owner_player_id,
           trickcasting: trickcasting,
           hp: hp,
           max_hp: max_hp
         },
         _env
       ) do
    owner_player_id != nil and trickcasting == nil and hp < max_hp
  end

  defp evaluate(:trickcasting, _condition, %MobState{trickcasting: trickcasting}, _env),
    do: trickcasting != nil

  defp evaluate(:rudeattacked, _condition, _mob_state, %{event: :rudeattacked}), do: true

  defp evaluate(:rudeattacked, _condition, %MobState{attacked_count: count}, %{event: :tick}),
    do: count >= 1

  defp evaluate(:rudeattacked, _condition, _mob_state, _env), do: false

  defp evaluate(:onspawn, _condition, _mob_state, env), do: env.event == :spawn

  defp evaluate(:slavelt, %{value: value}, %MobState{instance_id: instance_id}, env)
       when is_integer(value) do
    env.count_living_slaves.(instance_id) < value
  end

  defp evaluate(:slavele, %{value: value}, %MobState{instance_id: instance_id}, env)
       when is_integer(value) do
    env.count_living_slaves.(instance_id) <= value
  end

  defp evaluate(:attackpcgt, %{value: value}, %MobState{instance_id: id}, env)
       when is_integer(value),
       do: env.targeted_count.({:mob, id}) > value

  defp evaluate(:attackpcge, %{value: value}, %MobState{instance_id: id}, env)
       when is_integer(value),
       do: env.targeted_count.({:mob, id}) >= value

  defp evaluate(:masterattacked, _condition, %MobState{master_id: master_id}, env)
       when is_integer(master_id) do
    env.living_unit.({:mob, master_id}) and env.targeted_count.({:mob, master_id}) > 0
  end

  defp evaluate(:afterskill, %{value: skill_id}, %MobState{last_skill_id: last}, _env)
       when is_integer(skill_id),
       do: last == skill_id

  defp evaluate(:mobnearbygt, %{value: value}, mob_state, env) when is_integer(value),
    do: env.nearby_mobs.(mob_state) > value

  defp evaluate(:friendhpltmaxrate, %{value: value}, mob_state, env) when is_integer(value),
    do: env.hp_rate_friend.(mob_state, 0, value) != nil

  defp evaluate(:friendhpinrate, %{value: low, val1: high}, mob_state, env)
       when is_integer(low) and is_integer(high),
       do: env.hp_rate_friend.(mob_state, low, high) != nil

  defp evaluate(type, %{value: status}, mob_state, env)
       when type in [:friendstatuson, :friendstatusoff],
       do: env.status_friend.(mob_state, type == :friendstatuson, status) != nil

  defp evaluate(_type, _condition, _mob_state, _env), do: false

  # The HP rate rounded down, as the source compares it.
  defp hp_rate(hp, max_hp), do: trunc(100 * (hp / max_hp))

  # The common abnormalities `anybad` stands for.
  @common_statuses [
    :sc_stone,
    :sc_freeze,
    :sc_stun,
    :sc_sleep,
    :sc_poison,
    :sc_curse,
    :sc_silence,
    :sc_confusion,
    :sc_blind,
    :sc_bleeding,
    :sc_dpoison,
    :sc_stonewait
  ]

  @doc """
  Whether `statuses` (a unit's status atoms) satisfy a status condition:
  `on?` asks for the status to be present, else absent. `:anybad` stands for
  any common abnormality; a numeric status id is the common status at that
  index (0 is stone).
  """
  @spec status_matches?([atom()], boolean(), atom() | integer()) :: boolean()
  def status_matches?(statuses, on?, status) do
    found? =
      case status_atom(status) do
        :anybad -> Enum.any?(@common_statuses, &(&1 in statuses))
        atom -> atom in statuses
      end

    if on?, do: found?, else: not found?
  end

  defp status_atom(:anybad), do: :anybad
  defp status_atom(index) when is_integer(index), do: Enum.at(@common_statuses, index, :anybad)
  defp status_atom(name) when is_atom(name), do: :"sc_#{name}"

  defp mob_statuses(%MobState{instance_id: id}),
    do: :mob |> StatusStorage.get_unit_statuses(id) |> Enum.map(& &1.type)
end
