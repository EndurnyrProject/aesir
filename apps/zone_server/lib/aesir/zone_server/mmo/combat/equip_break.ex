defmodule Aesir.ZoneServer.Mmo.Combat.EquipBreak do
  @moduledoc """
  Resolves equipment-break attempts for player targets.

  `resolve/3` handles the weapon and armor rates attached to weapon hits. Its
  wearer may be a `%Stats{}` or a `%Combatant{}`; a player summon's hits resolve
  their master's combatant, whose rates its equipment carries. `resolve_rates/4`
  resolves the two target rates alone, for a caller that already has them.
  `resolve_slot/4` is the slot-specific entry point for skills that supply their
  own break rate. Every path applies equipment-based prevention and the matching
  Chemical Protection status before rolling.

  Player targets include the character id because status effects are stored by
  unit identity: `{:player, character_id, stats}`. Non-player targets never emit
  target-break decisions because they have no breakable equipment.

  Garment and shoes are valid `resolve_slot/4` targets and honor the matching
  `unbreakable_*` prevention flag, but no natural weapon hit ever rolls them:
  in Renewal only weapon, armor, shield and helm break, so `resolve/3` never
  emits a garment or shoes decision. They also have no Chemical Protection
  counterpart, so their protection lookup yields none.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats

  @type slot :: :weapon | :shield | :armor | :helm | :garment | :shoes
  @type decision :: {:self, :weapon} | {:target, slot()}
  @type target :: {:player, integer(), Stats.t()} | {atom(), term()}
  @type rng :: (pos_integer() -> pos_integer())

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
    helm: :unbreakable_helm,
    garment: :unbreakable_garment,
    shoes: :unbreakable_shoes
  }

  @default_rng &:rand.uniform/1

  @doc """
  Resolves natural self-weapon break and target weapon/armor break rates for a
  confirmed weapon hit.

  The target rates come from the attacker's equipment; the self-break uses the
  configured natural rate and the attacker's own weapon, prevention and, for a
  combatant (whose unit id is known), Chemical Protection (Weapon).
  """
  @spec resolve(Stats.t() | Combatant.t(), target(), keyword()) :: [decision()]
  def resolve(wearer, target, opts \\ [])
      when is_struct(wearer, Stats) or is_struct(wearer, Combatant) do
    rng = Keyword.get(opts, :rng, @default_rng)

    decisions(
      wearer,
      equipment_modifier(wearer, :break_weapon_rate),
      equipment_modifier(wearer, :break_armor_rate),
      target,
      rng
    )
  end

  @doc """
  Resolves the target weapon and armor break rates alone, without the
  self-break. The rates are 1/10000 chances, as `resolve/3` derives them.
  """
  @spec resolve_rates(integer(), integer(), target(), keyword()) :: [decision()]
  def resolve_rates(weapon_rate, armor_rate, target, opts \\ []) do
    rng = Keyword.get(opts, :rng, @default_rng)
    target_decisions(weapon_rate, armor_rate, target, rng)
  end

  @doc """
  Resolves one target break attempt for `slot` at the supplied 1/10000 rate.

  Returns either the single target decision or an empty list, matching
  `resolve/3` so callers can dispatch decisions through the same pipeline.
  """
  @spec resolve_slot(integer(), target(), slot(), keyword()) :: [decision()]
  def resolve_slot(rate, target, slot, opts \\ [])
      when slot in [:weapon, :shield, :armor, :helm, :garment, :shoes] do
    rng = Keyword.get(opts, :rng, @default_rng)

    case target_slot(rate, target, slot, rng) do
      nil -> []
      decision -> [decision]
    end
  end

  @spec decisions(Stats.t() | Combatant.t(), integer(), integer(), target(), rng()) ::
          [decision()]
  defp decisions(wearer, weapon_rate, armor_rate, target, rng) do
    [self_weapon(wearer, rng) | target_decisions(weapon_rate, armor_rate, target, rng)]
    |> Enum.reject(&is_nil/1)
  end

  @spec target_decisions(integer(), integer(), target(), rng()) :: [decision()]
  defp target_decisions(weapon_rate, armor_rate, target, rng) do
    [
      target_slot(weapon_rate, target, :weapon, rng),
      target_slot(armor_rate, target, :armor, rng)
    ]
    |> Enum.reject(&is_nil/1)
  end

  @spec self_weapon(Stats.t() | Combatant.t(), rng()) :: {:self, :weapon} | nil
  defp self_weapon(wearer, rng) do
    rate = apply_stat_prevention(Config.natural_break_rate(), wearer, :weapon)

    if weapon_breakable?(wearer) and not slot_chemical_protected?(wearer_id(wearer), :weapon) and
         broke?(rate, rng),
       do: {:self, :weapon}
  end

  @spec wearer_id(Stats.t() | Combatant.t()) :: integer() | nil
  defp wearer_id(%Combatant{unit_id: id}), do: id
  defp wearer_id(%Stats{}), do: nil

  @spec target_slot(integer(), target(), slot(), rng()) :: {:target, slot()} | nil
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

  @spec apply_stat_prevention(integer(), Stats.t() | Combatant.t(), slot()) :: integer()
  defp apply_stat_prevention(rate, victim, slot) do
    if stat_slot_masked?(victim, slot) do
      0
    else
      apply_percentage_prevention(rate, victim)
    end
  end

  @spec apply_percentage_prevention(integer(), Stats.t() | Combatant.t()) :: integer()
  defp apply_percentage_prevention(rate, victim) do
    unbreakable = equipment_modifier(victim, :unbreakable)
    max(0, rate - div(rate * unbreakable, 100))
  end

  @spec slot_masked?({integer(), Stats.t()}, slot()) :: boolean()
  defp slot_masked?({victim_id, victim}, slot) do
    stat_slot_masked?(victim, slot) or slot_chemical_protected?(victim_id, slot)
  end

  @spec slot_chemical_protected?(integer() | nil, slot()) :: boolean()
  defp slot_chemical_protected?(nil, _slot), do: false

  defp slot_chemical_protected?(victim_id, slot) do
    case Map.get(@chemical_protection, slot) do
      nil -> false
      status -> StatusStorage.has_status?(:player, victim_id, status)
    end
  end

  @spec stat_slot_masked?(Stats.t() | Combatant.t(), slot()) :: boolean()
  defp stat_slot_masked?(victim, slot) do
    victim
    |> equipment_modifier(Map.fetch!(@unbreakable_modifiers, slot))
    |> Kernel.>(0)
  end

  @spec slot_breakable?(slot(), Stats.t()) :: boolean()
  defp slot_breakable?(:weapon, victim), do: weapon_breakable?(victim)
  defp slot_breakable?(_slot, _victim), do: true

  @spec weapon_breakable?(Stats.t() | Combatant.t()) :: boolean()
  defp weapon_breakable?(%Stats{equipment: equipment}) do
    Stats.weapon_type(equipment) not in @weapon_break_immune_types
  end

  defp weapon_breakable?(%Combatant{weapon: %{type: type}}),
    do: type not in @weapon_break_immune_types

  @spec equipment_modifier(Stats.t() | Combatant.t(), atom()) :: integer()
  defp equipment_modifier(%Stats{} = wearer, key),
    do: Stats.get_equipment_modifier(wearer, key)

  defp equipment_modifier(%Combatant{equip_modifiers: modifiers}, key),
    do: Map.get(modifiers, key, 0)

  @spec broke?(integer(), rng()) :: boolean()
  defp broke?(rate, _rng) when rate <= 0, do: false
  defp broke?(rate, rng), do: rng.(10_000) <= rate
end
