defmodule Aesir.ZoneServer.Mmo.Homunculus.Stats do
  @moduledoc """
  Pure Renewal stat derivation for original and evolved Homunculi.

  Durable maximum HP and SP are retained as raw growth values. Passive bonuses
  and transient status modifiers are applied only to the returned runtime
  snapshot, so repeated derivation cannot compound them.
  """

  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @brain_surgery 8003
  @adamantium_skin 8007
  @instruction_change 8015

  @lif_classes [6001, 6005]
  @amistr_classes [6002, 6006]
  @vanilmirth_classes [6004, 6008]

  @instruction_str [1, 1, 3, 4, 4]
  @instruction_int [1, 2, 2, 4, 5]

  @typedoc "Status modifier values already aggregated for this Homunculus."
  @type modifiers :: %{optional(atom()) => number()}

  @doc "Derives effective resources, base stats, combat values, and passive regeneration rates."
  @spec recompute(HomunculusState.t(), modifiers()) :: HomunculusState.t()
  def recompute(%HomunculusState{} = state, modifiers \\ %{}) when is_map(modifiers) do
    state = ensure_raw_maxima(state)
    brain = passive_rank(state, @brain_surgery, @lif_classes)
    skin = passive_rank(state, @adamantium_skin, @amistr_classes)
    instruct = passive_rank(state, @instruction_change, @vanilmirth_classes)

    base = base_stats(state, instruct)
    effective = effective_stats(base, modifiers)
    max_hp = state.raw_max_hp + div(state.raw_max_hp * 2 * skin, 100)
    max_sp = state.raw_max_sp + div(state.raw_max_sp * brain, 100)
    combat = combat_stats(state, base, effective, modifiers, brain, skin)

    %{
      state
      | str: effective.str,
        agi: effective.agi,
        vit: effective.vit,
        int: effective.int,
        dex: effective.dex,
        luk: effective.luk,
        hp: min(state.hp, max_hp),
        max_hp: max_hp,
        sp: min(state.sp, max_sp),
        max_sp: max_sp,
        attack_delay_ms: attack_delay(state.raw_attack_delay_ms, effective, modifiers),
        combat_stats: combat
    }
  end

  @doc "Returns Brain Surgery's Healing Touch recovery bonus for later skill application."
  @spec healing_touch_bonus_rate(HomunculusState.t()) :: non_neg_integer()
  def healing_touch_bonus_rate(%HomunculusState{} = state) do
    2 * passive_rank(state, @brain_surgery, @lif_classes)
  end

  @doc "Returns the learned passive rank only for the matching species and form."
  @spec passive_rank(HomunculusState.t(), pos_integer(), [pos_integer()]) :: non_neg_integer()
  def passive_rank(%HomunculusState{} = state, skill_id, base_classes)
      when is_integer(skill_id) and is_list(base_classes) do
    case Catalog.by_id(state.class_id) do
      {:ok, %{base_class_id: base_class_id}} when is_integer(base_class_id) ->
        learned_rank(state.learned_skills, skill_id, base_class_id in base_classes)

      _wrong_species ->
        0
    end
  end

  defp learned_rank(skills, skill_id, true) do
    case Map.get(skills, skill_id, 0) do
      rank when is_integer(rank) and rank > 0 -> rank
      _unlearned -> 0
    end
  end

  defp learned_rank(_skills, _skill_id, false), do: 0

  @doc "Returns the current movement step delay after Homunculus movement-haste modifiers."
  @spec movement_delay_ms(pos_integer(), modifiers()) :: pos_integer()
  def movement_delay_ms(base_delay_ms, modifiers) when base_delay_ms > 0 and is_map(modifiers) do
    haste = modifiers |> Map.get(:movement_speed, 0) |> Kernel.-() |> max(0)
    div(base_delay_ms * max(100 - haste, 40), 100)
  end

  defp ensure_raw_maxima(%HomunculusState{raw_max_hp: nil, raw_max_sp: nil} = state) do
    %{
      state
      | raw_max_hp: state.max_hp,
        raw_max_sp: state.max_sp,
        raw_str: state.str,
        raw_agi: state.agi,
        raw_vit: state.vit,
        raw_int: state.int,
        raw_dex: state.dex,
        raw_luk: state.luk,
        raw_attack_delay_ms: state.attack_delay_ms
    }
  end

  defp ensure_raw_maxima(%HomunculusState{} = state), do: state

  defp base_stats(state, instruct) do
    %{
      str: state.raw_str + ranked(@instruction_str, instruct),
      agi: state.raw_agi,
      vit: state.raw_vit,
      int: state.raw_int + ranked(@instruction_int, instruct),
      dex: state.raw_dex,
      luk: state.raw_luk
    }
  end

  defp effective_stats(base, modifiers) do
    Map.new(base, fn {stat, value} -> {stat, value + modifier(modifiers, stat)} end)
  end

  defp combat_stats(state, base, effective, modifiers, brain, skin) do
    level = state.level

    %{
      atk: 2 * level + effective.str,
      atk_min: div(effective.str + effective.dex, 5),
      atk_max: div(effective.luk + effective.str + effective.dex, 3),
      def: hard_def(base, effective, level, skin, modifiers),
      soft_def: soft_def(base, effective),
      hit: max(level + effective.dex + 150 + modifier(modifiers, :hit), 1),
      flee: max(level + effective.agi + modifier(modifiers, :flee), 1),
      perfect_dodge: max(effective.luk + 10 + modifier(modifiers, :perfect_dodge), 0),
      critical: max(div(level, 10) + 10 + 3 * effective.luk + modifier(modifiers, :critical), 1),
      matk: matk_max(effective, level),
      matk_min: matk_min(effective, level),
      matk_max: matk_max(effective, level),
      mdef: hard_mdef(base, effective, level, modifiers),
      soft_mdef: soft_mdef(base, effective),
      hp_regen_rate: 5 * skin,
      sp_regen_rate: 3 * brain
    }
  end

  defp hard_def(base, effective, level, skin, modifiers) do
    base.vit + div(level, 2) + 4 * skin + div(effective.vit, 5) - div(base.vit, 5) +
      modifier(modifiers, :def)
  end

  defp soft_def(base, effective) do
    base.vit + div(base.agi, 2) +
      trunc((effective.vit - base.vit) / 2 + (effective.agi - base.agi) / 5)
  end

  defp hard_mdef(base, effective, level, modifiers) do
    trunc((base.vit + level) / 4 + base.int / 2) + div(effective.int, 5) - div(base.int, 5) +
      modifier(modifiers, :mdef)
  end

  defp soft_mdef(base, effective) do
    div(base.vit + base.int, 2) + effective.int - base.int +
      trunc((effective.dex - base.dex) / 5 + (effective.vit - base.vit) / 5)
  end

  defp matk_min(stats, level), do: stats.int + level + div(stats.int + stats.dex, 5)
  defp matk_max(stats, level), do: stats.int + level + div(stats.luk + stats.int + stats.dex, 3)

  defp attack_delay(base_delay, stats, modifiers) do
    stat_delay =
      base_delay - div(base_delay * stats.dex, 1_000) - div(stats.agi * base_delay, 250)

    haste = modifiers |> Map.get(:hom_aspd_rate, 0) |> trunc() |> min(1_000) |> max(0)
    stat_delay |> max(100) |> Kernel.*(1_000 - haste) |> div(1_000) |> max(100)
  end

  defp ranked(_values, 0), do: 0
  defp ranked(values, rank), do: Enum.at(values, rank - 1, 0)
  defp modifier(modifiers, key), do: modifiers |> Map.get(key, 0) |> trunc()
end
