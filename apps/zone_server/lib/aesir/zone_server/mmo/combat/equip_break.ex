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
  unit identity: `{:player, character_id, stats}`. Legacy resolve entry points
  ignore non-player targets. `resolve_hit/3` additionally supports typed
  non-player strip decisions with explicit attacker/source/wearer ownership.

  Garment and shoes are valid `resolve_slot/4` targets and honor the matching
  `unbreakable_*` prevention flag, but no natural weapon hit ever rolls them:
  in Renewal only weapon, armor, shield and helm break, so `resolve/3` never
  emits a garment or shoes decision. They also have no Chemical Protection
  counterpart, so their protection lookup yields none.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats

  @type slot :: :weapon | :shield | :armor | :helm | :garment | :shoes
  @typedoc "A player item break or a non-player strip to dispatch after a hit."
  @type decision ::
          {:self, :weapon}
          | {:target, slot()}
          | {:strip, atom(), non_neg_integer(), pos_integer()}

  @typedoc "The original status owner, dispatched source, and optional equipment wearer."
  @type hit_context :: %{
          attacker: {atom(), integer()},
          source: {atom(), integer()},
          wearer: Stats.t() | Combatant.t() | nil
        }

  @typedoc "A player with prevention stats or a non-player status-capable recipient."
  @type hit_target :: {:player, integer(), Stats.t()} | {:unit, atom(), integer()}
  @type target :: {:player, integer(), Stats.t()} | {atom(), term()}
  @type rng :: (pos_integer() -> pos_integer())
  @type context :: %{wearer: Stats.t() | Combatant.t(), attacker: {atom(), integer()} | nil}

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
  @overthrust_bonus 10

  @doc """
  Resolves natural self-weapon break and target weapon/armor break rates for a
  confirmed weapon hit.

  The target rates come from the wearer's equipment; the self-break uses the
  configured natural rate plus the pre-renewal Over Thrust terms of the
  **attacking unit's** status container (which stays the summon's for a summon's
  hit), and the wearer's own weapon, prevention and Chemical Protection
  (Weapon). A bare wearer is its own attacking unit.
  """
  @spec resolve(context() | Stats.t() | Combatant.t(), target(), keyword()) :: [decision()]
  def resolve(wearer_or_context, target, opts \\ [])

  def resolve(%{wearer: wearer, attacker: attacker}, target, opts) do
    rng = Keyword.get(opts, :rng, @default_rng)

    decisions(
      wearer,
      self_break_bonus(attacker),
      equipment_modifier(wearer, :break_weapon_rate),
      equipment_modifier(wearer, :break_armor_rate),
      target,
      rng
    )
  end

  def resolve(wearer, target, opts)
      when is_struct(wearer, Stats) or is_struct(wearer, Combatant) do
    resolve(%{wearer: wearer, attacker: unit_ref(wearer)}, target, opts)
  end

  @doc """
  Resolves a connected, surviving weapon hit's self and target break decisions.

  The original attacker supplies held Meltdown rates and classic Over Thrust
  additions. The optional wearer supplies equipment rates and self prevention.
  The dispatched source independently needs Meltdown to strip non-player targets.
  Skill ids 337 and 485 exclude target attempts, never preceding self attempts.
  No mutation or session dispatch occurs here. `:rng` retains the 1..10,000 draw.
  """
  @spec resolve_hit(hit_context(), hit_target(), keyword()) :: [decision()]
  def resolve_hit(%{attacker: attacker, source: source, wearer: wearer}, target, opts \\ []) do
    rng = Keyword.get(opts, :rng, @default_rng)
    self_decisions = hit_self_decisions(wearer, attacker, rng)

    if Keyword.get(opts, :skill_id) in [337, 485] do
      self_decisions
    else
      {weapon_bonus, armor_bonus} = meltdown_rates(attacker)
      weapon_rate = equipment_modifier(wearer, :break_weapon_rate) + weapon_bonus
      armor_rate = equipment_modifier(wearer, :break_armor_rate) + armor_bonus
      self_decisions ++ hit_target_decisions(weapon_rate, armor_rate, source, target, rng)
    end
  end

  defp hit_self_decisions(nil, _attacker, _rng), do: []

  defp hit_self_decisions(wearer, attacker, rng),
    do: List.wrap(self_weapon(wearer, self_break_bonus(attacker), rng))

  defp meltdown_rates({type, id}) do
    case StatusStorage.get_status(type, id, :sc_meltdown) do
      nil -> {0, 0}
      entry -> {entry.val2, entry.val3}
    end
  end

  defp hit_target_decisions(weapon_rate, armor_rate, _source, {:player, _, _} = target, rng),
    do: target_decisions(weapon_rate, armor_rate, target, rng)

  defp hit_target_decisions(
         weapon_rate,
         armor_rate,
         {source_type, source_id},
         {:unit, type, id},
         rng
       ) do
    if StatusStorage.has_status?(source_type, source_id, :sc_meltdown) do
      for {rate, protection, strip, val2} <- [
            {weapon_rate, :sc_cp_weapon, :sc_stripweapon, 25},
            {armor_rate, :sc_cp_armor, :sc_striparmor, 40}
          ],
          rate > 0,
          not StatusStorage.has_status?(type, id, protection),
          broke?(rate, rng),
          do: {:strip, strip, val2, 75_000}
    else
      []
    end
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

  @spec decisions(Stats.t() | Combatant.t(), integer(), integer(), integer(), target(), rng()) ::
          [decision()]
  defp decisions(wearer, self_bonus, weapon_rate, armor_rate, target, rng) do
    [
      self_weapon(wearer, self_bonus, rng)
      | target_decisions(weapon_rate, armor_rate, target, rng)
    ]
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

  @spec self_weapon(Stats.t() | Combatant.t(), integer(), rng()) :: {:self, :weapon} | nil
  defp self_weapon(wearer, self_bonus, rng) do
    rate = apply_stat_prevention(Config.natural_break_rate() + self_bonus, wearer, :weapon)

    if weapon_breakable?(wearer) and not slot_chemical_protected?(wearer_id(wearer), :weapon) and
         broke?(rate, rng),
       do: {:self, :weapon}
  end

  # Pre-renewal only: each held Over Thrust status adds 10 to the natural rate.
  # The statuses are read from the attacking unit's container, which stays the
  # summon's for a summon's hit, so a master's Over Thrust never leaks into its
  # summon's self break.
  @spec self_break_bonus({atom(), integer()} | nil) :: non_neg_integer()
  defp self_break_bonus({unit_type, unit_id}) when is_integer(unit_id) do
    if GameMode.mode() == :pre_renewal do
      [:sc_overthrust, :sc_maxoverthrust]
      |> Enum.count(&StatusStorage.has_status?(unit_type, unit_id, &1))
      |> Kernel.*(@overthrust_bonus)
    else
      0
    end
  end

  defp self_break_bonus(_attacker), do: 0

  @spec unit_ref(Stats.t() | Combatant.t()) :: {atom(), integer()} | nil
  defp unit_ref(%Combatant{unit_type: type, unit_id: id}), do: {type, id}
  defp unit_ref(%Stats{}), do: nil

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
    Stats.weapon_type(equipment) not in @weapon_break_immune_types and
      Stats.weapon_type(%{equipment | right_hand: equipment.left_hand}) != :one_handed_axe
  end

  defp weapon_breakable?(%Combatant{left_hand: %{subtype: :one_handed_axe}}), do: false

  defp weapon_breakable?(%Combatant{weapon: %{type: type}}),
    do: type not in @weapon_break_immune_types

  @spec equipment_modifier(Stats.t() | Combatant.t() | nil, atom()) :: integer()
  defp equipment_modifier(nil, _key), do: 0

  defp equipment_modifier(%Stats{} = wearer, key),
    do: Stats.get_equipment_modifier(wearer, key)

  defp equipment_modifier(%Combatant{equip_modifiers: modifiers}, key),
    do: Map.get(modifiers, key, 0)

  @spec broke?(integer(), rng()) :: boolean()
  defp broke?(rate, _rng) when rate <= 0, do: false
  defp broke?(rate, rng), do: rng.(10_000) <= rate
end
