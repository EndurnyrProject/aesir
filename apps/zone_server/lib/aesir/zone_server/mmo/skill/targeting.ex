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
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Concealment
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
              optional(:class) => :normal | :boss,
              optional(:detector) => boolean()
            }

  @pressure 367

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

  @doc "Validates that `target` is a living enemy of `attacker`."
  @spec validate_enemy(map(), map()) :: :ok | {:error, atom()}
  def validate_enemy(attacker, target) do
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
    if alive?(target) do
      attacker = relationship_combatant(attacker)
      target = relationship_combatant(target)

      with :ok <- validate_field_source(group, attacker),
           :ok <- validate_field_target_map(group, target),
           :ok <- validate_field_self(group, target),
           :ok <- validate_field_relationship(group, attacker, target) do
        Rules.validate_target(attacker, target, %{skill_id: group.skill_id})
      end
    else
      {:error, :target_dead}
    end
  end

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

  @doc "Returns whether `map` is a versus map."
  @spec versus_map?(term()) :: boolean()
  def versus_map?(map_name) when is_binary(map_name),
    do: MapFlags.get(map_name, :pvp) or MapFlags.get(map_name, :gvg)

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

  Relationship, life and range are other checks' concern.
  """
  @spec validate_skill_use(
          concealment_unit() | nil,
          concealment_unit(),
          Definition.t(),
          skill_use_phase()
        ) :: :ok | {:error, :target_concealed}
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

      same_unit?(caster, target) ->
        :ok

      concealed?(caster, target, option, skill_mask(phase, definition)) ->
        {:error, :target_concealed}

      true ->
        :ok
    end
  end

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
      MapFlags.get(map_name, :gvg) ->
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
