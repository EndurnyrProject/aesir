defmodule Aesir.ZoneServer.Mmo.Combat.EquipVanish do
  @moduledoc """
  Equipment-granted percentage HP/SP loss.

  Category-gated entries roll independently after a positive hit, sum the
  percentages of successful entries, and ask the target's owning session to
  apply the nonlethal HP loss and clamped SP loss.

  Race-gated entries are the Vellum normal-attack variant: matching race and
  `:all` values combine, HP is tried before SP, and a successful result replaces
  the ordinary swing with max-resource damage.
  """

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication

  @roll_ceiling 1_000
  @generic_families [
    {:hp, :hp_vanish_rate, :hp_vanish_percent},
    {:sp, :sp_vanish_rate, :sp_vanish_percent}
  ]

  @typedoc "A per-mille roll predicate receiving the effective chance."
  @type roll_fun :: (integer() -> boolean())

  @typedoc "A normal-swing replacement using the target's maximum resource."
  @type override :: :none | {:hp | :sp, non_neg_integer()}

  @doc "Rolls category-gated vanish entries for one positive delivered hit."
  @spec after_hit(Combatant.t(), Combatant.t(), pid(), BattleFlags.flag(), keyword()) :: :ok
  def after_hit(attacker, target, target_pid, attack_flag, opts \\ [])

  def after_hit(
        %Combatant{unit_type: :player} = attacker,
        %Combatant{unit_type: target_type},
        target_pid,
        attack_flag,
        opts
      )
      when target_type in [:player, :mob] and is_pid(target_pid) do
    roll = Keyword.get(opts, :roll, &default_roll/1)
    %{hp: hp_percent, sp: sp_percent} = roll_generic(attacker, attack_flag, roll)

    if hp_percent > 0 or sp_percent > 0 do
      DamageApplication.apply_vanish(
        target_type,
        target_pid,
        hp_percent,
        sp_percent,
        {:player, attacker.unit_id}
      )
    end

    :ok
  end

  def after_hit(_attacker, _target, _target_pid, _attack_flag, _opts), do: :ok

  @doc "Rolls the race-gated replacement for one landed normal weapon swing."
  @spec normal_attack_override(Combatant.t(), Combatant.t(), keyword()) :: override()
  def normal_attack_override(attacker, target, opts \\ [])

  def normal_attack_override(
        %Combatant{unit_type: :player} = attacker,
        %Combatant{race: race} = target,
        opts
      ) do
    roll = Keyword.get(opts, :roll, &default_roll/1)

    case race_override(attacker.equip_modifiers, target, race, :hp, roll) do
      :none -> race_override(attacker.equip_modifiers, target, race, :sp, roll)
      override -> override
    end
  end

  def normal_attack_override(_attacker, _target, _opts), do: :none

  defp roll_generic(attacker, attack_flag, roll) do
    Enum.reduce(@generic_families, %{hp: 0, sp: 0}, fn family, acc ->
      {resource, percent} = roll_family(family, attacker.equip_modifiers, attack_flag, roll)
      Map.put(acc, resource, percent)
    end)
  end

  defp roll_family({resource, rate_family, percent_family}, modifiers, attack_flag, roll) do
    percent =
      Enum.reduce(modifiers, 0, fn entry, sum ->
        sum + vanish_percent(entry, modifiers, rate_family, percent_family, attack_flag, roll)
      end)

    {resource, percent}
  end

  defp vanish_percent(
         {{rate_family, flag}, rate},
         modifiers,
         rate_family,
         percent_family,
         attack_flag,
         roll
       )
       when is_integer(flag) and is_integer(rate) do
    if BattleFlags.matches_battle?(flag, attack_flag) and successful?(rate, roll) do
      Map.get(modifiers, {percent_family, flag}, 0)
    else
      0
    end
  end

  defp vanish_percent(
         _entry,
         _modifiers,
         _rate_family,
         _percent_family,
         _attack_flag,
         _roll
       ),
       do: 0

  defp race_override(modifiers, target, race, resource, roll) do
    {rate_family, percent_family, maximum} = race_families(resource, target)
    rate = race_value(modifiers, rate_family, race)
    percent = race_value(modifiers, percent_family, race)

    if percent > 0 and successful?(rate, roll) and is_integer(maximum) and maximum >= 0 do
      {resource, div(maximum * percent, 100)}
    else
      :none
    end
  end

  defp race_families(:hp, target),
    do: {:hp_vanish_race_rate, :hp_vanish_race_percent, target.max_hp}

  defp race_families(:sp, target),
    do: {:sp_vanish_race_rate, :sp_vanish_race_percent, target.max_sp}

  defp race_value(modifiers, family, race),
    do: Map.get(modifiers, {family, race}, 0) + Map.get(modifiers, {family, :all}, 0)

  defp successful?(rate, _roll) when rate >= @roll_ceiling, do: true
  defp successful?(rate, roll) when rate > 0, do: roll.(rate)
  defp successful?(_rate, _roll), do: false

  defp default_roll(rate), do: :rand.uniform(@roll_ceiling) <= rate
end
