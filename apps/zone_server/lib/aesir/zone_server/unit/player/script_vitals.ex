defmodule Aesir.ZoneServer.Unit.Player.ScriptVitals do
  @moduledoc """
  The HP/SP change of the script heal commands, applied to a `PlayerState`.

  - `{:heal, hp, sp}` (`heal`): a forced heal. No rates; Frenzy does not stop
    it; a negative amount is passive damage that can kill, negative SP drains
    to zero. A dead player is untouched.
  - `{:item_heal, item_id, hp, sp}` (`itemheal`): the amounts scaled by
    `ItemHeal.amounts/4`, then applied as a forced heal.
  - `{:percent_heal, hp, sp}` (`percentheal`): No Recovery cancels both rates
    and, in renewal, Asura recovery the SP rate; each rate is clamped to
    -100..100. A positive rate heals that percent of the maximum (at least 1),
    refused for HP in Frenzy and on a dead player. A negative rate is passive
    damage of that percent of the maximum (at least 1) that leaves 1 HP unless
    the HP rate is -100; it still drains a dead player's SP.

  `apply/2` returns the new state and the HP damage it dealt as
  `{damage, hp_after}` (or `nil`), which the player session settles (status
  reactions, death) through `HealthHandler.settle_script_damage/2`.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.ItemHeal
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @typedoc "A script heal command with its rolled amounts."
  @type op ::
          {:heal, integer(), integer()}
          | {:item_heal, pos_integer() | nil, integer(), integer()}
          | {:percent_heal, integer(), integer()}

  @typedoc "HP damage dealt by a heal: the amount taken and the HP left."
  @type damage :: {pos_integer(), non_neg_integer()} | nil

  @doc "Applies `op` to `game_state`, returning the new state and the HP damage dealt."
  @spec apply(op(), PlayerState.t()) :: {PlayerState.t(), damage()}
  def apply({:heal, hp, sp}, game_state), do: forced(game_state, hp, sp)

  def apply({:item_heal, item_id, hp, sp}, game_state) do
    {hp, sp} = ItemHeal.amounts(game_state, item_id, hp, sp)
    forced(game_state, hp, sp)
  end

  def apply({:percent_heal, hp_rate, sp_rate}, game_state) do
    char_id = game_state.character_id

    sp_rate =
      if GameMode.mode() == :renewal and
           StatusStorage.has_status?(:player, char_id, :sc_extremityfist),
         do: 0,
         else: sp_rate

    {hp_rate, sp_rate} =
      if StatusStorage.has_status?(:player, char_id, :sc_norecover_state),
        do: {0, 0},
        else: {clamp_rate(hp_rate), clamp_rate(sp_rate)}

    cond do
      hp_rate >= 0 and sp_rate >= 0 ->
        percent_restore(game_state, hp_rate, sp_rate)

      hp_rate <= 0 and sp_rate <= 0 ->
        percent_drain(game_state, hp_rate, sp_rate)

      true ->
        {game_state, damage} = percent_side(game_state, hp_rate, 0)
        {game_state, nil} = percent_side(game_state, 0, sp_rate)
        {game_state, damage}
    end
  end

  @doc """
  Pushes the HP/SP that changed between `previous` and `current` to the client
  and persists them.
  """
  @spec sync(pid() | nil, PlayerState.t(), PlayerState.t()) :: :ok
  def sync(connection_pid, %PlayerState{} = previous, %PlayerState{} = current) do
    old = previous.stats.current_state
    new = current.stats.current_state

    changed =
      Enum.filter([hp: StatusParams.hp(), sp: StatusParams.sp()], fn {key, _param} ->
        Map.fetch!(old, key) != Map.fetch!(new, key)
      end)

    Enum.each(changed, fn {key, param} ->
      StatusSync.send_param(connection_pid, param, Map.fetch!(new, key))
    end)

    if changed != [] do
      fields = Map.new(changed, fn {key, _param} -> {key, Map.fetch!(new, key)} end)
      CharacterPersistence.update_stats(current.character_id, fields, async: true)
    end

    :ok
  end

  defp forced(game_state, hp, sp) do
    if dead?(game_state) do
      {game_state, nil}
    else
      {game_state, damage} = forced_hp(game_state, hp)
      {forced_sp(game_state, sp), damage}
    end
  end

  defp forced_hp(game_state, hp) when hp > 0, do: {restore(game_state, :hp, hp), nil}
  defp forced_hp(game_state, hp) when hp < 0, do: take_hp(game_state, -hp)
  defp forced_hp(game_state, _hp), do: {game_state, nil}

  defp forced_sp(game_state, sp) when sp > 0, do: restore(game_state, :sp, sp)
  defp forced_sp(game_state, sp) when sp < 0, do: drain_sp(game_state, -sp)
  defp forced_sp(game_state, _sp), do: game_state

  defp clamp_rate(rate), do: rate |> max(-100) |> min(100)

  defp percent_side(game_state, 0, 0), do: {game_state, nil}

  defp percent_side(game_state, hp_rate, sp_rate) when hp_rate > 0 or sp_rate > 0,
    do: percent_restore(game_state, hp_rate, sp_rate)

  defp percent_side(game_state, hp_rate, sp_rate),
    do: percent_drain(game_state, hp_rate, sp_rate)

  defp percent_restore(game_state, hp_rate, sp_rate) do
    if dead?(game_state) do
      {game_state, nil}
    else
      derived = game_state.stats.derived_stats

      hp =
        if DamageApplication.heal_refused?(:player, game_state.character_id),
          do: 0,
          else: percent_of(derived.max_hp, hp_rate)

      {game_state
       |> restore(:hp, hp)
       |> restore(:sp, percent_of(derived.max_sp, sp_rate)), nil}
    end
  end

  defp percent_drain(game_state, hp_rate, sp_rate) do
    derived = game_state.stats.derived_stats
    hp = percent_of(derived.max_hp, -hp_rate)
    current = game_state.stats.current_state.hp

    hp =
      cond do
        dead?(game_state) -> 0
        hp_rate == -100 -> hp
        true -> min(hp, current - 1)
      end

    {game_state, damage} =
      if hp > 0, do: take_hp(game_state, hp), else: {game_state, nil}

    {drain_sp(game_state, percent_of(derived.max_sp, -sp_rate)), damage}
  end

  defp percent_of(_max, 0), do: 0
  defp percent_of(max, 100), do: max
  defp percent_of(max, rate) when max > 100_000, do: max(div(max, 100) * rate, 1)
  defp percent_of(max, rate), do: max(div(max * rate, 100), 1)

  defp restore(game_state, _key, 0), do: game_state

  defp restore(game_state, :hp, amount),
    do: put(game_state, :hp, min(current(game_state, :hp) + amount, maximum(game_state, :hp)))

  defp restore(game_state, :sp, amount),
    do: put(game_state, :sp, min(current(game_state, :sp) + amount, maximum(game_state, :sp)))

  defp take_hp(game_state, amount) do
    current = current(game_state, :hp)
    damage = min(amount, current)
    {put(game_state, :hp, current - damage), {damage, current - damage}}
  end

  defp drain_sp(game_state, 0), do: game_state

  defp drain_sp(game_state, amount),
    do: put(game_state, :sp, max(current(game_state, :sp) - amount, 0))

  defp dead?(%PlayerState{action_state: :dead}), do: true
  defp dead?(game_state), do: current(game_state, :hp) <= 0

  defp current(game_state, key), do: Map.fetch!(game_state.stats.current_state, key)

  defp maximum(game_state, :hp), do: game_state.stats.derived_stats.max_hp
  defp maximum(game_state, :sp), do: game_state.stats.derived_stats.max_sp

  defp put(game_state, key, value) do
    stats = game_state.stats
    %{game_state | stats: %{stats | current_state: Map.put(stats.current_state, key, value)}}
  end
end
