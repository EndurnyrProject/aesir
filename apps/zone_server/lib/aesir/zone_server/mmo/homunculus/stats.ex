defmodule Aesir.ZoneServer.Mmo.Homunculus.Stats do
  @moduledoc """
  Mode-aware stat derivation for original and evolved Homunculi.

  Durable maximum HP and SP are retained as raw growth values. Passive bonuses
  and transient status modifiers are applied only to the returned runtime
  snapshot, so repeated derivation cannot compound them.
  """

  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Mechanics
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

    inputs = %{
      level: state.level,
      base_attack_delay_ms: state.raw_attack_delay_ms,
      raw: base_stats(state, 0),
      base: base,
      effective: effective,
      skin_rank: skin,
      modifiers:
        Map.new([:def, :mdef, :hit, :flee, :hom_aspd_rate], &{&1, modifier(modifiers, &1)})
    }

    %{combat_stats: combat, attack_delay_ms: delay} =
      Mechanics.homunculus_formulas().derive(inputs)

    combat = Map.merge(combat, %{hp_regen_rate: 5 * skin, sp_regen_rate: 3 * brain})

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
        attack_delay_ms: delay,
        combat_stats: combat
    }
  end

  @doc "Returns Brain Surgery's Healing Touch recovery bonus for later skill application."
  @spec healing_touch_bonus_rate(HomunculusState.t()) :: non_neg_integer()
  def healing_touch_bonus_rate(%HomunculusState{} = state) do
    2 * passive_rank(state, @brain_surgery, @lif_classes)
  end

  @doc "Returns Instruction Change's learned rank for original and evolved Vanilmirth."
  @spec instruction_change_rank(HomunculusState.t() | nil) :: non_neg_integer()
  def instruction_change_rank(nil), do: 0

  def instruction_change_rank(%HomunculusState{} = state) do
    passive_rank(state, @instruction_change, @vanilmirth_classes)
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

  defp ranked(_values, 0), do: 0
  defp ranked(values, rank), do: Enum.at(values, rank - 1, 0)
  defp modifier(modifiers, key), do: modifiers |> Map.get(key, 0) |> trunc()
end
