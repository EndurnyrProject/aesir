defmodule Aesir.ZoneServer.Mmo.Homunculus.Ai.Decision do
  @moduledoc """
  Pure fixed-policy selection of one Homunculus AI intent per tick.
  """

  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Unit.Ref

  @type intent ::
          :idle
          | :feed
          | {:follow, Ref.t()}
          | {:recover, {integer(), integer()}}
          | {:cast, pos_integer(), pos_integer(), Ref.t()}
          | {:attack, Ref.t()}
          | {:chase, Ref.t()}

  @doc "Selects exactly one intent from owner, Homunculus, and nearby snapshots."
  @spec next(map(), map(), [map()]) :: intent()
  def next(owner, homunculus, candidates) when is_list(candidates) do
    if ready?(homunculus), do: next_ready(owner, homunculus, candidates), else: :idle
  end

  defp ready?(%{lifecycle: :active, alive?: true, busy?: false}), do: true
  defp ready?(_homunculus), do: false

  defp next_ready(owner, %{ai_config: %Config{} = config} = homunculus, candidates) do
    cond do
      feed_due?(homunculus, config) ->
        :feed

      recovered?(homunculus) ->
        {:recover, owner.position}

      distance(homunculus.position, owner.position) > config.leash_distance ->
        {:follow, owner.ref}

      homunculus.standby? ->
        :idle

      true ->
        combat_policy(owner, homunculus, candidates, config)
    end
  end

  defp feed_due?(homunculus, config) do
    config.auto_feed and homunculus.hunger <= config.auto_feed_threshold and
      homunculus.food_available?
  end

  defp recovered?(%{separated_ms: separated_ms}) when is_integer(separated_ms),
    do: separated_ms >= 3_000

  defp recovered?(_homunculus), do: false

  defp combat_policy(owner, homunculus, candidates, config) do
    candidates = Enum.filter(candidates, &candidate?(&1, owner.ref, config))

    target =
      select_target(
        candidates,
        homunculus.target,
        owner.target,
        owner.alive?,
        homunculus.retaliation_target,
        config,
        homunculus.position
      )

    auto_skill(owner, homunculus, target) ||
      combat_intent(target, homunculus.position, homunculus.attack_range)
  end

  defp select_target(
         candidates,
         current_target,
         owner_target,
         owner_alive?,
         retaliation_target,
         config,
         position
       ) do
    candidate_by_ref(candidates, current_target) ||
      if(config.join_owner_target and owner_alive?,
        do: candidate_by_ref(candidates, owner_target)
      ) ||
      if(config.retaliate, do: candidate_by_ref(candidates, retaliation_target)) ||
      proactive_target(candidates, config, position)
  end

  defp proactive_target(_candidates, %Config{stance: stance}, _position)
       when stance != :aggressive,
       do: nil

  defp proactive_target(candidates, %Config{} = config, position) do
    candidates
    |> Enum.filter(&proactively_allowed?(&1, config))
    |> Enum.min_by(&{distance(&1.position, position), &1.ref}, fn -> nil end)
  end

  defp proactively_allowed?(_candidate, %Config{allowed_mob_class_ids: []}), do: true

  defp proactively_allowed?(%{class_id: class_id}, %Config{allowed_mob_class_ids: allowed}),
    do: class_id in allowed

  defp auto_skill(owner, %{ai_config: config, skills: skills} = homunculus, target) do
    skills
    |> Enum.filter(&eligible_skill?(&1, config, target, owner, homunculus))
    |> Enum.sort_by(fn %{id: id} -> {-config.skills[id].priority, id} end)
    |> List.first()
    |> cast_intent(target, homunculus.ref, owner.ref)
  end

  defp eligible_skill?(skill, config, target, owner, homunculus) do
    with %{id: id, target: target_type, sp_cost: cost, cooldown_ready?: true} <- skill,
         %{mode: :auto} = skill_config <- config.skills[id],
         true <- cost <= homunculus.sp,
         true <-
           (homunculus.sp - cost) * 100 >= homunculus.max_sp * config.auto_cast_sp_reserve_percent,
         true <- thresholds_met?(skill_config, target, owner, homunculus),
         true <- target_available?(target_type, target, owner.alive?) do
      true
    else
      _ -> false
    end
  end

  defp thresholds_met?(config, target, owner, homunculus) do
    upper_threshold?(config.self_hp_threshold, homunculus.hp, homunculus.max_hp) and
      upper_threshold?(config.owner_hp_threshold, owner.hp, owner.max_hp) and
      target_range?(config.target_hp_range, target)
  end

  defp upper_threshold?(nil, _hp, _max_hp), do: true
  defp upper_threshold?(threshold, hp, max_hp), do: hp * 100 <= max_hp * threshold

  defp target_range?(nil, _target), do: true
  defp target_range?(_range, nil), do: false

  defp target_range?(%{min_percent: min_percent, max_percent: max_percent}, %{
         hp: hp,
         max_hp: max_hp
       }) do
    hp * 100 >= max_hp * min_percent and hp * 100 <= max_hp * max_percent
  end

  defp target_available?(:self, _target, _owner_alive?), do: true
  defp target_available?(:owner, _target, owner_alive?), do: owner_alive?
  defp target_available?(:enemy, target, _owner_alive?), do: target != nil

  defp cast_intent(nil, _target, _homunculus_ref, _owner_ref), do: nil

  defp cast_intent(%{id: id, level: level, target: :self}, _target, homunculus_ref, _owner_ref),
    do: {:cast, id, level, homunculus_ref}

  defp cast_intent(%{id: id, level: level, target: :owner}, _target, _homunculus_ref, owner_ref),
    do: {:cast, id, level, owner_ref}

  defp cast_intent(
         %{id: id, level: level, target: :enemy},
         %{ref: target_ref},
         _homunculus_ref,
         _owner_ref
       ),
       do: {:cast, id, level, target_ref}

  defp cast_intent(_skill, _target, _homunculus_ref, _owner_ref), do: nil

  defp combat_intent(nil, _position, _attack_range), do: :idle

  defp combat_intent(%{ref: target_ref, position: target_position}, position, attack_range) do
    if distance(position, target_position) <= attack_range,
      do: {:attack, target_ref},
      else: {:chase, target_ref}
  end

  defp candidate_by_ref(candidates, ref) when is_tuple(ref),
    do: Enum.find(candidates, &(&1.ref == ref))

  defp candidate_by_ref(_candidates, _ref), do: nil

  defp candidate?(candidate, owner_ref, config) do
    claim_safe?(candidate, owner_ref) and
      candidate.class_id not in config.denied_mob_class_ids and
      (not config.avoid_bosses or not candidate.boss?) and candidate.hp > 0
  end

  defp claim_safe?(%{claim_root: nil}, _owner_ref), do: true
  defp claim_safe?(%{claim_root: owner_ref}, owner_ref), do: Ref.valid?(owner_ref)
  defp claim_safe?(_candidate, _owner_ref), do: false

  defp distance({x1, y1}, {x2, y2}), do: max(abs(x1 - x2), abs(y1 - y2))
end
