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

  @typedoc "Already aggregated stat-derivation modifiers, not damage-stage rates."
  @type modifiers :: %{
          optional(:def | :mdef | :hit | :flee | :hom_aspd_rate) => integer()
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

  @typedoc "Derived combat snapshot and attack delay, without resource or persistence changes."
  @type result :: %{combat_stats: combat_stats(), attack_delay_ms: pos_integer()}

  @doc "Derives the mode's combat snapshot from captured stat stages."
  @callback derive(input()) :: result()

  @doc false
  @spec finish(map(), input(), integer()) :: result()
  def finish(combat, input, stat_delay) do
    haste = input.modifiers |> Map.get(:hom_aspd_rate, 0) |> max(0) |> min(1_000)
    bounded_delay = stat_delay |> max(100) |> min(8_000)
    delay = div(bounded_delay * (1_000 - haste), 1_000) |> max(100) |> min(8_000)

    combat =
      Map.merge(combat, %{
        matk_min: combat.matk,
        matk_max: combat.matk,
        critical: 1 + div(input.effective.luk, 3),
        critical_rate: 0,
        perfect_dodge: 0
      })

    %{combat_stats: combat, attack_delay_ms: delay}
  end
end
