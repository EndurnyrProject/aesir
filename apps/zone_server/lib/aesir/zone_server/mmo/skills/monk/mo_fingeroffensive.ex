defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoFingeroffensive do
  @moduledoc """
  Throw Spirit Sphere (MO_FINGEROFFENSIVE).

  A five-hit physical strike that costs a single spirit sphere under the local
  default multi-hit configuration, usable against any enemy in range. It deals
  bonus damage when the target is the Monk's own linked Root peer, closing the
  pair after the volley lands, and briefly locks the Monk's own movement above
  level 1.

  Renewal: 600 plus 200 per level percent (half again against a rooted target)
  as one damage split into five hits for one sphere, 8 plus 4 per level SP, a
  0.5 s cast plus 0.5 s fixed, and a 1 s cooldown. Pre-renewal: 100 plus 50 per
  level percent repeated once per level, spending one sphere per level, 10 SP,
  a 1 s cast, and no cooldown. A classic Monk holding fewer spheres than the
  level still casts, spends every sphere held, and throws that many.

  The cast-begin check records the spheres the cast will spend; the strike's
  sphere bonus and classic throw count read that record plus the spheres left
  after paying. A restricted invocation (an item cast) records nothing and
  spends none, so it reads the record of the last ordinary cast.
  """

  @sp_costs Enum.map(
              1..5,
              &Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.throw_spirit_sphere_sp_cost/1
            )
  @timing Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.throw_spirit_sphere_timing()
  @sphere_cost Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.throw_spirit_sphere_cost()
  @hit_count Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.throw_spirit_sphere_hit_count()

  use Aesir.ZoneServer.Mmo.Skill,
    id: 267,
    name: :mo_fingeroffensive,
    cast_cancel: false,
    # Player-coupled at runtime (character_id), but accepted by the previous mob gate.
    # Kept mob-selectable with [] to preserve exact pre-migration behaviour; a mob caster
    # falls through to the {:error, :invalid_target} clause as it does today.
    requires: [],
    display_name: "Throw Spirit Sphere",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 9,
    hit_count: [renewal: @hit_count, pre_renewal: [1, 2, 3, 4, 5]],
    sp_cost: [renewal: @sp_costs, pre_renewal: List.duplicate(10, 5)],
    sphere_cost: [renewal: List.duplicate(@sphere_cost, 5), pre_renewal: [1, 2, 3, 4, 5]],
    cast_time: [
      renewal: List.duplicate(@timing.cast_time, 5),
      pre_renewal: List.duplicate(1_000, 5)
    ],
    fixed_cast_time: [renewal: List.duplicate(@timing.fixed_cast_time, 5), pre_renewal: []],
    after_cast_delay: List.duplicate(@timing.after_cast_delay, 5),
    cooldown: [renewal: List.duplicate(@timing.cooldown, 5), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @behaviour Active

  @doc """
  Resolves the cast's cost. A classic Monk holding at least one sphere but
  fewer than the level spends only the spheres held; an empty hand keeps the
  full requirement and fails validation. The sphere count spent is recorded
  for the strike.
  """
  @impl Active
  @spec dynamic_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(caster, _target, level, definition) do
    cost =
      Cost.from_definition(caster, definition, level,
        sp: Cost.resolve_sp(caster, definition, level)
      )

    held = held_spheres(caster)

    spheres = if held > 0 and held < cost.spheres, do: held, else: cost.spheres
    %{cost | spheres: spheres, spheres_old: spheres}
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with {:ok, target_type, _position} <- Combat.resolve_target_position(target_id) do
      attack(caster, caster_id, target_id, level, definition, target_type)
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp attack(caster, caster_id, target_id, level, definition, target_type) do
    with :ok <- Root.check_cast(:player, caster_id, definition.id),
         opts <- attack_opts(caster, definition, level, target_type, target_id),
         :ok <- Combat.execute_skill_attack(caster, target_id, opts) do
      if Root.rooted?(:player, caster_id), do: Root.close(:player, caster_id)

      updated =
        PlayerState.apply_walk_delay(
          caster,
          Formulas.throw_spirit_sphere_walk_delay(level),
          now()
        )

      {:ok, updated}
    end
  end

  defp attack_opts(caster, definition, level, target_type, target_id) do
    [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio:
        Formulas.throw_spirit_sphere_ratio(level, Root.rooted?(target_type, target_id)),
      skip_crit: true,
      skip_range: true
    ] ++ sphere_opts(caster, definition, level)
  end

  # Renewal adds the recorded spheres to those left for the sphere bonus.
  # Classic throws at most the recorded spheres plus those left, and its bonus
  # counts the throws plus the spheres left.
  defp sphere_opts(caster, definition, level) do
    declared = Definition.hit_count_at_level(definition, level)
    left = held_spheres(caster)
    recorded = Map.get(caster, :spirit_spheres_old, 0)

    case GameMode.mode() do
      :renewal ->
        [hit_divisions: declared, spirit_spheres: recorded + left]

      :pre_renewal ->
        throws = min(declared, recorded + left)
        [hit_divisions: throws, spirit_spheres: throws + left]
    end
  end

  defp held_spheres(%{spirit_spheres: %SpiritSpheres{} = spheres}),
    do: SpiritSpheres.count(spheres)

  defp held_spheres(_caster), do: 0

  defp now, do: System.monotonic_time(:millisecond)
end
