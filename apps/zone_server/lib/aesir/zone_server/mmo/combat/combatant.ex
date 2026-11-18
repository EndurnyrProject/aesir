defmodule Aesir.ZoneServer.Mmo.Combat.Combatant do
  @moduledoc """
  The unit snapshot every combat calculation reads: identity and relationship
  roots, base and combat stats, element/race/size, weapon hands and the
  precomputed passive levels.

  Each unit module builds one with `to_combatant/1` (`PlayerState`, `MobState`,
  `HomunculusState`, `Npc.SkillCaster`, skill-unit cells), so attackers and
  defenders of any type pass through the same functions:

      attacker = PlayerState.to_combatant(player_state)
      defender = MobState.to_combatant(mob_state)
      DamageCalculator.calculate_damage(attacker, defender)
  """

  use TypedStruct

  import Bitwise

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats

  @typedoc "A combatant's unit type."
  @type unit_type :: :player | :mob | :npc | :homunculus | :skill_unit

  @typedoc """
  Standardized combatant structure containing all data needed for combat calculations.

  Fields are organized into logical groups:
  - Identity: unit_id, unit_type, social_root, reward_root
  - Stats: base_stats, combat_stats (physical atk/def plus magic matk/mdef/soft_mdef), progression
  - Combat modifiers: element, race, size, weapon
  - Timing: attack_range, attack_delay_ms
  - Positioning: position, map_name

  `arrow_element` is the unpromoted ammo element, used only by ammo-using hits.
  Bows and guns promote their ammo element into `weapon.element` instead.

  `combat_stats.soft_def` is required for `:mob` combatants; it is optional for
  other unit types.
  """
  typedstruct do
    field :unit_id, integer(), enforce: true
    field :unit_type, unit_type(), enforce: true
    field :social_root, Ref.t()
    field :reward_root, {:player, pos_integer()}
    field :party_id, non_neg_integer(), default: 0
    field :guild_id, non_neg_integer(), default: 0

    field :base_stats, BaseStats.t(), enforce: true
    field :combat_stats, CombatStats.t(), enforce: true

    field :max_hp, non_neg_integer()
    field :max_sp, non_neg_integer()

    # Current HP, carried only by skill-unit cells (their durability), so
    # enemy targeting can refuse a spent cell. Other units keep theirs in state.
    field :hp, non_neg_integer()
    field :progression, %{base_level: integer(), job_level: integer()}, enforce: true
    field :element, tuple() | atom(), enforce: true

    # Secondary race groups apply only to mobs; players and homunculi use [].
    field :race, atom(), enforce: true
    field :race2, [atom()], default: []
    field :size, atom(), enforce: true
    field :weapon, %{type: atom(), element: atom(), size: atom()}, enforce: true
    field :ammo_atk, non_neg_integer(), default: 0
    field :arrow_element, atom()
    field :right_hand, WeaponHand.t()
    field :left_hand, WeaponHand.t()
    field :attack_range, integer(), enforce: true

    # Attack cadence in milliseconds: the delay the combat loop uses to gate
    # attacks. Sent to the client as ZC_NOTIFY_ACT src_speed so the swing
    # animation duration matches real attack speed.
    field :attack_delay_ms, integer(), enforce: true

    # The attack animation length in milliseconds (status amotion): half the
    # attack delay for a player, the whole delay for a Homunculus, the
    # monster's own attack motion for a monster.
    field :amotion, non_neg_integer()

    field :position, {integer(), integer()}
    field :map_name, String.t()

    # Passive skill levels precomputed at combatant-build time (0 for mobs).
    field :divine_protection_level, integer(), default: 0
    field :demon_bane_level, integer(), default: 0
    field :beast_bane_level, integer(), default: 0
    field :dragonology_level, integer(), default: 0
    field :advanced_katar_level, integer(), default: 0
    field :faith_level, integer(), default: 0
    field :skin_temper_level, integer(), default: 0
    # Learned levels that extend flagged skill ranges (0 for non-players).
    field :vulture_eye_level, non_neg_integer(), default: 0
    field :snake_eye_level, non_neg_integer(), default: 0

    # Monster class for the class-keyed bonuses and rules. Players are always
    # :normal; a mob's class is derived from its modes (`MobMode.class/1`).
    field :class, MobMode.class(), default: :normal

    # Existing status-immunity mode projected for pure combat policies.
    field :status_immune, boolean(), default: false

    # Detector mode (insect/demon detectors and every boss-class monster), which
    # sees through Hiding and Cloaking. Only monsters carry it.
    field :detector, boolean(), default: false

    # The monster's infinite-defense modes; see `infinite_defense?/2`.
    field :ignore_modes, [ignore_mode()], default: []

    # Monster database id (mob class), set only for mob defenders. Keys the
    # per-monster physical damage bonus (add_damage_class); nil for players.
    field :monster_id, integer()

    # The player whose equipment procs answer for this attacker's hits. Set for
    # a player-owned monster summon (its owner), nil otherwise.
    field :proc_owner_id, integer()

    # Whether the attacker is mounted (Peco-Peco). Feeds the mounted-spear
    # size-modifier override; always false for mobs.
    field :riding, boolean(), default: false

    # Folded equipment bonus map (players: `stats.modifiers.equipment`;
    # mobs: empty, since mobs carry no equipment).
    field :equip_modifiers, map(), default: %{}
    field :magic_reduction, 0..100, default: 0

    # Current derived equipment autobonus registrations. Non-player combatants
    # have no equipment, so they retain the safe empty default.
    field :equip_autobonuses, %{Stats.autobonus_key() => Stats.autobonus_registration()},
      default: %{}

    # Spirit spheres a player held when the combatant was built (0 for others).
    field :spirit_spheres, non_neg_integer(), default: 0
  end

  @typedoc "A monster mode that turns every matching hit into a 1-damage contact."
  @type ignore_mode :: :ignore_melee | :ignore_magic | :ignore_ranged | :ignore_misc

  @ignore_modes [:ignore_melee, :ignore_magic, :ignore_ranged, :ignore_misc]
  @weapon_short BattleFlags.type_bit(:weapon) ||| BattleFlags.range_bit(:short)
  @weapon_long BattleFlags.type_bit(:weapon) ||| BattleFlags.range_bit(:long)
  @magic BattleFlags.type_bit(:magic)
  @misc BattleFlags.type_bit(:misc)

  @doc "The monster modes that grant infinite defense."
  @spec ignore_modes() :: [ignore_mode()]
  def ignore_modes, do: @ignore_modes

  @doc """
  Whether `defender` takes a hit described by the battle flag `attack_flag` as
  an infinite-defense contact: melee weapon hits against `:ignore_melee`, any
  magic against `:ignore_magic`, ranged weapon hits against `:ignore_ranged`,
  any misc hit against `:ignore_misc`. The invincibility status and the
  infinite-defense skill units that also grant it are not implemented.
  """
  @spec infinite_defense?(t(), BattleFlags.flag()) :: boolean()
  def infinite_defense?(%__MODULE__{ignore_modes: modes}, attack_flag)
      when is_integer(attack_flag) do
    (:ignore_melee in modes and (attack_flag &&& @weapon_short) == @weapon_short) or
      (:ignore_magic in modes and (attack_flag &&& @magic) != 0) or
      (:ignore_ranged in modes and (attack_flag &&& @weapon_long) == @weapon_long) or
      (:ignore_misc in modes and (attack_flag &&& @misc) != 0)
  end

  @doc """
  Builds a combatant, defaulting the relationship roots of a player, mob or
  NPC from its unit id and rejecting roots that do not fit its unit type (a
  homunculus must carry its owner's player roots).
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    combatant = attrs |> with_roots() |> then(&struct(__MODULE__, &1))

    if valid_roots?(combatant) do
      {:ok, combatant}
    else
      {:error, "Invalid combatant relationship roots"}
    end
  rescue
    e in ArgumentError ->
      {:error, "Invalid combatant data: #{Exception.message(e)}"}
  end

  @doc """
  Creates a new combatant struct, raising on invalid data.
  """
  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, combatant} -> combatant
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Checks if this combatant is a mob.
  """
  @spec mob?(t()) :: boolean()
  def mob?(%__MODULE__{unit_type: :mob}), do: true
  def mob?(_), do: false

  defp with_roots(%{unit_type: :player, unit_id: unit_id} = attrs) do
    attrs
    |> Map.put_new(:social_root, {:player, unit_id})
    |> Map.put_new(:reward_root, {:player, unit_id})
  end

  defp with_roots(%{unit_type: :mob, unit_id: unit_id} = attrs) do
    attrs
    |> Map.put_new(:social_root, {:mob, unit_id})
    |> Map.put_new(:reward_root, nil)
  end

  defp with_roots(%{unit_type: :npc, unit_id: unit_id} = attrs) do
    attrs
    |> Map.put_new(:social_root, {:npc, unit_id})
    |> Map.put_new(:reward_root, nil)
  end

  defp with_roots(attrs), do: attrs

  defp valid_roots?(%__MODULE__{
         unit_type: :player,
         unit_id: unit_id,
         social_root: {:player, unit_id},
         reward_root: {:player, unit_id}
       })
       when is_integer(unit_id) and unit_id > 0,
       do: true

  defp valid_roots?(%__MODULE__{
         unit_type: :mob,
         unit_id: unit_id,
         social_root: {:mob, unit_id},
         reward_root: nil
       })
       when is_integer(unit_id) and unit_id > 0,
       do: true

  defp valid_roots?(%__MODULE__{
         unit_type: :npc,
         unit_id: unit_id,
         social_root: {:npc, unit_id},
         reward_root: nil
       })
       when is_integer(unit_id) and unit_id > 0,
       do: true

  defp valid_roots?(%__MODULE__{
         unit_type: :homunculus,
         unit_id: unit_id,
         social_root: {:player, owner_id},
         reward_root: {:player, owner_id}
       })
       when is_integer(unit_id) and unit_id > 0 and is_integer(owner_id) and owner_id > 0,
       do: true

  defp valid_roots?(%__MODULE__{unit_type: :skill_unit}), do: true
  defp valid_roots?(%__MODULE__{}), do: false
end
