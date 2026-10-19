defmodule Aesir.ZoneServer.Mmo.Skill.Targeting do
  @moduledoc """
  Shared target relations for skills and combat.

  Existing callers may keep passing player and mob state maps. New relationship
  callers use typed combatants and unit references.

  Versus hostility is resolved in `validate_enemy/2`; a homunculus whose owner
  has vanished from the unit registry is treated as unaffiliated (party/guild
  0) for that single check.
  """

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.Relationship
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Concealment
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc """
  Where a skill's use on a target is checked: when the cast begins, when its
  cast bar completes, for a splash or ground-unit recipient after the skill went
  off, and when a ground unit is placed over the target.
  """
  @type skill_use_phase :: :cast_begin | :cast_end | :splash | :unit_place

  @typedoc """
  A unit checked for concealment: a combatant, or just its identity plus, for a
  caster, its boss `:class` and `:detector` mode (both default to neither).
  """
  @type concealment_unit ::
          Combatant.t()
          | %{
              required(:unit_type) => atom(),
              required(:unit_id) => term(),
              optional(:class) => MobMode.class(),
              optional(:detector) => boolean()
            }

  @typedoc """
  How a skill hit reached its recipient, deciding whether the hit re-checks the
  recipient's skill use (`validate_delivery/4`):

    * `:direct` - the caster's own unanimated hit (a single-target strike, an
      unanimated splash, a song): never re-checked.
    * `:unit` - the actual source is a placed ground unit or trap: every
      recipient is checked against the caster.
    * `{:splash, primary}` - an animated splash: every recipient but `primary`
      is checked against the caster when the skill has the Splash damage flag
      and is not an NPC skill.
    * `{:area, primary}` - an area attack resolved recipient by recipient: every
      recipient but `primary` is checked without a caster, and additionally
      against the caster when the skill has the Splash damage flag and keeps
      its splash animation.
  """
  @type delivery :: :direct | :unit | {:splash, Ref.t() | nil} | {:area, Ref.t() | nil}

  @pressure 367
  @lex_aeterna 78
  @lex_divina 76
  @trick_dead 143
  @adaptation 304
  @gospel 369
  @chase_walk 389
  @freeze_immune_skills [88, 89]
  @frost_nova 88
  @free_body_states [0, 6, 7]

  @field_skills %{
    92 => :wz_quagmire,
    115 => :ht_skidtrap,
    116 => :ht_landmine,
    117 => :ht_anklesnare,
    118 => :ht_shockwave,
    119 => :ht_sandman,
    120 => :ht_flasher,
    121 => :ht_freezingtrap,
    122 => :ht_blastmine,
    123 => :ht_claymoretrap,
    229 => :am_demonstration,
    369 => :pa_gospel
  }

  @doc """
  Validates that `target` is a living enemy of `attacker` that can be targeted:
  an invincible player cannot (`Unit.Player.Invincibility`).
  """
  @spec validate_enemy(map(), map()) :: :ok | {:error, atom()}
  def validate_enemy(attacker, target) do
    if alive?(target) and Invincibility.active?(target),
      do: {:error, :target_invincible},
      else: validate_enemy_relation(attacker, target)
  end

  @doc """
  Validates that `target` is a living enemy of `attacker`, invincible or not.

  For a skill's checks when its cast begins: an attack skill aimed at an
  invincible player still starts, and fails when it completes
  (`castend_refused?/2`).
  """
  @spec validate_enemy_relation(map(), map()) :: :ok | {:error, atom()}
  def validate_enemy_relation(attacker, target) do
    if alive?(target) do
      attacker_combatant = relationship_combatant(attacker)
      target_combatant = relationship_combatant(target)
      versus = versus_context(target_combatant.map_name)

      if Relationship.enemy?(
           enrich_homunculus(attacker_combatant, versus),
           enrich_homunculus(target_combatant, versus),
           versus
         ) do
        Rules.validate_target(attacker_combatant, target_combatant, %{skill_id: nil})
      else
        {:error, :invalid_target}
      end
    else
      {:error, :target_dead}
    end
  end

  @doc """
  Validates a target selected and delivered by a supported player-owned field.

  The source group must identify the actual player caster, map, and one of the
  finite Quagmire, Demonstration, or Hunter trap skills. Those fields may reach
  normally protected player-side targets only while PvP or GvG is active; PvE
  and off-hours maps retain ordinary enemy targeting. The field's concrete
  skill identity is always checked by siege objective rules.
  """
  @spec validate_field_target(Group.t(), map(), map()) :: :ok | {:error, atom()}
  def validate_field_target(%Group{} = group, attacker, target) do
    cond do
      not alive?(target) -> {:error, :target_dead}
      Invincibility.active?(target) -> {:error, :target_invincible}
      true -> validate_live_field_target(group, attacker, target)
    end
  end

  defp validate_live_field_target(group, attacker, target) do
    attacker = relationship_combatant(attacker)
    target = relationship_combatant(target)

    with :ok <- validate_field_source(group, attacker),
         :ok <- validate_field_target_map(group, target),
         :ok <- validate_field_self(group, target),
         :ok <- validate_field_status(group, target),
         :ok <- validate_field_relationship(group, attacker, target) do
      Rules.validate_target(attacker, target, %{skill_id: group.skill_id})
    end
  end

  @doc "Checks status-based immunity to a ground unit, independently of its owner."
  @spec validate_field_status(Group.t(), map()) :: :ok | {:error, :target_trap_immune}
  def validate_field_status(%Group{skill_id: skill_id}, target) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> validate_trap_status(definition, target)
      :error -> :ok
    end
  end

  defp validate_trap_status(%Definition{is_trap: true}, target) do
    case StatusStorage.get_status(unit_type(target), unit_id(target), :sc_sightblaster) do
      %{state: state} ->
        if Map.get(state || %{}, :trap_immunity, true),
          do: {:error, :target_trap_immune},
          else: :ok

      _unprotected ->
        :ok
    end
  end

  defp validate_trap_status(_definition, _target), do: :ok

  @doc "Returns whether two typed combatants are enemies on a PvE map."
  @spec enemy?(Combatant.t(), Combatant.t()) :: boolean()
  defdelegate enemy?(attacker, target), to: Relationship

  @doc "Returns whether a player may directly support the exact owned Homunculus."
  @spec direct_support?(Combatant.t() | map(), Combatant.t() | map()) :: boolean()
  def direct_support?(%Combatant{} = caster, %Combatant{} = target),
    do: Relationship.direct_support?(caster, target)

  def direct_support?(caster, target),
    do:
      Relationship.direct_support?(relationship_combatant(caster), relationship_combatant(target))

  @doc "Returns whether two unit snapshots share the exact social root."
  @spec exact_ally?(map(), map()) :: boolean()
  def exact_ally?(left, right) do
    left_root = left |> relationship_combatant() |> Relationship.social_root()
    right_root = right |> relationship_combatant() |> Relationship.social_root()
    Ref.equal?(left_root, right_root)
  end

  @doc "Returns whether an explicit ground selector chooses a typed unit reference."
  @spec ground_selected?(Relationship.ground_selector(), Ref.t()) :: boolean()
  defdelegate ground_selected?(selector, target_ref), to: Relationship

  # Attack-type skills (the source's TargetType Attack) that Aesir models as
  # `:target_any` because they also accept allies.
  @attack_type_any [:pf_soulchange, :sa_dispell, :dc_winkcharm]

  # Support skills with the source's PartyOnly or GuildOnly flag (the same in
  # both modes): at cast end they check the target's relation, which refuses an
  # invincible player other than the caster.
  @party_or_guild_only_support [
    :as_enchantpoison,
    :am_potionpitcher,
    :cr_devotion,
    :sa_flamelauncher,
    :sa_frostweapon,
    :sa_lightningloader,
    :sa_seismicweapon,
    :cg_marionette,
    :mo_kitranslation
  ]

  @doc """
  Whether an attack-type skill aimed at a unit standing in Blinding Mist fails
  at cast end: three times in four. Support, self and ground skills, and targets
  outside the fog, never fail. `rng` is a `(100 -> 1..100)` roll.
  """
  @spec fogged_out?(term(), map(), (pos_integer() -> pos_integer())) :: boolean()
  def fogged_out?(target, definition, rng \\ &:rand.uniform/1)

  def fogged_out?({:unit, target_id}, %{target_type: type, name: name}, rng)
      when type == :target_enemy or name in @attack_type_any do
    case TargetResolver.resolve(target_id) do
      {:ok, _pid, _state, unit_type} ->
        StatusStorage.has_status?(unit_type, bare_id(target_id), :sc_fogwall) and rng.(100) <= 75

      _unresolved ->
        false
    end
  end

  def fogged_out?(_target, _definition, _rng), do: false

  defp bare_id({_type, id}), do: id
  defp bare_id(id), do: id

  @doc """
  Whether a skill completing on `target` fails because the target is an
  invincible player, for a `caster` that is not the target (see
  `castend_refused?/3`).
  """
  @spec castend_refused?(term(), map()) :: boolean()
  def castend_refused?(target, definition), do: castend_refused?(nil, target, definition)

  @doc """
  Whether a skill `caster` (a typed reference) completes on `target` fails
  because the target is an invincible player. Attack-type skills fail on one,
  though Lex Divina still reaches a silenced one. Party-only and guild-only
  support skills fail on one unless it is the caster. Every other support skill
  reaches it. Checked when the skill completes, never when its cast begins.
  """
  @spec castend_refused?(Ref.t() | nil, term(), map()) :: boolean()
  def castend_refused?(caster, {:unit, target_id}, %{target_type: type, name: name} = definition)
      when type == :target_enemy or name in @attack_type_any or
             name in @party_or_guild_only_support do
    case TargetResolver.resolve(target_id) do
      {:ok, _pid, state, :player} ->
        Invincibility.active?(state) and
          refused_on_invincible?(caster, definition, bare_id(target_id))

      _not_player ->
        false
    end
  end

  def castend_refused?(_caster, _target, _definition), do: false

  defp refused_on_invincible?(caster, %{name: name}, target_id)
       when name in @party_or_guild_only_support,
       do: caster != {:player, target_id}

  defp refused_on_invincible?(_caster, definition, target_id),
    do: not silenced_lex_divina?(definition, target_id)

  defp silenced_lex_divina?(%{id: @lex_divina}, id),
    do: StatusStorage.has_status?(:player, id, :sc_silence)

  defp silenced_lex_divina?(_definition, _id), do: false

  @doc "Returns whether `map` is a versus map (`MapFlags.versus?/1`)."
  @spec versus_map?(term()) :: boolean()
  def versus_map?(map_name) when is_binary(map_name), do: MapFlags.versus?(map_name)

  def versus_map?(_map_name), do: false

  @doc """
  Checks whether `caster`'s skill can reach `target` through its concealment.

  At cast begin Hiding, Cloaking and Chase Walk all conceal; at cast end and for
  a splash recipient only Hiding does. A TargetHidden skill reaches through
  Hiding, never through the others. A GM-invisible player is never reached. A
  boss or detector caster sees a concealed player; only a detector sees a
  concealed non-player. A `nil` caster (a ground skill checked without its
  caster) sees nothing concealed. Classic Pressure never reaches a hidden
  target after its cast begins. Unit placement checks only the target's Hiding
  against TargetHidden, whoever the caster is. A caster always reaches itself.

  A frozen target is out of Storm Gust's and Frost Nova's reach, as a frozen or
  petrified one is out of Lex Aeterna's, in every phase. At `:splash` the
  caster must also still be able to act (see `validate_delivery/4`). The
  classic Roki's Weil lock does not block the skill a player is casting from an
  item: that exemption holds only while the item cast itself executes, so a
  later timer delivery of the same skill is locked again.

  Relationship, life and range are other checks' concern.
  """
  @spec validate_skill_use(
          concealment_unit() | nil,
          concealment_unit(),
          Definition.t(),
          skill_use_phase()
        ) :: :ok | {:error, :caster_restricted | :target_restricted | :target_concealed}
  def validate_skill_use(_caster, target, %Definition{} = definition, :unit_place) do
    if hidden?(target_option(target)) and not definition.target_hidden,
      do: {:error, :target_concealed},
      else: :ok
  end

  def validate_skill_use(caster, target, %Definition{} = definition, phase) do
    option = target_option(target)

    cond do
      classic_pressure?(definition) and phase != :cast_begin and hidden?(option) ->
        {:error, :target_concealed}

      splash_check?(phase) and caster_restricted?(caster, definition, :splash) ->
        {:error, :caster_restricted}

      same_unit?(caster, target) ->
        :ok

      true ->
        reach_target(caster, target, option, definition, phase)
    end
  end

  defp reach_target(caster, target, option, definition, phase) do
    cond do
      target_restricted?(target, definition) ->
        {:error, :target_restricted}

      concealed?(caster, target, option, skill_mask(phase, definition)) ->
        {:error, :target_concealed}

      true ->
        :ok
    end
  end

  @doc """
  Checks the caster's own state when its timed cast completes; the target is
  `validate_skill_use/4`'s concern at `:cast_end`.

  A dead monster fails. Stun, freeze, sleep or petrification fails only a
  damage cast: support, self and ground casts still complete, and waiting to
  petrify fails nothing. Silence and the other statuses that only forbid
  starting a cast never fail it here. Playing dead, chanting Battle Chant, a
  Root lock, a performance that does not allow the skill, Hiding without a
  skill usable while hidden and Chase Walk fail it. Classic Roki's Weil fails
  it unless `item?` marks the caster's own item cast.
  """
  @spec validate_cast_completion(concealment_unit(), Definition.t(), boolean()) ::
          :ok | {:error, :caster_restricted}
  def validate_cast_completion(caster, %Definition{} = definition, item? \\ false) do
    if caster_restricted?(caster, definition, {:cast_end, item?}),
      do: {:error, :caster_restricted},
      else: :ok
  end

  @doc """
  Re-checks a skill hit's recipient according to how the hit reached it (see
  `t:delivery/0`), before any damage is calculated.

  A re-checked recipient goes through `validate_skill_use/4` at `:splash`,
  which also refuses a caster that cannot act (a dead monster; stunned, frozen,
  petrified or asleep; playing dead; chanting Battle Chant; Root-locked; under
  classic Loki's Veil; hidden without a skill usable while hidden; chase
  walking) and a frozen recipient of Storm Gust or Frost Nova. An unknown skill
  id is never re-checked.
  """
  @spec validate_delivery(
          concealment_unit(),
          concealment_unit(),
          integer() | Definition.t(),
          delivery()
        ) ::
          :ok
          | {:error,
             :caster_restricted | :target_restricted | :target_concealed | :target_trap_immune}
  def validate_delivery(_caster, _target, _skill, :direct), do: :ok

  def validate_delivery(caster, target, skill_id, delivery) when is_integer(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> validate_delivery(caster, target, definition, delivery)
      :error -> :ok
    end
  end

  def validate_delivery(caster, target, %Definition{} = definition, :unit) do
    with :ok <- validate_trap_status(definition, target),
         do: validate_skill_use(caster, target, definition, :splash)
  end

  def validate_delivery(caster, target, %Definition{} = definition, {:splash, primary}) do
    if primary?(target, primary) or definition.is_npc or not definition.damage_splash,
      do: :ok,
      else: validate_skill_use(caster, target, definition, :splash)
  end

  def validate_delivery(caster, target, %Definition{} = definition, {:area, primary}) do
    cond do
      primary?(target, primary) ->
        :ok

      definition.damage_splash and definition.id != @frost_nova ->
        with :ok <- validate_skill_use(nil, target, definition, :splash),
             do: validate_skill_use(caster, target, definition, :splash)

      true ->
        validate_skill_use(nil, target, definition, :splash)
    end
  end

  @doc """
  Whether a ground unit's on-enter effect (a field status, a web, a portal)
  reaches the unit `ref`. An invincible player is never reached. A Hiding unit
  is out of reach unless the skill is TargetHidden; only acquiring the effect
  is gated by Hiding, so a unit that already holds it keeps it while it hides.
  An unknown skill id reaches every other unit.
  """
  @spec placement_reaches?(integer() | Definition.t(), Ref.t()) :: boolean()
  def placement_reaches?(skill_id, ref) when is_integer(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> placement_reaches?(definition, ref)
      :error -> not Invincibility.active?(ref)
    end
  end

  def placement_reaches?(%Definition{} = definition, {unit_type, unit_id} = ref) do
    not Invincibility.active?(ref) and
      validate_skill_use(
        nil,
        %{unit_type: unit_type, unit_id: unit_id},
        definition,
        :unit_place
      ) == :ok
  end

  defp primary?(%{unit_type: type, unit_id: id}, {type, id}), do: true
  defp primary?(_target, _primary), do: false

  defp splash_check?(:splash), do: true
  defp splash_check?(_phase), do: false

  # The caster's own state at the source's recipient check (`:splash`) or at a
  # timed cast's completion (`{:cast_end, item?}`). A `nil` caster (an area
  # check made without one) carries no state.
  defp caster_restricted?(nil, _definition, _check), do: false

  defp caster_restricted?(%{unit_type: type, unit_id: id}, %Definition{} = definition, check) do
    %{body_state: body_state, effect_state: option} = caster_display(type, id)

    dead_non_player?(type, id) or body_locked?(body_state, definition, check) or
      status_locked?(type, id, definition, item_cast?(type, id, definition, check)) or
      performance_locked?(type, id, definition, check) or
      option_locked?(type, option, definition)
  end

  defp caster_restricted?(_caster, _definition, _check), do: false

  defp body_locked?(body_state, _definition, _check) when body_state in @free_body_states,
    do: false

  defp body_locked?(_body_state, definition, {:cast_end, _item?}), do: damage_cast?(definition)
  defp body_locked?(_body_state, _definition, :splash), do: true

  defp damage_cast?(%Definition{} = definition), do: Definition.cast_type(definition) == :damage

  defp performance_locked?(type, id, %Definition{id: skill_id}, {:cast_end, _item?}),
    do: not StatusInterpreter.performance_allows_skill?(type, id, skill_id)

  defp performance_locked?(_type, _id, _definition, :splash), do: false

  defp status_locked?(type, id, %Definition{id: skill_id}, item_cast?) do
    locked_by?(type, id, :sc_trickdead, skill_id, @trick_dead) or
      locked_by?(type, id, :sc_gospel, skill_id, @gospel) or
      not Root.skill_allowed?(type, id, skill_id) or
      (GameMode.mode() == :pre_renewal and not item_cast? and
         locked_by?(type, id, :sc_rokisweil, skill_id, @adaptation))
  end

  defp item_cast?(_type, _id, _definition, {:cast_end, item?}), do: item?

  defp item_cast?(type, id, %Definition{name: skill_name}, :splash) do
    match?(
      %{invocation: :item, skill: ^skill_name, caster: {^type, ^id}},
      Origin.current()
    )
  end

  defp locked_by?(type, id, status, skill_id, exempt_skill),
    do: skill_id != exempt_skill and StatusStorage.has_status?(type, id, status)

  defp option_locked?(type, option, %Definition{id: skill_id} = definition) do
    (type == :player and hidden?(option) and not definition.allow_when_hidden) or
      ((option &&& Option.id(:chasewalk)) != 0 and skill_id != @chase_walk)
  end

  defp caster_display(type, id) when type in [:player, :mob, :homunculus],
    do: StatusDisplay.spawn_state(type, id)

  defp caster_display(_type, _id), do: %{body_state: 0, effect_state: 0}

  defp dead_non_player?(:player, _id), do: false

  defp dead_non_player?(type, id) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, state, _pid}} -> not Unit.living?(state)
      _missing -> false
    end
  end

  defp target_restricted?(%{unit_type: type, unit_id: id}, %Definition{id: skill_id})
       when skill_id in @freeze_immune_skills,
       do: StatusStorage.has_status?(type, id, :sc_freeze)

  defp target_restricted?(%{unit_type: type, unit_id: id}, %Definition{id: @lex_aeterna}),
    do:
      StatusStorage.has_status?(type, id, :sc_freeze) or
        StatusStorage.has_status?(type, id, :sc_stone)

  defp target_restricted?(_target, _definition), do: false

  @doc """
  Whether an attacker's normal attack can see `target`: Hiding, Cloaking and
  Chase Walk conceal it from anything but a boss or detector, and a GM-invisible
  player from everything.
  """
  @spec attack_visible?(concealment_unit(), concealment_unit()) :: boolean()
  def attack_visible?(attacker, target),
    do: not concealed?(attacker, target, target_option(target), Concealment.conceal_mask())

  defp skill_mask(:cast_begin, definition),
    do: clear_hiding(Concealment.conceal_mask(), definition)

  defp skill_mask(_phase, definition), do: clear_hiding(Option.id(:hide), definition)

  defp clear_hiding(mask, %Definition{target_hidden: true}), do: mask &&& bnot(Option.id(:hide))
  defp clear_hiding(mask, _definition), do: mask

  # No equipment grants perfect hiding, so the source's
  # `perfect_hiding || !detector` is `!detector` here.
  defp concealed?(caster, %{unit_type: :player} = target, option, mask) do
    invisible?(target, option) or
      ((option &&& mask) != 0 and not boss?(caster) and not detector?(caster))
  end

  defp concealed?(caster, _target, option, mask),
    do: (option &&& mask) != 0 and not detector?(caster)

  defp hidden?(option), do: (option &&& Option.id(:hide)) != 0

  defp invisible?(%{unit_id: unit_id}, option) do
    base_option =
      case UnitRegistry.get_unit(:player, unit_id) do
        {:ok, {_module, %PlayerState{option: base}, _pid}} when is_integer(base) -> base
        _missing -> 0
      end

    ((option ||| base_option) &&& Option.id(:invisible)) != 0
  end

  defp target_option(%{unit_type: type, unit_id: id}) when type in [:player, :mob, :homunculus],
    do: StatusDisplay.spawn_state(type, id).effect_state

  defp target_option(_target), do: 0

  defp boss?(%{class: :boss}), do: true
  defp boss?(_caster), do: false

  defp detector?(%{detector: true}), do: true
  defp detector?(_caster), do: false

  defp same_unit?(%{unit_type: type, unit_id: id}, %{unit_type: type, unit_id: id}), do: true
  defp same_unit?(_caster, _target), do: false

  defp classic_pressure?(%Definition{id: @pressure}), do: GameMode.mode() == :pre_renewal
  defp classic_pressure?(_definition), do: false

  defp validate_field_source(
         %Group{
           caster_type: :player,
           caster_id: caster_id,
           map_name: map_name,
           skill_id: skill_id,
           skill_name: skill_name
         },
         %{unit_type: :player, unit_id: caster_id, map_name: map_name}
       )
       when is_binary(map_name) do
    case Map.fetch(@field_skills, skill_id) do
      {:ok, ^skill_name} when not is_nil(skill_name) -> :ok
      _mismatch -> {:error, :invalid_field_source}
    end
  end

  defp validate_field_source(%Group{}, _attacker), do: {:error, :invalid_field_source}

  defp validate_field_target_map(%Group{map_name: map_name}, %{map_name: map_name}), do: :ok
  defp validate_field_target_map(%Group{}, _target), do: {:error, :different_map}

  defp validate_field_self(
         %Group{caster_type: caster_type, caster_id: caster_id},
         %{unit_type: caster_type, unit_id: caster_id}
       ),
       do: {:error, :invalid_target}

  defp validate_field_self(%Group{}, _target), do: :ok

  defp validate_field_relationship(group, attacker, target) do
    if versus_map?(group.map_name), do: :ok, else: validate_enemy(attacker, target)
  end

  defp versus_context(map_name) when is_binary(map_name) do
    cond do
      MapFlags.gvg?(map_name) ->
        :gvg

      MapFlags.get(map_name, :pvp) ->
        {:pvp, MapFlags.get(map_name, :pvp_noparty), MapFlags.get(map_name, :pvp_noguild)}

      true ->
        :off
    end
  end

  defp versus_context(_map_name), do: :off

  defp relationship_combatant(unit) do
    attrs = %{
      unit_id: unit_id(unit),
      unit_type: unit_type(unit),
      party_id: Map.get(unit, :party_id, 0),
      guild_id: Map.get(unit, :guild_id, 0),
      map_name: Map.get(unit, :map_name),
      monster_id: Map.get(unit, :monster_id) || Map.get(unit, :mob_id)
    }

    unit
    |> relationship_roots(attrs)
    |> Combatant.new!()
  end

  defp enrich_homunculus(combatant, versus)

  defp enrich_homunculus(
         %Combatant{unit_type: :homunculus, social_root: {:player, owner_id}} = combatant,
         versus
       )
       when versus != :off do
    {party_id, guild_id} =
      case UnitRegistry.get_unit(:player, owner_id) do
        {:ok, {_module, owner_state, _pid}} ->
          {Map.get(owner_state, :party_id, 0), Map.get(owner_state, :guild_id, 0)}

        {:error, :not_found} ->
          {0, 0}
      end

    %{combatant | party_id: party_id, guild_id: guild_id}
  end

  defp enrich_homunculus(combatant, _versus), do: combatant

  defp relationship_roots(%{owner_character_id: owner_id}, attrs) do
    Map.merge(attrs, %{social_root: {:player, owner_id}, reward_root: {:player, owner_id}})
  end

  defp relationship_roots(unit, attrs) do
    case {Map.fetch(unit, :social_root), Map.fetch(unit, :reward_root)} do
      {{:ok, social_root}, {:ok, reward_root}} ->
        Map.merge(attrs, %{social_root: social_root, reward_root: reward_root})

      {:error, :error} ->
        attrs
    end
  end

  defp alive?(%{is_dead: true}), do: false
  defp alive?(%{action_state: :dead}), do: false
  defp alive?(%{hp: hp}) when hp <= 0, do: false
  defp alive?(%{stats: %{current_state: %{hp: hp}}}) when hp <= 0, do: false
  defp alive?(_target), do: true

  defp unit_type(%{unit_type: unit_type}), do: unit_type

  defp unit_type(%{owner_character_id: _owner_character_id, world_gid: _world_gid}),
    do: :homunculus

  defp unit_type(%{character_id: _character_id}), do: :player
  defp unit_type(%{instance_id: _instance_id}), do: :mob

  defp unit_id(%{unit_id: unit_id}), do: unit_id
  defp unit_id(%{owner_character_id: _owner_character_id, world_gid: world_gid}), do: world_gid
  defp unit_id(%{character_id: character_id}), do: character_id
  defp unit_id(%{instance_id: instance_id}), do: instance_id
end
