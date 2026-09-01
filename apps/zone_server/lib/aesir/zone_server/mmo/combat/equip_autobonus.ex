defmodule Aesir.ZoneServer.Mmo.Combat.EquipAutobonus do
  @moduledoc """
  Pure matching for equipment autobonus registrations.
  """

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Unit.Player.Stats

  @roll_ceiling 1_000

  @type roll_fun :: (non_neg_integer() -> boolean())

  @spec on_attack(
          %{Stats.autobonus_key() => Stats.autobonus_registration()},
          BattleFlags.flag(),
          keyword()
        ) ::
          [Stats.autobonus_key()]
  def on_attack(registrations, battle_flag, opts \\ []) do
    matching_battle_registrations(registrations, :attack, battle_flag, opts)
  end

  @spec when_hit(
          %{Stats.autobonus_key() => Stats.autobonus_registration()},
          BattleFlags.flag(),
          keyword()
        ) ::
          [Stats.autobonus_key()]
  def when_hit(registrations, battle_flag, opts \\ []) do
    matching_battle_registrations(registrations, :when_hit, battle_flag, opts)
  end

  @spec on_skill(
          %{Stats.autobonus_key() => Stats.autobonus_registration()},
          pos_integer(),
          keyword()
        ) ::
          [Stats.autobonus_key()]
  def on_skill(registrations, skill_id, opts \\ []) do
    roll = Keyword.get(opts, :roll, &default_roll/1)

    registrations
    |> ordered_registrations()
    |> Enum.flat_map(fn
      {key, %{trigger: {:on_skill, ^skill_id}, rate: rate}} ->
        if successful_roll?(rate, roll), do: [key], else: []

      _entry ->
        []
    end)
  end

  @spec matching_battle_registrations(
          map(),
          :attack | :when_hit,
          BattleFlags.flag(),
          keyword()
        ) :: [Stats.autobonus_key()]
  defp matching_battle_registrations(registrations, trigger, battle_flag, opts) do
    roll = Keyword.get(opts, :roll, &default_roll/1)

    registrations
    |> ordered_registrations()
    |> Enum.flat_map(fn
      {key, %{trigger: ^trigger, battle_flag: registration_flag, rate: rate}} ->
        if BattleFlags.matches_battle?(registration_flag, battle_flag) and
             successful_roll?(rate, roll) do
          [key]
        else
          []
        end

      _entry ->
        []
    end)
  end

  @spec ordered_registrations(map()) :: [{Stats.autobonus_key(), map()}]
  defp ordered_registrations(registrations) do
    Enum.sort_by(registrations, fn {_key, registration} ->
      Map.fetch!(registration, :source_order)
    end)
  end

  @spec successful_roll?(integer(), roll_fun()) :: boolean()
  defp successful_roll?(rate, roll) do
    effective = clamp_rate(rate)
    effective > 0 and roll.(effective)
  end

  @spec clamp_rate(integer()) :: non_neg_integer()
  defp clamp_rate(rate), do: rate |> max(0) |> min(@roll_ceiling)

  @spec default_roll(non_neg_integer()) :: boolean()
  defp default_roll(rate), do: :rand.uniform(@roll_ceiling) <= rate
end
