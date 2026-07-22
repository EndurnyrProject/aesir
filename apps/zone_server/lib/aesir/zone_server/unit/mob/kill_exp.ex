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

  `distribute/5` is the impure orchestrator, called synchronously from
  `Aesir.ZoneServer.Unit.Mob.MobSession.announce_kill/2` while the dying mob
  process still holds the full aggro history. Attackers who share an
  `exp_share` party have their damage-based shares pooled and re-split evenly
  across every currently eligible member of that party (`Party.ExpShare`,
  design "EXP share") -- not just the ones who attacked; other attackers are
  granted their own damage-based share directly, after the renewal
  level-gap penalty (`LevelPenalty.exp/2`). Every final grant is delivered as
  `{:progression, {:mob_kill_exp, base, job, mob_race}}` to the recipient's own
  `player:<char_id>` topic. The dead mob's race rides along so each recipient's
  own session can apply its per-race equipment EXP bonus — the bonus is a
  property of the receiving player's gear, not of the shared kill, so it cannot
  be folded into the shares computed here.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Party.ExpShare
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
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
  rides untouched into every grant, for the recipient's own per-race equipment
  EXP bonus.
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
    |> Enum.each(&distribute_group(&1, mob_level, mob_map, mob_race))

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
      {:ok, {_module, player_state, _pid}} ->
        player_state.map_name == mob_map and player_state.stats.current_state.hp > 0

      {:error, :not_found} ->
        false
    end
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

  defp distribute_group({nil, shares}, mob_level, _mob_map, mob_race) do
    Enum.each(shares, fn {char_id, {base_share, job_share}} ->
      grant_solo(char_id, base_share, job_share, mob_level, mob_race)
    end)
  end

  defp distribute_group({party_id, shares}, mob_level, mob_map, mob_race) do
    case PartyManager.get(party_id) do
      {:ok, party_state} ->
        {pooled_base, pooled_job} = pool(shares)

        party_state
        |> ExpShare.eligible_members(mob_map)
        |> then(
          &ExpShare.split(pooled_base, pooled_job, &1, Config.party_even_share_bonus(), mob_level)
        )
        |> Enum.each(fn {char_id, {base_slice, job_slice}} ->
          broadcast_grant(char_id, base_slice, job_slice, mob_race)
        end)

      {:error, _reason} ->
        Enum.each(shares, fn {char_id, {base_share, job_share}} ->
          grant_solo(char_id, base_share, job_share, mob_level, mob_race)
        end)
    end
  end

  defp pool(shares) do
    Enum.reduce(shares, {0, 0}, fn {_char_id, {base, job}}, {base_acc, job_acc} ->
      {base_acc + base, job_acc + job}
    end)
  end

  defp grant_solo(char_id, base_share, job_share, mob_level, mob_race) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, player_state, _pid}} ->
        rate = LevelPenalty.exp(mob_level, player_state.stats.progression.base_level)

        broadcast_grant(
          char_id,
          apply_level_penalty(base_share, rate),
          apply_level_penalty(job_share, rate),
          mob_race
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

  defp broadcast_grant(char_id, base, job, mob_race) do
    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{char_id}",
      {:progression, {:mob_kill_exp, base, job, mob_race}}
    )
  end
end
