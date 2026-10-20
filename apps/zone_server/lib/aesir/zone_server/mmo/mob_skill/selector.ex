defmodule Aesir.ZoneServer.Mmo.MobSkill.Selector do
  @moduledoc """
  Pure skill picker for a mob's AI tick.

  Given a mob's `MobState`, the skill rows applicable to its class (from
  `MobSkill.Db.rows_for/1`), and per-tick options, returns `{:cast, row}` for the
  first row that clears every gate, or `nil`. It reads state but never mutates
  it; the `MobSession` cast phase (Task P2-6) acts on the result.

  A mob with the no-cast mode picks nothing. Otherwise rows are visited in
  order and the first row passing every gate wins; no later row is tried:

    1. **State** - the row's `state` must match the mob's skill state
       (`state_matches?/2`): `any` matches every state but dead, `anytarget`
       every state but dead and loot while the mob has a target.
    2. **Delay** - the row's skill must be off cooldown (`MobState.skill_ready?/3`).
    3. **Castable** - the row's skill must resolve in the real skill catalog
       (`Skill.Catalog.by_id/1` with an active module) and satisfy its declared
       requirements for a mob caster. Non-castable rows are dropped silently;
       coverage is tracked once globally by the importer's manifest and the
       sweep test, not per-tick here (that would spam).
    4. **Rate** - a zero-based roll below 10000 must not exceed the row's rate,
       rolled before its condition, so a rate of 0 still fires once in 10000.
    5. **Condition** - the row's `condition` predicate must hold.

  `opts`:

    * `:now` - millisecond timestamp for the delay gate (default: current system
      time). The cast site passes the same clock it writes cooldowns with.
    * `:rng` - a 1-arg fun `(pos_integer -> non_neg_integer)` returning a
      zero-based roll below its argument (default uniform); injected so tests
      are deterministic.
    * `:event` - the AI event driving this selection (default `:tick`). The
      event names match the source's translated events: `:spawn`,
      `:rudeattacked` and `:casttargeted` fire only their own rows;
      `{:attacked, kind, damage}` is a landed hit (`:closed`, `:long`, or
      `:other` for any damage type the source maps to neither); and
      `{:skillused, skill_id}` (no damage reported) or
      `{:skillused, skill_id, damage}` fires the `skillused` rows naming that
      skill (or no skill) and, with damage, the `groundattacked` rows of a
      ground skill. The carried damage is what the source's `damagedgt`
      threshold and its ground-attacked requirement read. On a `:tick`, a
      `rudeattacked` row needs a rude-attack count of at least 1; the caller
      resets the count when such a row is picked.
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

  Event conditions fire only from their events, never from a periodic check.
  The source evaluates one ordered chain per row, so a `damagedgt` row also
  fires from a closed, long or other attack event (and from no skill-used or
  periodic event), and a `groundattacked` row fires from a skill-used event of
  a ground skill that took HP. `trickcasting` holds while the mob keeps a
  trick cast (`MobState.trickcasting`); `alchemist` needs a player-owned, hurt
  mob without one.
  """

  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Npc.SlaveSummon
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @typedoc "A mob skill row as produced by `MobSkill.Db`."
  @type row :: map()

  @typedoc "A landed hit's event: its range kind and the HP damage it took."
  @type attack_event :: {:attacked, :closed | :long | :other, non_neg_integer()}

  @typedoc "The AI event a selection runs for."
  @type event ::
          :tick
          | :spawn
          | :rudeattacked
          | :casttargeted
          | attack_event()
          | {:skillused, pos_integer()}
          | {:skillused, pos_integer(), non_neg_integer()}

  @spec select(MobState.t(), [row()], keyword()) :: {:cast, row()} | nil
  def select(%MobState{} = mob_state, rows, opts \\ []) when is_list(rows) do
    now = Keyword.get(opts, :now, System.system_time(:millisecond))
    rng = Keyword.get(opts, :rng, &zero_based_roll/1)

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

    if MobState.mode?(mob_state, :no_cast),
      do: nil,
      else: Enum.find_value(rows, &pick(&1, mob_state, env, now, rng))
  end

  defp pick(row, mob_state, env, now, rng) do
    if row_state_eligible?(row, mob_state) and MobState.skill_ready?(mob_state, row.skill_id, now) and
         castable?(row) and rng.(10_000) <= row.rate and condition_holds?(row, mob_state, env),
       do: {:cast, row}
  end

  defp zero_based_roll(bound), do: :rand.uniform(bound) - 1

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

  # One ordered chain per row, as the source evaluates it: an exact event
  # match, the skill-used match, the ground-attacked match, the damage
  # threshold, and last - only for the periodic check - the state conditions.
  @spec condition_holds?(row(), MobState.t(), map()) :: boolean()
  defp condition_holds?(%{condition: condition}, mob_state, env) do
    cond do
      condition.type == exact_event_condition(env.event) ->
        true

      condition.type == :skillused ->
        skill_used?(condition, env)

      condition.type == :groundattacked ->
        event_damage(env) > 0 and ground_skill_used?(env)

      condition.type == :damagedgt ->
        damage_threshold?(condition, env)

      env.event == :tick ->
        evaluate(condition.type, condition, mob_state, env)

      true ->
        false
    end
  end

  @spec exact_event_condition(event()) :: atom() | nil
  defp exact_event_condition({:attacked, :closed, _damage}), do: :closedattacked
  defp exact_event_condition({:attacked, :long, _damage}), do: :longrangeattacked
  defp exact_event_condition(:casttargeted), do: :casttargeted
  defp exact_event_condition(:rudeattacked), do: :rudeattacked
  defp exact_event_condition(:spawn), do: :onspawn
  defp exact_event_condition(_event), do: nil

  # The source skips the damage threshold on a skill-used event.
  @spec damage_threshold?(map(), map()) :: boolean()
  defp damage_threshold?(%{value: value}, env) do
    damage = event_damage(env)
    not skill_used_event?(env) and damage > 0 and damage > value
  end

  @spec event_damage(map()) :: integer()
  defp event_damage(%{event: {:attacked, _kind, damage}}), do: damage
  defp event_damage(%{event: {:skillused, _skill_id, damage}}), do: damage
  defp event_damage(_env), do: 0

  @spec skill_used_event?(map()) :: boolean()
  defp skill_used_event?(%{event: {:skillused, _skill_id}}), do: true
  defp skill_used_event?(%{event: {:skillused, _skill_id, _damage}}), do: true
  defp skill_used_event?(_env), do: false

  @spec skill_used?(map(), map()) :: boolean()
  defp skill_used?(%{value: value}, %{event: {:skillused, skill_id}}),
    do: value in [skill_id, 0, nil]

  defp skill_used?(%{value: value}, %{event: {:skillused, skill_id, _damage}}),
    do: value in [skill_id, 0, nil]

  defp skill_used?(_condition, _env), do: false

  @spec ground_skill_used?(map()) :: boolean()
  defp ground_skill_used?(%{event: {:skillused, skill_id}}), do: ground_skill?(skill_id)
  defp ground_skill_used?(%{event: {:skillused, skill_id, _damage}}), do: ground_skill?(skill_id)
  defp ground_skill_used?(_env), do: false

  # The source's INF_GROUND_SKILL bit, which its skill DB sets from the
  # skill's ground target type.
  @spec ground_skill?(integer()) :: boolean()
  defp ground_skill?(skill_id) do
    with {:ok, definition} <- SkillCatalog.by_id(skill_id),
         do: Definition.cast_type(definition) == :ground
  end

  @spec evaluate(atom(), map(), MobState.t(), map()) :: boolean()
  defp evaluate(:always, _condition, _mob_state, _env), do: true

  defp evaluate(:myhpltmaxrate, %{value: value}, %MobState{hp: hp, calculated: calculated}, _env)
       when is_integer(value) and calculated.max_hp > 0 do
    max_hp = calculated.max_hp

    hp_rate(hp, max_hp) <= value
  end

  defp evaluate(
         :myhpinrate,
         %{value: low, val1: high},
         %MobState{hp: hp, calculated: calculated},
         _env
       )
       when is_integer(low) and is_integer(high) and calculated.max_hp > 0 do
    rate = hp_rate(hp, calculated.max_hp)
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
           calculated: calculated
         },
         _env
       ) do
    owner_player_id != nil and trickcasting == nil and hp < calculated.max_hp
  end

  defp evaluate(:trickcasting, _condition, %MobState{trickcasting: trickcasting}, _env),
    do: trickcasting != nil

  defp evaluate(:rudeattacked, _condition, %MobState{attacked_count: count}, %{event: :tick}),
    do: count >= 1

  defp evaluate(:rudeattacked, _condition, _mob_state, _env), do: false

  defp evaluate(:onspawn, _condition, _mob_state, _env), do: false

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
