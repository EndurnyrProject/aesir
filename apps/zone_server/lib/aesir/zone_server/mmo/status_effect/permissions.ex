defmodule Aesir.ZoneServer.Mmo.StatusEffect.Permissions do
  @moduledoc """
  What a unit's held statuses let it do: move, attack, cast, use items, sit,
  stand, chat, change equipment, be targeted.

  Most answers are a property check over every held status
  (`Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker`); the player rules with
  entry-dependent exceptions (Hiding with Tunnel Drive, a performance lock and
  Longing, a channelled Gravitation Field) are spelled out here.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type unit_type :: Unit.unit_type()

  @doc "Returns whether the unit has an active status indexed for `flag`."
  @spec has_active_flag?(unit_type(), integer(), atom()) :: boolean()
  def has_active_flag?(unit_type, unit_id, flag) do
    flag
    |> Registry.statuses_with_flag()
    |> Enum.any?(&StatusStorage.has_status?(unit_type, unit_id, &1))
  end

  @doc """
  Returns whether a unit may move, i.e. carries no `prevents_movement` status.

  Players have two entry-dependent rules: Hiding allows movement with Tunnel
  Drive, and a performance lock's root is entry-dependent. Longing frees
  ordinary ensemble performers, but not always-rooted Moonlit or Hermode.
  """
  @spec can_move?(unit_type(), integer()) :: boolean()
  def can_move?(:player, unit_id) do
    :player
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(&(not blocks_player_movement?(&1, unit_id)))
  end

  def can_move?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &PropertyChecker.prevents_movement?/1)

  @doc """
  Returns whether a unit may attack. Longing relaxes an ensemble performing
  lock, but other `prevents_attack` statuses still block attacks.
  """
  @spec can_attack?(unit_type(), integer()) :: boolean()
  def can_attack?(:player, unit_id) do
    :player
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(&(not blocks_player_attack?(&1, unit_id)))
  end

  def can_attack?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &PropertyChecker.prevents_attack?/1)

  @doc """
  Returns whether an active status blocks equipping `slot`.
  """
  @spec equip_blocked?(unit_type(), integer(), slot :: atom()) :: boolean()
  def equip_blocked?(unit_type, unit_id, slot) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.any?(fn %StatusEntry{type: type} ->
      match?(%{metadata: %{strip_slot: ^slot}}, Registry.get_definition(type))
    end)
  end

  @doc """
  Returns whether a unit may use skills, i.e. carries no `prevents_skills` status.
  """
  @spec can_use_skill?(unit_type(), integer()) :: boolean()
  def can_use_skill?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &PropertyChecker.prevents_skills?/1)

  @doc "Returns whether a unit may use items while status effects are active."
  @spec can_use_item?(unit_type(), integer()) :: boolean()
  def can_use_item?(unit_type, unit_id),
    do:
      not restricted?(unit_type, unit_id, &PropertyChecker.prevents_items?/1) and
        not channeling_gravitation?(unit_type, unit_id)

  @gravitation_skill 484

  @doc """
  Whether a skill hit by `unit_type`/`unit_id` may be calculated at all.

  A pre-renewal player channelling their own Gravitation Field deals no other
  skill damage while the field lasts: only Gravitation Field itself and a skill
  running with the caster's autocast flag set (`autocast?`, an equipment proc)
  get through. Field occupants, monsters, renewal casters and ordinary attacks
  are never gated. The check belongs before any damage calculation; a refused
  hit is not a cast failure, so its costs stay spent.
  """
  @spec can_deal_skill_damage?(unit_type(), integer(), integer(), boolean()) :: boolean()
  def can_deal_skill_damage?(:player, unit_id, skill_id, autocast?) do
    autocast? or skill_id == @gravitation_skill or GameMode.mode() != :pre_renewal or
      not channeling_gravitation?(:player, unit_id)
  end

  def can_deal_skill_damage?(_unit_type, _unit_id, _skill_id, _autocast?), do: true

  @doc """
  `can_deal_skill_damage?/4` for an attacking combatant, read with its live
  autocast flag in the calling process: `:ok` to calculate the hit, `:suppressed`
  to skip it entirely. Every attack calculation entry calls it right after the
  delivery check.
  """
  @spec authorize_skill_damage(
          %{:unit_type => unit_type(), :unit_id => integer(), optional(atom()) => any()},
          integer()
        ) :: :ok | :suppressed
  def authorize_skill_damage(%{unit_type: type, unit_id: id}, skill_id) do
    if can_deal_skill_damage?(type, id, skill_id, Origin.autocast?({type, id})),
      do: :ok,
      else: :suppressed
  end

  # A pre-renewal Gravitation Field caster cannot use items; its field occupants can.
  defp channeling_gravitation?(unit_type, unit_id) do
    match?(
      %StatusEntry{state: %{self?: true}},
      StatusStorage.get_status(unit_type, unit_id, :sc_gravitation)
    )
  end

  @doc """
  Returns whether a player may sit down: no locking body state (see
  `can_stand?/1`), no performance, and not channelling a Gravitation Field.
  """
  @spec can_sit?(integer()) :: boolean()
  def can_sit?(unit_id) do
    can_stand?(unit_id) and
      not match?(%StatusEntry{}, StatusStorage.get_status(:player, unit_id, :sc_dancing)) and
      not channeling_gravitation?(:player, unit_id)
  end

  @doc """
  Returns whether a player may stand up: no body state (stone, freeze, stun,
  sleep) holds them. The petrification wait phase does not.
  """
  @spec can_stand?(integer()) :: boolean()
  def can_stand?(unit_id) do
    :player
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(&(not locking_body_state?(&1)))
  end

  defp locking_body_state?(%StatusEntry{type: type}) do
    case Registry.get_definition(type) do
      nil -> false
      definition -> definition[:opt1] not in [nil, :stonewait, :burning]
    end
  end

  @lose_target_statuses [:sc_bladestop, :sc_cursedcircle_target, :sc__manhole]

  @doc """
  Returns whether a monster's statuses make it drop its target and pending
  attacked event: a body state other than the petrification wait or burning,
  or a status that loses the target (Blade Stop, Cursed Circle, Manhole).
  """
  @spec loses_target?(unit_type(), integer()) :: boolean()
  def loses_target?(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.any?(&(locking_body_state?(&1) or &1.type in @lose_target_statuses))
  end

  @doc "Returns whether a unit may send area chat while status effects are active."
  @spec can_chat?(unit_type(), integer()) :: boolean()
  def can_chat?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &PropertyChecker.prevents_chat?/1)

  @doc "Returns whether active statuses block equipment changes."
  @spec equip_change_blocked?(unit_type(), integer()) :: boolean()
  def equip_change_blocked?(unit_type, unit_id),
    do: restricted?(unit_type, unit_id, &PropertyChecker.prevents_equip_change?/1)

  @doc """
  Returns whether a unit may cast a specific skill.

  A status' `:blocked_skills` always denies its listed skills. Otherwise, a
  `prevents_skills` status does not block a skill it lists in `:allow_skills`.
  This lets a feigning-death player recast NV_TRICKDEAD to stand back up even
  though SC_TRICKDEAD prevents skills. A hidden player may use only a skill
  usable while hidden, and the Auto Counter stance allows no skill at all.

  `item?` marks a player's skill cast from an item: casting locks (Silence and
  the other statuses that forbid starting a cast) and skill blocks do not stop
  it, while a stun-like body state, playing dead, Blade Stop, a performance,
  the caster's own Battle Chant, Hiding and Auto Counter still do.
  """
  @spec can_use_skill?(unit_type(), integer(), integer(), boolean()) :: boolean()
  def can_use_skill?(unit_type, unit_id, skill_id, item? \\ false) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(fn %StatusEntry{type: type} = entry ->
      (item? and not item_skill_lock?(entry)) or
        (skill_id not in PropertyChecker.blocked_skills(type) and
           skill_allowed?(entry, unit_type, unit_id, skill_id))
    end)
  end

  @item_skill_locks [
    :sc_trickdead,
    :sc_bladestop,
    :sc_dancing,
    :sc_gospel,
    :sc_hiding,
    :sc_auto_counter
  ]

  defp item_skill_lock?(%StatusEntry{type: type} = entry),
    do: type in @item_skill_locks or locking_body_state?(entry)

  @doc """
  Whether a performing unit's lock lets it use `skill_id`, as `can_use_skill?/3`
  judges it. A unit that is not performing is never locked.
  """
  @spec performance_allows_skill?(unit_type(), integer(), integer()) :: boolean()
  def performance_allows_skill?(unit_type, unit_id, skill_id) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_dancing) do
      %StatusEntry{} = entry -> skill_allowed?(entry, unit_type, unit_id, skill_id)
      _none -> true
    end
  end

  @doc "True when an active status prevents ally-targeted support skills."
  @spec support_blocked?(unit_type(), integer()) :: boolean()
  def support_blocked?(unit_type, unit_id),
    do:
      restricted?(
        unit_type,
        unit_id,
        &PropertyChecker.has_property?(&1, :prevents_support_skills)
      )

  @doc """
  Returns whether a unit may be targeted, i.e. carries no `untargetable` status.
  """
  @spec targetable?(unit_type(), integer()) :: boolean()
  def targetable?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &PropertyChecker.untargetable?/1)

  @doc """
  Returns whether a unit is charmed against the candidate target.
  """
  @spec charmed_against?(unit_type(), integer(), integer()) :: boolean()
  def charmed_against?(unit_type, unit_id, target_id) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_winkcharm) do
      %StatusEntry{source_id: ^target_id} -> true
      _entry -> false
    end
  end

  defp blocks_player_movement?(%StatusEntry{type: :sc_hiding}, unit_id),
    do: not tunnel_drive?(unit_id)

  defp blocks_player_movement?(%StatusEntry{type: :sc_dancing} = entry, unit_id) do
    case root(entry) do
      :always -> true
      :ensemble -> not longing?(unit_id)
      :none -> false
    end
  end

  defp blocks_player_movement?(%StatusEntry{type: :sc_gravitation, state: state}, _unit_id),
    do: match?(%{self?: true}, state)

  defp blocks_player_movement?(%StatusEntry{type: type}, _unit_id),
    do: PropertyChecker.prevents_movement?(type)

  defp blocks_player_attack?(%StatusEntry{type: :sc_dancing} = entry, unit_id),
    do: root(entry) == :none or not longing?(unit_id)

  defp blocks_player_attack?(%StatusEntry{type: type}, _unit_id),
    do: PropertyChecker.prevents_attack?(type)

  defp root(%StatusEntry{state: state, val4: partner_id}),
    do:
      Map.get(state, :root) ||
        if(is_integer(partner_id) and partner_id > 0, do: :ensemble, else: :none)

  defp longing?(unit_id), do: StatusStorage.has_status?(:player, unit_id, :sc_longing)

  defp skill_allowed?(%StatusEntry{type: :sc_dancing} = entry, :player, unit_id, skill_id) do
    allowed =
      if root(entry) != :none and longing?(unit_id),
        do: skill_id != 305 and not Catalog.replayable?(skill_id),
        else: skill_id in PropertyChecker.allowed_skills(:sc_dancing)

    allowed and not hermode_adaptation?(entry, skill_id)
  end

  defp skill_allowed?(%StatusEntry{type: :sc_auto_counter}, _unit_type, _unit_id, _skill_id),
    do: false

  defp skill_allowed?(%StatusEntry{type: :sc_winkcharm}, unit_type, _unit_id, _skill_id)
       when unit_type != :player,
       do: false

  defp skill_allowed?(%StatusEntry{type: :sc_hiding}, :player, _unit_id, skill_id),
    do: match?({:ok, %{allow_when_hidden: true}}, Catalog.by_id(skill_id))

  defp skill_allowed?(%StatusEntry{type: type}, _unit_type, _unit_id, skill_id),
    do:
      not PropertyChecker.prevents_skills?(type) or
        skill_id in PropertyChecker.allowed_skills(type)

  # Classic Adaptation cannot end a Wand of Hermode performance.
  defp hermode_adaptation?(%StatusEntry{val1: performance}, skill_id),
    do: GameMode.mode() == :pre_renewal and performance == 488 and skill_id == 304

  defp tunnel_drive?(unit_id) do
    case UnitRegistry.get_unit(:player, unit_id) do
      {:ok, {PlayerState, player, _pid}} -> Passives.hidden_move_speed(player) > 0
      _ -> false
    end
  end

  defp restricted?(unit_type, unit_id, pred) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.any?(fn %StatusEntry{type: type} -> pred.(type) end)
  end
end
