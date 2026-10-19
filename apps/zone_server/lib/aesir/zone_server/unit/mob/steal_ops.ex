defmodule Aesir.ZoneServer.Unit.Mob.StealOps do
  @moduledoc """
  Owner-local item and zeny stealing decisions.

  Reads current status, map and catalog data and returns result tuples without
  packets or PubSub. The mob session commits successful and terminal-refusal
  states so competing attempts cannot both take an item.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @typedoc "Why an item steal attempt failed."
  @type reason :: :immune | :protected | :already_stolen | :status_blocked | :miss | :no_drop

  @typedoc "Effective caster DEX and an optional additive steal-rate bonus."
  @type item_caster :: %{
          required(:dex) => non_neg_integer(),
          optional(:add_steal_rate) => integer()
        }

  @typedoc "A successful claim, retryable refusal, or terminal refusal with its new state."
  @type item_result ::
          {:ok, non_neg_integer(), MobState.t()}
          | {:error, reason()}
          | {:error, reason(), MobState.t()}

  @typedoc "A zero-based random roll below the supplied positive bound."
  @type steal_rng :: (pos_integer() -> non_neg_integer())

  @typedoc "Effective caster stats used by RG_STEALCOIN."
  @type mug_caster() :: %{
          required(:dex) => non_neg_integer(),
          required(:luk) => non_neg_integer(),
          required(:base_level) => non_neg_integer()
        }

  @typedoc "Why a zeny steal attempt failed."
  @type mug_reason :: :no_coin | :immune

  @doc """
  Attempts one item steal inside the monster's owning process.

  A numeric caster argument keeps the DEX-only API with no bonus. Terminal
  refusals return their locked state; body-state, rate and drop misses remain
  retryable. Renewal rolls the base chance and each eligible drop; classic
  applies the chance to the drop threshold without a separate base roll.
  """
  @spec attempt_steal(MobState.t(), non_neg_integer() | item_caster(), non_neg_integer()) ::
          item_result()
  def attempt_steal(state, caster, skill_level),
    do: attempt_steal(state, caster, skill_level, &steal_roll/1)

  @doc "Attempts an item steal with deterministic zero-based rolls."
  @spec attempt_steal(
          MobState.t(),
          non_neg_integer() | item_caster(),
          non_neg_integer(),
          steal_rng()
        ) :: item_result()
  def attempt_steal(state, caster_dex, skill_level, rng) when is_integer(caster_dex),
    do: attempt_steal(state, %{dex: caster_dex}, skill_level, rng)

  def attempt_steal(%MobState{mob_data: mob_data} = state, %{dex: _} = caster, skill_level, rng) do
    cond do
      state.stolen_from ->
        {:error, :already_stolen}

      StatusDisplay.spawn_state(:mob, state.instance_id).body_state not in [0, 7] ->
        {:error, :status_blocked}

      state.master_id not in [nil, 0] ->
        {:error, :protected, MobState.mark_stolen(state)}

      MobState.status_immune?(state) ->
        {:error, :immune, MobState.mark_stolen(state)}

      :treasure in (mob_data.race_groups || []) or MapFlags.get(state.map_name, :nomobloot) ->
        {:error, :protected, MobState.mark_stolen(state)}

      true ->
        roll_item(state, caster, skill_level, rng)
    end
  end

  defp roll_item(state, caster, skill_level, rng) do
    rate =
      steal_rate(caster.dex, state.calculated.dex, skill_level) +
        Map.get(caster, :add_steal_rate, 0)

    mode = GameMode.mode()

    if rate < 1 or (mode == :renewal and rng.(100) >= rate) do
      {:error, :miss}
    else
      scale = if mode == :renewal, do: 100, else: rate

      case steal_drop(state.mob_data.drops, scale, rng) do
        {:ok, item_id} -> {:ok, item_id, MobState.mark_stolen(state)}
        :error -> {:error, :no_drop}
      end
    end
  end

  @doc """
  Attempts to steal zeny from a mob (RG_STEALCOIN).

  Returns the zeny amount and a state marked as mugged on success.
  Status-immune mobs, failed rolls, and already-mugged mobs do not mutate the
  state.
  """
  @spec attempt_mug(MobState.t(), mug_caster(), pos_integer()) ::
          {:ok, pos_integer(), MobState.t()} | {:error, mug_reason()}
  def attempt_mug(
        %MobState{mob_data: %{level: mob_level, modes: modes}} = state,
        %{dex: dex, luk: luk, base_level: base_level},
        skill_level
      ) do
    cond do
      :status_immune in modes ->
        {:error, :immune}

      state.coin_stolen ->
        {:error, :no_coin}

      :rand.uniform(1_000) > mug_rate(dex, luk, base_level, mob_level, skill_level) ->
        {:error, :no_coin}

      true ->
        zeny = (:rand.uniform(3) + 7) * mob_level + div(skill_level * mob_level, 10)
        {:ok, zeny, MobState.mark_coin_stolen(state)}
    end
  end

  @spec steal_rate(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: integer()
  defp steal_rate(caster_dex, mob_dex, skill_level) do
    div(caster_dex - mob_dex, 2) + 6 * skill_level + 4
  end

  @spec mug_rate(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          integer(),
          pos_integer()
        ) :: integer()
  defp mug_rate(dex, luk, base_level, mob_level, skill_level) do
    10 * skill_level + div(dex, 2) + div(luk, 2) + 2 * (base_level - mob_level)
  end

  @spec steal_drop([MobDrop.t()], integer(), steal_rng()) :: {:ok, non_neg_integer()} | :error
  defp steal_drop([], _scale, _rng), do: :error

  defp steal_drop([%MobDrop{steal_protected: true} | rest], scale, rng),
    do: steal_drop(rest, scale, rng)

  defp steal_drop([%MobDrop{item: item, rate: rate} | rest], scale, rng) do
    case ItemManagement.get_item_by_aegis(item) do
      {:ok, %{id: item_id}} ->
        if rng.(10_000) < rate * scale / 100.0,
          do: {:ok, item_id},
          else: steal_drop(rest, scale, rng)

      {:error, _reason} ->
        steal_drop(rest, scale, rng)
    end
  end

  defp steal_roll(bound), do: :rand.uniform(bound) - 1
end
