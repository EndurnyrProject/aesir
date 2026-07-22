defmodule Aesir.ZoneServer.Unit.Mob.StealOps do
  @moduledoc """
  Single-writer owner of the TF_STEAL roll: rate check, per-drop roll, and the
  `stolen_from` flip. Pure — result tuples only, no packets, no PubSub. Mirrors
  `Aesir.ZoneServer.Unit.Player.Handlers.BreakOps`'s Ops-layer contract.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @typedoc "Why a steal attempt failed."
  @type reason :: :boss | :already_stolen | :miss | :no_drop

  @doc """
  Attempts to steal one item from the mob described by `state`.

  Runs the full rate roll, per-drop roll and `stolen_from` flip. Rejects
  bosses and mobs already stolen from without consuming a roll. Returns
  `{:ok, item_id, new_state}` on a successful steal (with `stolen_from` set on
  `new_state`), or `{:error, reason}` — all but `:boss`/`:already_stolen` leave
  the state untouched, so the caller may retry. The caller is responsible for
  running this inside the mob's own process so concurrent attempts can't both
  succeed.
  """
  @spec attempt_steal(MobState.t(), non_neg_integer(), pos_integer()) ::
          {:ok, non_neg_integer(), MobState.t()} | {:error, reason()}
  def attempt_steal(%MobState{mob_data: mob_data} = state, caster_dex, skill_level) do
    cond do
      :boss in (mob_data.modes || []) ->
        {:error, :boss}

      state.stolen_from ->
        {:error, :already_stolen}

      :rand.uniform(100) > steal_rate(caster_dex, mob_data.stats.dex, skill_level) ->
        {:error, :miss}

      true ->
        case steal_drop(mob_data.drops) do
          {:ok, item_id} -> {:ok, item_id, MobState.mark_stolen(state)}
          :error -> {:error, :no_drop}
        end
    end
  end

  # rAthena pc_steal_item renewal rate formula, expressed as a percent out of 100.
  @spec steal_rate(non_neg_integer(), non_neg_integer(), pos_integer()) :: integer()
  defp steal_rate(caster_dex, mob_dex, skill_level) do
    div(caster_dex - mob_dex, 2) + 6 * skill_level + 4
  end

  # Walks the drop table in order, skipping steal-protected entries, and rolls
  # each remaining drop's own `rnd(10000) <= rate`. The first roll to succeed
  # wins; an unresolvable item name is treated as a miss on that drop rather
  # than aborting the whole steal.
  @spec steal_drop([MobDrop.t()]) :: {:ok, non_neg_integer()} | :error
  defp steal_drop([]), do: :error

  defp steal_drop([%MobDrop{steal_protected: true} | rest]), do: steal_drop(rest)

  defp steal_drop([%MobDrop{item: item, rate: rate} | rest]) do
    if :rand.uniform(10_000) <= rate do
      case ItemManagement.get_item_by_aegis(item) do
        {:ok, %{id: item_id}} -> {:ok, item_id}
        {:error, _reason} -> steal_drop(rest)
      end
    else
      steal_drop(rest)
    end
  end
end
