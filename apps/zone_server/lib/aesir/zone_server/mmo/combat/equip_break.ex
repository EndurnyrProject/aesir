defmodule Aesir.ZoneServer.Mmo.Combat.EquipBreak do
  @moduledoc """
  Resolves equipment-break attempts for player targets.

  `resolve/3` handles the weapon and armor rates attached to normal weapon hits.
  `resolve_slot/4` is the slot-specific entry point for skills that supply their
  own break rate. Both paths apply equipment-based prevention and the matching
  Chemical Protection status before rolling.

  Player targets include the character id because status effects are stored by
  unit identity: `{:player, character_id, stats}`. Non-player targets never emit
  target-break decisions because they have no breakable equipment.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats

  @type slot :: :weapon | :shield | :armor | :helm
  @type decision :: {:self, :weapon} | {:target, slot()}
  @type target :: {:player, integer(), Stats.t()} | {atom(), term()}

  @weapon_break_immune_types ~w(
    fist one_handed_axe two_handed_axe mace two_handed_mace staff two_handed_staff book huuma
  )a

  @chemical_protection %{
    weapon: :sc_cp_weapon,
    shield: :sc_cp_shield,
    armor: :sc_cp_armor,
    helm: :sc_cp_helm
  }

  @unbreakable_modifiers %{
    weapon: :unbreakable_weapon,
    shield: :unbreakable_shield,
    armor: :unbreakable_armor,
    helm: :unbreakable_helm
  }

  @default_rng &:rand.uniform/1

  @doc """
  Resolves natural self-weapon break and target weapon/armor break rates for a
  confirmed weapon hit.
  """
  @spec resolve(Stats.t(), target(), keyword()) :: [decision()]
  def resolve(%Stats{} = attacker, target, opts \\ []) do
    rng = Keyword.get(opts, :rng, @default_rng)

    [
      self_weapon(attacker, rng),
      target_slot(
        Stats.get_equipment_modifier(attacker, :break_weapon_rate),
        target,
        :weapon,
        rng
      ),
      target_slot(Stats.get_equipment_modifier(attacker, :break_armor_rate), target, :armor, rng)
    ]
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Resolves one target break attempt for `slot` at the supplied 1/10000 rate.

  Returns either the single target decision or an empty list, matching
  `resolve/3` so callers can dispatch decisions through the same pipeline.
  """
  @spec resolve_slot(integer(), target(), slot(), keyword()) :: [decision()]
  def resolve_slot(rate, target, slot, opts \\ [])
      when slot in [:weapon, :shield, :armor, :helm] do
    rng = Keyword.get(opts, :rng, @default_rng)

    case target_slot(rate, target, slot, rng) do
      nil -> []
      decision -> [decision]
    end
  end

  @spec self_weapon(Stats.t(), (pos_integer() -> pos_integer())) ::
          {:self, :weapon} | nil
  defp self_weapon(attacker, rng) do
    rate = apply_stat_prevention(Config.natural_break_rate(), attacker, :weapon)

    if weapon_breakable?(attacker) and broke?(rate, rng), do: {:self, :weapon}
  end

  @spec target_slot(integer(), target(), slot(), (pos_integer() -> pos_integer())) ::
          {:target, slot()} | nil
  defp target_slot(rate, _target, _slot, _rng) when rate <= 0, do: nil

  defp target_slot(rate, {:player, victim_id, %Stats{} = victim}, slot, rng) do
    rate = apply_prevention(rate, {victim_id, victim}, slot)

    if slot_breakable?(slot, victim) and broke?(rate, rng), do: {:target, slot}
  end

  defp target_slot(_rate, _target, _slot, _rng), do: nil

  @spec apply_prevention(integer(), {integer(), Stats.t()}, slot()) :: integer()
  defp apply_prevention(rate, {victim_id, %Stats{} = victim}, slot) do
    if slot_masked?({victim_id, victim}, slot) do
      0
    else
      apply_percentage_prevention(rate, victim)
    end
  end

  @spec apply_stat_prevention(integer(), Stats.t(), slot()) :: integer()
  defp apply_stat_prevention(rate, %Stats{} = victim, slot) do
    if stat_slot_masked?(victim, slot) do
      0
    else
      apply_percentage_prevention(rate, victim)
    end
  end

  @spec apply_percentage_prevention(integer(), Stats.t()) :: integer()
  defp apply_percentage_prevention(rate, victim) do
    unbreakable = Stats.get_equipment_modifier(victim, :unbreakable)
    max(0, rate - div(rate * unbreakable, 100))
  end

  @spec slot_masked?({integer(), Stats.t()}, slot()) :: boolean()
  defp slot_masked?({victim_id, victim}, slot) do
    stat_slot_masked?(victim, slot) or
      StatusStorage.has_status?(:player, victim_id, Map.fetch!(@chemical_protection, slot))
  end

  @spec stat_slot_masked?(Stats.t(), slot()) :: boolean()
  defp stat_slot_masked?(victim, slot) do
    victim
    |> Stats.get_equipment_modifier(Map.fetch!(@unbreakable_modifiers, slot))
    |> Kernel.>(0)
  end

  @spec slot_breakable?(slot(), Stats.t()) :: boolean()
  defp slot_breakable?(:weapon, victim), do: weapon_breakable?(victim)
  defp slot_breakable?(_slot, _victim), do: true

  @spec weapon_breakable?(Stats.t()) :: boolean()
  defp weapon_breakable?(%Stats{equipment: equipment}) do
    Stats.weapon_type(equipment) not in @weapon_break_immune_types
  end

  @spec broke?(integer(), (pos_integer() -> pos_integer())) :: boolean()
  defp broke?(rate, _rng) when rate <= 0, do: false
  defp broke?(rate, rng), do: rng.(10_000) <= rate
end
