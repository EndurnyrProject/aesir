defmodule Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas do
  @moduledoc """
  Numeric stat derivation for original and evolved Homunculi.

  Raw stats precede passives, base stats include passives, and effective stats
  include transient modifiers. Implementations perform no lookups or random
  draws. Weapon endpoints describe a half-open normal-attack interval.
  """

  @typedoc "Whole stats at one stage of derivation."
  @type stats :: %{
          str: integer(),
          agi: integer(),
          vit: integer(),
          int: integer(),
          dex: integer(),
          luk: integer()
        }

  @typedoc """
  Already aggregated stat-derivation modifiers, not damage-stage rates. `batk`
  and `batk_rate` are the status ATK stages, `watk` the status weapon ATK and
  `matk` the flat status MATK.
  """
  @type modifiers :: %{
          optional(
            :batk
            | :batk_rate
            | :watk
            | :matk
            | :def
            | :def_cut_rate
            | :mdef
            | :hit
            | :flee
            | :hom_aspd_rate
            | :blind_accuracy_rate
          ) => integer()
        }

  @typedoc "Captured numeric inputs with species eligibility resolved by the caller."
  @type input :: %{
          level: non_neg_integer(),
          base_attack_delay_ms: pos_integer(),
          raw: stats(),
          base: stats(),
          effective: stats(),
          skin_rank: non_neg_integer(),
          modifiers: modifiers()
        }

  @typedoc "Combat values with display percent distinct from authoritative critical chance."
  @type combat_stats :: %{
          atk: integer(),
          atk_min: integer(),
          atk_max: integer(),
          def: integer(),
          soft_def: integer(),
          mdef: integer(),
          soft_mdef: integer(),
          hit: integer(),
          flee: integer(),
          matk: integer(),
          matk_min: integer(),
          matk_max: integer(),
          critical: integer(),
          critical_rate: 0,
          perfect_dodge: 0
        }

  @typedoc "A mode's combat values before the shared accuracy, MATK and critical finish."
  @type mode_combat_stats :: %{
          atk: integer(),
          atk_min: integer(),
          atk_max: integer(),
          def: integer(),
          soft_def: integer(),
          mdef: integer(),
          soft_mdef: integer(),
          hit: integer(),
          flee: integer(),
          matk: integer()
        }

  @typedoc "Derived combat snapshot and attack delay, without resource or persistence changes."
  @type result :: %{combat_stats: combat_stats(), attack_delay_ms: pos_integer()}

  @doc "Derives the mode's combat snapshot from captured stat stages."
  @callback derive(input()) :: result()

  @doc """
  Status DEF before the VIT share: the base DEF plus the flat status DEF, less
  Divest Shield's percent cut. The VIT share is added after it.
  """
  @spec status_def(integer(), modifiers()) :: integer()
  def status_def(base_def, modifiers) do
    value = base_def + Map.get(modifiers, :def, 0)
    value - div(value * Map.get(modifiers, :def_cut_rate, 0), 100)
  end

  @doc "A weapon bound plus the flat status weapon ATK, held to `0..65_535`."
  @spec status_watk(integer(), modifiers()) :: non_neg_integer()
  def status_watk(bound, modifiers), do: clamp_ushort(bound + Map.get(modifiers, :watk, 0))

  @doc false
  @spec finish(mode_combat_stats(), input(), integer()) :: result()
  def finish(combat, input, stat_delay) do
    haste = input.modifiers |> Map.get(:hom_aspd_rate, 0) |> max(0) |> min(1_000)
    bounded_delay = stat_delay |> max(100) |> min(8_000)
    delay = div(bounded_delay * (1_000 - haste), 1_000) |> max(100) |> min(8_000)

    blind_rate = Map.get(input.modifiers, :blind_accuracy_rate, 0)
    matk = clamp_ushort(combat.matk + Map.get(input.modifiers, :matk, 0))

    combat =
      Map.merge(combat, %{
        hit: max(combat.hit - div(combat.hit * blind_rate, 100), 1),
        flee: max(combat.flee - div(combat.flee * blind_rate, 100), 1),
        matk: matk,
        matk_min: matk,
        matk_max: matk,
        critical: 1 + div(input.effective.luk, 3),
        critical_rate: 0,
        perfect_dodge: 0
      })

    %{combat_stats: combat, attack_delay_ms: delay}
  end

  defp clamp_ushort(value), do: value |> max(0) |> min(65_535)
end
