defmodule Aesir.ZoneServer.Mmo.StatusEffect.MobParameters do
  @moduledoc """
  Initializes ordinary monster status values before they become held entries.

  Loaded entries bypass initialization and retain their captured parameters.
  Calculated-stat recipes consume these values rather than deriving magnitudes
  or rechecking the recipient's element or race during a later refresh.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.FieldElement
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @aspd_potion_tiers %{
    sc_aspdpotion0: 100,
    sc_aspdpotion1: 150,
    sc_aspdpotion2: 200,
    sc_aspdpotion3: 250
  }

  defp boss_level_bonus(level) when level > 10, do: 20 * (level - 10)
  defp boss_level_bonus(_level), do: 0

  @doc "Initializes a new monster status from the recipient's captured entity information."
  @spec initialize(StatusEntry.t(), GameMode.t(), map()) :: StatusEntry.t()
  def initialize(%{type: type} = entry, _mode, _target)
      when type in [:sc_decreaseagi, :sc_increaseagi],
      do: %{entry | val2: 2 + entry.val1}

  def initialize(%{type: :sc_concentrate} = entry, _mode, _target),
    do: %{entry | val2: 2 + entry.val1, val3: 0, val4: 0}

  def initialize(%{type: :sc_quagmire} = entry, _mode, _target),
    do: %{entry | val2: 10 * entry.val1}

  def initialize(%{type: :sc_magicpower} = entry, :renewal, _target),
    do: %{entry | val3: 5 * entry.val1}

  def initialize(%{type: :sc_magicpower} = entry, :pre_renewal, _target),
    do: %{entry | val2: 1, val3: 5 * entry.val1, val4: 0, state: Map.delete(entry.state, :armed)}

  def initialize(%{type: :sc_concentration} = entry, mode, _target) do
    rate = if mode == :renewal, do: 5 + 2 * entry.val1, else: 5 * entry.val1
    %{entry | val2: rate, val3: 10 * entry.val1, val4: rate}
  end

  def initialize(%{type: :sc_mindbreaker} = entry, _mode, _target),
    do: %{entry | val2: 20 * entry.val1, val3: 12 * entry.val1}

  def initialize(%{type: :sc_provoke, val1: 10} = entry, _mode, %{source_present: true})
      when entry.source_type != :player,
      do: %{entry | val2: 0, val3: 100}

  def initialize(%{type: :sc_provoke} = entry, _mode, _target),
    do: %{entry | val2: 2 + 3 * entry.val1, val3: 5 + 5 * entry.val1}

  def initialize(%{type: :sc_truesight} = entry, _mode, _target),
    do: %{entry | val2: 10 * entry.val1, val3: 3 * entry.val1}

  def initialize(%{type: :sc_stripweapon} = entry, _mode, _target), do: %{entry | val2: 25}
  def initialize(%{type: :sc_stripshield} = entry, _mode, _target), do: %{entry | val2: 15}

  def initialize(%{type: type} = entry, _mode, _target)
      when type in [:sc_striparmor, :sc_striphelm],
      do: %{entry | val2: 40}

  def initialize(%{type: type} = entry, _mode, _target) when type in [:sc_angelus, :sc_impositio],
    do: %{entry | val2: 5 * entry.val1}

  def initialize(%{type: :sc_explosionspirits} = entry, _mode, _target),
    do: %{entry | val2: 75 + 25 * entry.val1}

  def initialize(%{type: :sc_windwalk} = entry, _mode, _target),
    do: %{entry | val2: div(entry.val1 + 1, 2)}

  def initialize(%{type: :sc_change} = entry, _mode, _target),
    do: %{entry | val2: 30 * entry.val1, val3: 20 * entry.val1}

  def initialize(%{type: :sc_whistle} = entry, :renewal, _target),
    do: %{entry | val2: 18 + 2 * entry.val1, val3: div(entry.val1 + 1, 2) * 10}

  def initialize(%{type: :sc_humming} = entry, :renewal, _target),
    do: %{entry | val2: 4 * entry.val1}

  def initialize(%{type: :sc_fortunekiss} = entry, :renewal, _target),
    do: %{entry | val2: 10 * entry.val1}

  def initialize(%{type: :sc_drumbattle} = entry, :renewal, _target),
    do: %{entry | val2: 15 + 5 * entry.val1, val3: 15 * entry.val1}

  def initialize(%{type: :sc_drumbattle} = entry, :pre_renewal, _target),
    do: %{entry | val2: (entry.val1 + 1) * 25, val3: (entry.val1 + 1) * 2}

  def initialize(%{type: :sc_twohandquicken} = entry, _mode, _target),
    do: %{entry | val2: 300 + boss_level_bonus(entry.val1)}

  def initialize(%{type: :sc_spearquicken} = entry, :pre_renewal, _target),
    do: %{entry | val2: 200 + 10 * entry.val1}

  def initialize(%{type: type} = entry, _mode, _target)
      when type in [:sc_adrenaline, :sc_adrenaline2],
      do: %{entry | val3: if(entry.val2 != 0, do: 300, else: 200)}

  def initialize(%{type: :sc_assncross} = entry, :renewal, _target),
    do: %{entry | val2: if(entry.val1 < 10, do: entry.val1 * 2 - 1, else: 20)}

  def initialize(%{type: type} = entry, _mode, _target)
      when type in [:sc_aspdpotion0, :sc_aspdpotion1, :sc_aspdpotion2, :sc_aspdpotion3],
      do: %{entry | val2: Map.fetch!(@aspd_potion_tiers, type)}

  def initialize(%{type: :sc_fleet} = entry, _mode, _target), do: %{entry | val2: 30 * entry.val1}

  def initialize(%{type: :sc_avoid} = entry, _mode, _target), do: %{entry | val2: 10 * entry.val1}

  def initialize(%{type: :sc_emergency_move} = entry, _mode, _target), do: %{entry | val2: 25}

  def initialize(%{type: :sc_ensemblefatigue} = entry, :renewal, _target),
    do: %{entry | val2: 30}

  def initialize(%{type: :sc_gravitation} = entry, :pre_renewal, _target),
    do: %{entry | val2: 50 * entry.val1}

  def initialize(%{type: :sc_blessing} = entry, _mode, target) do
    %{entry | val2: if(RaceModifiers.undead_or_demon?(target), do: 0, else: entry.val1)}
  end

  def initialize(%{type: :sc_volcano} = entry, mode, target) do
    bonus = if mode == :renewal, do: 5 + 5 * entry.val1, else: 10 * entry.val1
    bonus = if mode == :pre_renewal and target.element != :fire, do: 0, else: bonus
    %{entry | val2: bonus, val3: FieldElement.enchant_bonus(entry.val1)}
  end

  def initialize(%{type: :sc_violentgale} = entry, mode, target) do
    bonus = if mode == :pre_renewal and target.element != :wind, do: 0, else: 3 * entry.val1
    %{entry | val2: bonus, val3: FieldElement.enchant_bonus(entry.val1)}
  end

  def initialize(%{type: :sc_deluge} = entry, mode, target) do
    bonus = elem({5, 9, 12, 14, 15}, max(rem(entry.val1 - 1, 5), 0))
    bonus = if mode == :pre_renewal and target.element != :water, do: 0, else: bonus
    %{entry | val2: bonus, val3: FieldElement.enchant_bonus(entry.val1)}
  end

  def initialize(entry, _mode, _target), do: entry
end
