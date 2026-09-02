defmodule Aesir.ZoneServer.Mmo.Combat.HandedAttack do
  @moduledoc """
  Pure calculation of one hand-aware ordinary weapon swing.

  Resolves a chance-based attack proc before the shared hit roll, calculates
  damage components without applying them, and returns their immutable raw
  result. The optional `:rng` function controls only the passive proc roll and
  defaults to `&:rand.uniform/1`.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  @enforce_keys [
    :primary,
    :secondary,
    :raw_total,
    :display_divisions,
    :outcome,
    :primary_element
  ]
  defstruct @enforce_keys

  @type outcome :: :hit | :critical | :miss | :perfect_dodge
  @type rng :: (pos_integer() -> pos_integer())
  @type t :: %__MODULE__{
          primary: DamageCalculator.damage_result(),
          secondary: DamageCalculator.damage_result() | nil,
          raw_total: non_neg_integer(),
          display_divisions: pos_integer(),
          outcome: outcome(),
          primary_element: atom()
        }

  @doc "Calculates one ordinary swing without delivery, mutation, or publication."
  @spec calculate(PlayerState.t(), Combatant.t(), Combatant.t(), keyword()) ::
          {:ok, t()} | {:error, atom()}
  def calculate(player_state, %Combatant{} = attacker, %Combatant{} = defender, opts \\ []) do
    {attacker, divisions, double_attack?} = resolve_attack_proc(player_state, attacker, opts)

    case hit_result(attacker, defender) do
      :hit -> calculate_hit(player_state, attacker, defender, divisions, double_attack?)
      outcome -> {:ok, empty_result(attacker, divisions, outcome)}
    end
  end

  defp resolve_attack_proc(%PlayerState{stats: %Stats{}} = player, attacker, opts) do
    case Passives.attack_procs(player) do
      %{multi_hit: 2} = proc ->
        chance = Map.get(proc, :chance, 100)
        rng = Keyword.get(opts, :rng, &:rand.uniform/1)

        if rng.(100) <= chance do
          hit_bonus = Map.get(proc, :hit_bonus, 0)
          combat_stats = Map.update!(attacker.combat_stats, :hit, &(&1 + hit_bonus))
          {%{attacker | combat_stats: combat_stats}, 2, true}
        else
          {attacker, 1, false}
        end

      _other ->
        {attacker, 1, false}
    end
  end

  defp resolve_attack_proc(_player_state, attacker, _opts), do: {attacker, 1, false}

  defp hit_result(attacker, defender) do
    HitCalculations.calculate_hit_result(
      %{
        hit: attacker.combat_stats.hit,
        char_id: attacker.unit_id,
        perfect_hit: EquipmentBonuses.perfect_hit_rate(attacker),
        hit_rate_bonus_pct: Map.get(attacker.combat_stats, :hit_rate_bonus_pct, 0)
      },
      %{
        flee: defender.combat_stats.flee,
        perfect_dodge: defender.combat_stats.perfect_dodge,
        unit_id: defender.unit_id
      }
    )
  end

  defp calculate_hit(player, attacker, defender, divisions, double_attack?) do
    primary_opts = [
      skip_crit: double_attack?,
      critical_rate_bonus: ranged_critical_rate(attacker)
    ]

    with {:ok, primary} <- DamageCalculator.calculate_damage(attacker, defender, primary_opts),
         {:ok, primary, secondary} <- components(player, attacker, defender, primary) do
      {:ok, result(attacker, primary, secondary, divisions)}
    end
  end

  defp ranged_critical_rate(%Combatant{weapon: %{type: weapon_type}} = attacker) do
    if WeaponTypes.requires_ammo?(weapon_type),
      do: EquipmentBonuses.critical_long_rate(attacker),
      else: 0
  end

  defp ranged_critical_rate(_attacker), do: 0

  defp components(
         %PlayerState{stats: %Stats{}} = player,
         %Combatant{
           right_hand: %WeaponHand{subtype: :dagger},
           left_hand: %WeaponHand{subtype: :dagger}
         } = attacker,
         defender,
         primary
       ) do
    primary = scale(primary, Passives.right_hand_damage_rate(player))
    critical_opts = if primary.is_critical, do: [force_crit: true], else: [skip_crit: true]

    case DamageCalculator.calculate_secondary_hand_damage(attacker, defender, critical_opts) do
      {:ok, secondary} ->
        {:ok, primary, scale(secondary, Passives.left_hand_damage_rate(player))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp components(
         %PlayerState{stats: %Stats{}} = player,
         %Combatant{right_hand: %WeaponHand{subtype: :katar}},
         defender,
         primary
       ) do
    secondary =
      if plant_mode?(defender) do
        nil
      else
        %{primary | damage: div(primary.damage * Passives.katar_secondary_rate(player), 100)}
      end

    {:ok, primary, secondary}
  end

  defp components(_player, _attacker, _defender, primary), do: {:ok, primary, nil}

  defp scale(result, rate), do: %{result | damage: max(div(result.damage * rate, 100), 1)}

  defp plant_mode?(%Combatant{race: :plant}), do: true
  defp plant_mode?(_defender), do: false

  defp result(attacker, primary, secondary, divisions) do
    %__MODULE__{
      primary: primary,
      secondary: secondary,
      raw_total: primary.damage + secondary_damage(secondary),
      display_divisions: divisions,
      outcome: if(primary.is_critical, do: :critical, else: :hit),
      primary_element: attacker.weapon.element
    }
  end

  defp empty_result(attacker, divisions, outcome) do
    %__MODULE__{
      primary: %{damage: 0, is_critical: false},
      secondary: nil,
      raw_total: 0,
      display_divisions: divisions,
      outcome: outcome,
      primary_element: attacker.weapon.element
    }
  end

  defp secondary_damage(nil), do: 0
  defp secondary_damage(secondary), do: secondary.damage
end
