defmodule Aesir.ZoneServer.Party.ExpShare do
  @moduledoc """
  Pools killer-blow EXP across an `exp_share` party's eligible members and
  splits it per-member (design "EXP share").

  `split/5` is the pure formula: pool ÷ eligible count, × bonus ÷ 100 (bonus
  scaling favors larger parties), × each member's `LevelPenalty.exp/2` rate ÷
  100 -- every step truncates, in that exact order, mirroring the worked
  pseudocode in the design doc. `eligible_members/2` is the impure companion
  that reads `UnitRegistry` for the live map/HP a member's own `Party.Member`
  entry may not yet reflect.
  """

  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Splits `base_exp`/`job_exp` across `eligible_members`, scaled by
  `even_share_bonus` and each member's renewal level-gap penalty for
  `mob_level` (`LevelPenalty.exp/2`). Returns `%{char_id => {base_slice,
  job_slice}}`. Each member's final slice is floored at 1 when its
  pre-penalty (post-bonus) pooled share was positive, mirroring the solo
  path's floor-at-1 rule. Empty input yields an empty map.
  """
  @spec split(non_neg_integer(), non_neg_integer(), [Member.t()], non_neg_integer(), integer()) ::
          %{non_neg_integer() => {non_neg_integer(), non_neg_integer()}}
  def split(_base_exp, _job_exp, [], _even_share_bonus, _mob_level), do: %{}

  def split(base_exp, job_exp, eligible_members, even_share_bonus, mob_level) do
    count = length(eligible_members)
    bonus = 100 + even_share_bonus * (count - 1)
    pooled_base = pooled_share(base_exp, count, bonus)
    pooled_job = pooled_share(job_exp, count, bonus)

    Map.new(eligible_members, fn %Member{} = member ->
      rate = LevelPenalty.exp(mob_level, member.base_level)

      {member.char_id, {member_slice(pooled_base, rate), member_slice(pooled_job, rate)}}
    end)
  end

  @doc """
  Online members of `party_state` on `mob_map` and currently alive, read live
  from `UnitRegistry` rather than the entry's own (possibly stale)
  `Party.Member.map_name`. A member whose registry lookup 404s (logged out
  mid-flight) is skipped rather than raising.
  """
  @spec eligible_members(State.t(), String.t()) :: [Member.t()]
  def eligible_members(%State{} = party_state, mob_map) do
    party_state
    |> State.online_members()
    |> Enum.filter(&eligible?(&1, mob_map))
  end

  defp eligible?(%Member{char_id: char_id}, mob_map) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, player_state, _pid}} ->
        player_state.map_name == mob_map and player_state.stats.current_state.hp > 0

      {:error, :not_found} ->
        false
    end
  end

  defp pooled_share(amount, count, bonus) do
    div(div(amount, count) * bonus, 100)
  end

  defp member_slice(pooled_amount, rate) do
    case div(pooled_amount * rate, 100) do
      0 when pooled_amount > 0 -> 1
      scaled -> scaled
    end
  end
end
