defmodule Aesir.ZoneServer.Unit.Mob.KillExp do
  @moduledoc """
  Damage-based EXP distribution for a mob kill (design "Damage-based EXP
  share"): every attacker who damaged the mob is credited proportionally to their share of the total
  damage dealt, not just whoever landed the killing blow.

  `split/6` is the pure per-attacker formula: each eligible attacker's share
  is `their_damage / total_damage` of `base_exp`/`job_exp` (`total_damage`
  covers every attacker who ever hit the mob, even ones no longer eligible --
  their damage still dilutes everyone else's cut, matching rAthena), boosted
  by a flat multi-attacker bonus (`bonus_pct` percent per attacker beyond the
  first, counting at most `max_attackers` attackers -- rAthena
  `exp_bonus_attacker`/`exp_bonus_max_attacker`), each step truncated in that
  exact order. Floored at 1 whenever the attacker's own logged damage was
  positive. `eligible_damage/2` is the impure companion filtering an
  `aggro_list` down to attackers currently online, alive, and on the mob's
  map.

  `distribute/6` preserves the player-only API. `distribute_typed/7` is
  the mob-death orchestrator: it keeps actual contributors separate through
  splitting, grants active same-map companions 10% of eligible player and
  Homunculus base shares, then aggregates reward owners. Attackers who share an
  `exp_share` party have their damage-based shares pooled and re-split evenly
  across every currently eligible member of that party (`Party.ExpShare`,
  design "EXP share") -- not just the ones who attacked; other attackers are
  granted their own damage-based share directly, after the renewal
  level-gap penalty (`LevelPenalty.exp/2`). Every final grant is delivered as
  `{:progression, {:mob_kill_exp, base, job, mob_race, mob_class}}` to the
  recipient's own `player:<char_id>` topic. The dead mob's race and class ride
  along so each recipient's own session can apply its equipment EXP bonuses —
  the bonuses are properties of the receiving player's gear, not of the shared
  kill, so they cannot be folded into the shares computed here.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Party.ExpShare
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @doc """
  Splits `base_exp`/`job_exp` across `eligible_damage` (a `char_id => damage`
  map already filtered to currently-eligible attackers by `eligible_damage/2`)
  proportional to each attacker's share of `total_damage` (the sum of every
  attacker who ever hit the mob, eligible or not), boosted by `bonus_pct` per
  attacker beyond the first (capped at `max_attackers` attackers). Returns
  `%{char_id => {base_share, job_share}}`. Empty input yields an empty map.
  """
  @spec split(
          non_neg_integer(),
          non_neg_integer(),
          %{non_neg_integer() => pos_integer()},
          pos_integer(),
          non_neg_integer(),
          pos_integer()
        ) ::
          %{non_neg_integer() => {non_neg_integer(), non_neg_integer()}}
  def split(_base_exp, _job_exp, eligible_damage, _total_damage, _bonus_pct, _max_attackers)
      when map_size(eligible_damage) == 0,
      do: %{}

  def split(base_exp, job_exp, eligible_damage, total_damage, bonus_pct, max_attackers) do
    bonus = attacker_bonus(map_size(eligible_damage), bonus_pct, max_attackers)

    Map.new(eligible_damage, fn {char_id, dmg} ->
      {char_id,
       {damage_share(base_exp, dmg, total_damage, bonus),
        damage_share(job_exp, dmg, total_damage, bonus)}}
    end)
  end

  @doc """
  Splits eligible typed contributors without collapsing shared reward owners.

  `total_damage` must include the complete typed log, including ineligible and
  ownerless entries. The attacker bonus counts these eligible actual entries.
  """
  @spec split_typed(
          non_neg_integer(),
          non_neg_integer(),
          [map()],
          pos_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: [map()]
  def split_typed(base_exp, job_exp, eligible_entries, total_damage, bonus_pct, max_attackers) do
    bonus = attacker_bonus(length(eligible_entries), bonus_pct, max_attackers)

    Enum.map(eligible_entries, fn entry ->
      base_share = damage_share(base_exp, entry.damage, total_damage, bonus)

      entry
      |> Map.put(:base_share, base_share)
      |> Map.put(:job_share, damage_share(job_exp, entry.damage, total_damage, bonus))
      |> Map.put(:homunculus_share, div(base_share, 10))
    end)
  end

  @doc """
  Online, alive, same-`mob_map` subset of `aggro_list` (`char_id => cumulative
  damage`), read live from `UnitRegistry` (a damage-log entry says nothing
  about whether that attacker is still around to collect a share). A lookup
  404 (logged out mid-fight) is skipped rather than raising.
  """
  @spec eligible_damage(%{non_neg_integer() => pos_integer()}, String.t()) ::
          %{non_neg_integer() => pos_integer()}
  def eligible_damage(aggro_list, mob_map) do
    aggro_list
    |> Enum.filter(fn {char_id, _dmg} -> eligible?(char_id, mob_map) end)
    |> Map.new()
  end

  @doc """
  Computes every contributing attacker's final EXP grant for a mob kill and
  broadcasts it. `aggro_list` is the mob's full cumulative per-attacker
  damage log; `base_exp`/`job_exp` are the mob's undivided reward; `mob_level`
  feeds the renewal level-gap penalty for non-pooled attackers; `mob_map` is
  the mob's map, used to find each attacker's live party co-members; `mob_race`
  and `mob_class` ride untouched into every grant, for the recipient's own
  equipment EXP bonuses.
  """
  @spec distribute(
          %{non_neg_integer() => pos_integer()},
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          atom()
        ) :: :ok
  def distribute(aggro_list, base_exp, job_exp, mob_level, mob_map, mob_race) do
    distribute(aggro_list, base_exp, job_exp, mob_level, mob_map, mob_race, :normal)
  end

  @spec distribute(
          %{non_neg_integer() => pos_integer()},
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          atom(),
          :boss | :normal
        ) :: :ok
  def distribute(aggro_list, base_exp, job_exp, mob_level, mob_map, mob_race, mob_class) do
    total_damage = Enum.reduce(aggro_list, 0, fn {_char_id, dmg}, acc -> acc + dmg end)

    aggro_list
    |> eligible_damage(mob_map)
    |> then(
      &split(
        base_exp,
        job_exp,
        &1,
        total_damage,
        Config.exp_bonus_attacker(),
        Config.exp_bonus_max_attacker()
      )
    )
    |> Enum.group_by(fn {char_id, _share} -> exp_share_party_id(char_id) end)
    |> Enum.each(&distribute_group(&1, mob_level, mob_map, mob_race, mob_class))

    :ok
  end

  @doc """
  Distributes a complete ordered typed damage log through companion and owner rewards.

  Companion shares are delivered from actual player/Homunculus contributions before
  owner shares enter party pooling, level-gap adjustment, or player equipment bonuses.
  """
  @spec distribute_typed(
          [map()],
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          atom()
        ) ::
          :ok
  def distribute_typed(damage_log, base_exp, job_exp, mob_level, mob_map, mob_race) do
    distribute_typed(damage_log, base_exp, job_exp, mob_level, mob_map, mob_race, :normal)
  end

  @spec distribute_typed(
          [map()],
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          atom(),
          MobState.t() | :boss | :normal
        ) ::
          :ok
  def distribute_typed(damage_log, base_exp, job_exp, mob_level, mob_map, mob_race, state)
      when is_struct(state, MobState) do
    mob_class = if MobState.is_boss?(state), do: :boss, else: :normal
    distribute_typed(damage_log, base_exp, job_exp, mob_level, mob_map, mob_race, mob_class)
  end

  def distribute_typed(damage_log, base_exp, job_exp, mob_level, mob_map, mob_race, mob_class)
      when mob_class in [:boss, :normal] do
    total_damage = Enum.sum_by(damage_log, & &1.damage)
    eligible_entries = Enum.filter(damage_log, &eligible_typed?(&1, mob_map))

    shares =
      split_typed(
        base_exp,
        job_exp,
        eligible_entries,
        total_damage,
        Config.exp_bonus_attacker(),
        Config.exp_bonus_max_attacker()
      )

    grant_companion_shares(shares, mob_map)

    shares
    |> aggregate_owner_shares()
    |> Enum.group_by(fn {char_id, _share} -> exp_share_party_id(char_id) end)
    |> Enum.each(&distribute_group(&1, mob_level, mob_map, mob_race, mob_class))

    :ok
  end

  defp attacker_bonus(count, bonus_pct, max_attackers) when count > 1 do
    100 + (min(count, max_attackers) - 1) * bonus_pct
  end

  defp attacker_bonus(_count, _bonus_pct, _max_attackers), do: 100

  defp damage_share(amount, dmg, total_damage, bonus) do
    case div(div(amount * dmg, total_damage) * bonus, 100) do
      0 when amount > 0 and dmg > 0 -> 1
      share -> share
    end
  end

  defp eligible?(char_id, mob_map) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {PlayerState, %PlayerState{} = player_state, _pid}} ->
        player_state.map_name == mob_map and PlayerState.living?(player_state)

      {:ok, {_module, player_state, _pid}} ->
        player_state.map_name == mob_map and player_state.stats.current_state.hp > 0

      {:error, :not_found} ->
        false
    end
  end

  defp eligible_typed?(
         %{contributor: {:player, char_id}, reward_owner_id: char_id},
         mob_map
       ),
       do: eligible_player?(char_id, mob_map)

  defp eligible_typed?(
         %{contributor: {:homunculus, gid}, reward_owner_id: owner_id},
         mob_map
       ) do
    eligible_player?(owner_id, mob_map) and
      case UnitRegistry.get_unit(:homunculus, gid) do
        {:ok,
         {HomunculusState,
          %HomunculusState{owner_character_id: ^owner_id, map_name: ^mob_map} = homunculus, _pid}} ->
          HomunculusState.living?(homunculus)

        _other ->
          false
      end
  end

  defp eligible_typed?(
         %{contributor: {:mob, _gid}, reward_owner_id: owner_id},
         mob_map
       )
       when is_integer(owner_id),
       do: eligible_player?(owner_id, mob_map)

  defp eligible_typed?(_entry, _mob_map), do: false

  defp eligible_player?(char_id, mob_map) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {PlayerState, %PlayerState{map_name: ^mob_map} = player, _pid}} ->
        PlayerState.living?(player)

      _other ->
        false
    end
  end

  defp grant_companion_shares(shares, mob_map) do
    shares
    |> Enum.filter(&(&1.source_type in [:player, :homunculus]))
    |> Enum.group_by(& &1.reward_owner_id, & &1.homunculus_share)
    |> Enum.each(fn {owner_id, amounts} ->
      case active_companion(owner_id, mob_map) do
        {:ok, gid, owner_pid} ->
          PlayerSession.gain_homunculus_exp(owner_pid, gid, Enum.sum(amounts), mob_map)

        :error ->
          :ok
      end
    end)
  end

  defp active_companion(owner_id, mob_map) do
    :homunculus
    |> UnitRegistry.list_units_by_type()
    |> Enum.find_value(:error, &active_companion_entry(&1, owner_id, mob_map))
  end

  defp active_companion_entry(gid, owner_id, mob_map) do
    case UnitRegistry.get_unit(:homunculus, gid) do
      {:ok,
       {HomunculusState,
        %HomunculusState{owner_character_id: ^owner_id, map_name: ^mob_map} = homunculus,
        owner_pid}}
      when is_pid(owner_pid) ->
        if HomunculusState.living?(homunculus), do: {:ok, gid, owner_pid}

      _other ->
        nil
    end
  end

  defp aggregate_owner_shares(shares) do
    shares
    |> Enum.group_by(& &1.reward_owner_id)
    |> Map.new(fn {owner_id, entries} ->
      {base, job} =
        Enum.reduce(entries, {0, 0}, fn entry, {base, job} ->
          {base + entry.base_share, job + entry.job_share}
        end)

      {owner_id, {base, job}}
    end)
  end

  defp exp_share_party_id(char_id) do
    with {:ok, {_module, player_state, _pid}} <- UnitRegistry.get_unit(:player, char_id),
         party_id when party_id > 0 <- player_state.party_id,
         {:ok, %PartyState{exp_share: true}} <- PartyManager.get(party_id) do
      party_id
    else
      _ -> nil
    end
  end

  defp distribute_group({nil, shares}, mob_level, _mob_map, mob_race, mob_class) do
    Enum.each(shares, fn {char_id, {base_share, job_share}} ->
      grant_solo(char_id, base_share, job_share, mob_level, mob_race, mob_class)
    end)
  end

  defp distribute_group({party_id, shares}, mob_level, mob_map, mob_race, mob_class) do
    case PartyManager.get(party_id) do
      {:ok, party_state} ->
        {pooled_base, pooled_job} = pool(shares)

        party_state
        |> ExpShare.eligible_members(mob_map)
        |> then(
          &ExpShare.split(pooled_base, pooled_job, &1, Config.party_even_share_bonus(), mob_level)
        )
        |> Enum.each(fn {char_id, {base_slice, job_slice}} ->
          broadcast_grant(char_id, base_slice, job_slice, mob_race, mob_class)
        end)

      {:error, _reason} ->
        Enum.each(shares, fn {char_id, {base_share, job_share}} ->
          grant_solo(char_id, base_share, job_share, mob_level, mob_race, mob_class)
        end)
    end
  end

  defp pool(shares) do
    Enum.reduce(shares, {0, 0}, fn {_char_id, {base, job}}, {base_acc, job_acc} ->
      {base_acc + base, job_acc + job}
    end)
  end

  defp grant_solo(char_id, base_share, job_share, mob_level, mob_race, mob_class) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, player_state, _pid}} ->
        rate = LevelPenalty.exp(mob_level, player_state.stats.progression.base_level)

        broadcast_grant(
          char_id,
          apply_level_penalty(base_share, rate),
          apply_level_penalty(job_share, rate),
          mob_race,
          mob_class
        )

      {:error, :not_found} ->
        :ok
    end
  end

  defp apply_level_penalty(amount, rate) do
    case div(amount * rate, 100) do
      0 when amount > 0 -> 1
      scaled -> scaled
    end
  end

  defp broadcast_grant(char_id, base, job, mob_race, mob_class) do
    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{char_id}",
      {:progression, {:mob_kill_exp, base, job, mob_race, mob_class}}
    )
  end
end
