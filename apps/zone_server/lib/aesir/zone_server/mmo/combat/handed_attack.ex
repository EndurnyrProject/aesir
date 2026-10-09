defmodule Aesir.ZoneServer.Mmo.Combat.HandedAttack do
  @moduledoc """
  Calculation of one hand-aware ordinary weapon swing.

  Resolves a chance-based attack proc, then the target's perfect dodge, then the
  critical, which always hits, and only then the accuracy roll. It calculates
  damage components without applying them and returns their immutable raw
  result. Its one side effect is the attacker's own Auto Counter stance, which a
  swing ends when it turns the swing critical.

  A classic swing the target flees still deals what follows the hit block
  (`DamageCalculator.calculate_fled_damage/3`) and connects when that totals at
  least 1; a perfect dodge deals nothing.

  A multi-hit proc (Double Attack) is one logical swing: its single calculated
  primary damage is repeated over the proc's divisions before the hand
  components derive from it, so the katar off-hand follows the repeated value
  while a dual-wield left hand keeps its own single calculation. The optional
  `:rng` function controls only the passive proc roll and defaults to
  `&:rand.uniform/1`.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.Critical
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  @emperium_mob_id 1288

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

    case swing_result(attacker, defender, double_attack?) do
      :critical -> calculate_hit(player_state, attacker, defender, divisions, true)
      :hit -> calculate_hit(player_state, attacker, defender, divisions, false)
      :miss -> calculate_fled(player_state, attacker, defender, divisions)
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

  defp swing_result(attacker, defender, multi_hit?) do
    HitCalculations.calculate_hit_result(
      %{
        hit: attacker.combat_stats.hit,
        char_id: attacker.unit_id,
        critical: fn -> Critical.normal_attack?(attacker, defender, multi_hit: multi_hit?) end,
        perfect_hit: EquipmentBonuses.perfect_hit_rate(attacker),
        hit_rate_bonus_pct: Map.get(attacker.combat_stats, :hit_rate_bonus_pct, 0)
      },
      %{
        flee: defender.combat_stats.flee,
        perfect_dodge: defender.combat_stats.perfect_dodge,
        unit_id: defender.unit_id,
        hit_rate_taken_flat: HitCalculations.normal_attack_hit_taken_flat(attacker, defender)
      }
    )
  end

  defp calculate_hit(player, attacker, defender, divisions, critical?) do
    primary_opts = if critical?, do: [force_crit: true], else: [skip_crit: true]

    with {:ok, primary} <- DamageCalculator.calculate_damage(attacker, defender, primary_opts),
         {primary, divisions} <- repeat_primary(primary, divisions, defender),
         {:ok, primary, secondary} <-
           components(player, attacker, defender, primary, plant_mode?(defender)) do
      {:ok, result(attacker, primary, secondary, divisions)}
    end
  end

  # A fled swing still deals what follows its hit block, through both hands as
  # a connected swing does, and is a hit when that totals at least 1. The plant
  # check belongs to the hit block, so a fled katar swing keeps its off-hand.
  defp calculate_fled(player, attacker, defender, divisions) do
    with {:ok, primary} <- DamageCalculator.calculate_fled_damage(attacker, defender, []),
         {damage, divisions} = DamageShared.normalize_damage_divisions(primary.damage, divisions),
         {:ok, primary, secondary} <-
           fled_components(player, attacker, defender, primary, damage) do
      case result(attacker, primary, secondary, divisions) do
        %{raw_total: total} = result when total >= 1 -> {:ok, result}
        _nothing -> {:ok, empty_result(attacker, divisions, :miss)}
      end
    end
  end

  # The bonuses after the 0 cap join both hands, so a right hand left at 0 means
  # the left hand deals only its own earlier damage; with none it deals nothing.
  defp fled_components(player, attacker, defender, primary, damage) do
    if damage == 0 and Map.get(primary, :left_components, 0) == 0,
      do: {:ok, %{primary | damage: 0}, nil},
      else: components(player, attacker, defender, %{primary | damage: damage}, false)
  end

  # A plant-mode Emperium contact stays at its fixed 1 damage; the proc's
  # divisions remain display metadata.
  defp repeat_primary(primary, divisions, defender) do
    if DamageCalculator.emperium_plant_contact?(defender, []) do
      {primary, divisions}
    else
      {damage, divisions} = DamageShared.normalize_damage_divisions(primary.damage, divisions)
      {%{primary | damage: damage}, divisions}
    end
  end

  defp components(
         %PlayerState{stats: %Stats{}} = player,
         %Combatant{right_hand: %WeaponHand{}, left_hand: %WeaponHand{}} = attacker,
         defender,
         primary,
         _plant?
       ) do
    primary = scale(primary, Passives.right_hand_damage_rate(player))
    critical_opts = if primary.is_critical, do: [force_crit: true], else: [skip_crit: true]
    # The first hand's call already ran the left hand's attribute steps.
    critical_opts =
      case Map.fetch(primary, :left_components) do
        {:ok, left} -> [{:left_components, left} | critical_opts]
        :error -> critical_opts
      end

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
         _defender,
         primary,
         plant?
       ) do
    secondary =
      if plant? do
        nil
      else
        %{primary | damage: div(primary.damage * Passives.katar_secondary_rate(player), 100)}
      end

    {:ok, primary, secondary}
  end

  defp components(_player, _attacker, _defender, primary, _plant?), do: {:ok, primary, nil}

  defp scale(%{damage: 0} = result, _rate), do: result
  defp scale(result, rate), do: %{result | damage: max(div(result.damage * rate, 100), 1)}

  defp plant_mode?(%Combatant{unit_type: :mob, monster_id: @emperium_mob_id}) do
    Mechanics.mob_formulas().emperium_damage_mode() == :plant
  end

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
