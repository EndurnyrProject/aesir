defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgBackstap do
  @moduledoc """
  Back Stab (RG_BACKSTAP), a rear melee attack that breaks the caster's Hiding.

  Both modes deal 300 plus 40 per level percent (a bow halves the part above
  the base 100) for 16 SP with a 0.5 s delay. Renewal: no rear requirement,
  the caster first slips to the cell behind the target (a cell it cannot reach
  fails the skill), the hit is rolled normally, a
  dagger repeats the one calculated damage over two hits, a 5 plus 2 per level
  percent 4.5 s stun lands on hit, and a
  0.5 s cooldown applies. Pre-renewal: the caster must already stand behind the
  target, the hit never misses, and there is no stun or cooldown. Turning the
  target and the renewal flat HIT bonus are not modelled.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 212,
    name: :rg_backstap,
    requires: [],
    display_name: "Back Stab",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    ignore_flee: [renewal: false, pre_renewal: true],
    range: 1,
    hit_count: 1,
    sp_cost: List.duplicate(16, 10),
    after_cast_delay: List.duplicate(500, 10),
    cooldown: [renewal: List.duplicate(500, 10), pre_renewal: []],
    allow_when_hidden: [renewal: false, pre_renewal: true]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_ref}, level, definition) do
    with {:ok, _pid, target, target_type} <- TargetResolver.resolve(target_ref),
         {:ok, destination} <- approach(caster, target) do
      break_hiding(caster)
      {attacker, moved} = slip(caster, destination)

      opts =
        mode_opts() ++
          [
            skill_id: definition.id,
            skill_level: level,
            skill_ratio: backstab_ratio(caster, level),
            hit_divisions: hit_divisions(caster, definition, level),
            skip_range: true,
            report_hit: true
          ]

      strike(attacker, moved, target_type, target_ref, level, opts)
    end
  end

  defp strike(attacker, moved, target_type, target_ref, level, opts) do
    case Combat.execute_skill_attack(attacker, target_ref, opts) do
      {:ok, %{hit?: true}} ->
        if GameMode.mode() == :renewal, do: apply_stun(attacker, target_type, target_ref, level)
        {:ok, moved}

      {:ok, _no_effect} ->
        {:ok, moved}

      {:error, _reason} = error ->
        error
    end
  end

  defp approach(caster, target) do
    case GameMode.mode() do
      :renewal ->
        slip_destination(caster, target)

      :pre_renewal ->
        if Geometry.behind?(caster, target), do: {:ok, nil}, else: {:error, :must_be_behind}
    end
  end

  defp mode_opts do
    case GameMode.mode() do
      :renewal -> []
      :pre_renewal -> [ignore_flee: true]
    end
  end

  # A renewal dagger repeats the one calculated damage twice.
  defp hit_divisions(caster, definition, level) do
    if GameMode.mode() == :renewal and weapon_type(caster) == :dagger,
      do: 2,
      else: Definition.hit_count_at_level(definition, level)
  end

  defp break_hiding(%PlayerState{character_id: caster_id}),
    do: StatusInterpreter.remove_status(:player, caster_id, :sc_hiding)

  defp break_hiding(_caster), do: :ok

  # Renewal moves the caster to the cell one step beyond the target, along the
  # direction from the caster to it, before the attack. The cell must be
  # walkable and reachable in a straight line; otherwise the skill fails.
  defp slip_destination(%{map_name: map_name, x: x, y: y}, %{x: target_x, y: target_y})
       when is_binary(map_name) do
    {dx, dy} = beyond_step(target_x - x, target_y - y)
    destination = {target_x + dx, target_y + dy}

    if Cell.traversable?(map_name, target_x + dx, target_y + dy) and
         LineOfSight.passable?(map_name, {x, y}, destination),
       do: {:ok, destination},
       else: {:error, :invalid_destination}
  end

  defp slip_destination(_caster, _target), do: {:error, :invalid_destination}

  # The attack comes from the slipped cell. A player moves when the cast
  # commits; a monster requests its own relocation.
  defp slip(caster, nil), do: {caster, caster}

  defp slip(%PlayerState{} = caster, {x, y}) do
    directive = %ForcedMovement{map_name: caster.map_name, x: x, y: y}
    {%{caster | x: x, y: y}, PlayerState.put_pending_forced_movement(caster, directive)}
  end

  defp slip(%MobState{instance_id: id} = caster, {x, y}) do
    _ = Knockback.relocate(:mob, id, x, y)
    {%{caster | x: x, y: y}, caster}
  end

  # The unit step of the 8-way direction of `{dx, dy}`, quadrant by quadrant:
  # straight along an axis about three times the other, diagonal otherwise.
  # Toward the east an exact 3:1 counts as straight horizontally and diagonal
  # vertically; toward the west, the reverse. A caster on the target's own cell
  # steps east.
  defp beyond_step(dx, dy) do
    cond do
      dx == 0 and dy == 0 -> {1, 0}
      dx >= 0 and dy >= 0 -> pick(dx >= dy * 3, dx * 3 < dy, {1, 0}, {0, 1}, {1, 1})
      dx >= 0 -> pick(dx >= -dy * 3, dx * 3 < -dy, {1, 0}, {0, -1}, {1, -1})
      dy <= 0 -> pick(dx * 3 >= dy, dx < dy * 3, {0, -1}, {-1, 0}, {-1, -1})
      true -> pick(-dx * 3 <= dy, -dx > dy * 3, {0, 1}, {-1, 0}, {-1, 1})
    end
  end

  defp pick(true, _second?, first, _second, _diagonal), do: first
  defp pick(false, true, _first, second, _diagonal), do: second
  defp pick(false, false, _first, _second, diagonal), do: diagonal

  @doc """
  Returns Back Stab's weapon ratio: the base 100 plus 200 plus 40 per level,
  with a bow halving the skill's own part.
  """
  @spec backstab_ratio(PlayerState.t() | MobState.t(), pos_integer()) :: pos_integer()
  def backstab_ratio(caster, level) do
    bonus = 200 + 40 * level
    100 + if weapon_type(caster) == :bow, do: div(bonus, 2), else: bonus
  end

  defp weapon_type(%PlayerState{stats: %{equipment: equipment}}),
    do: Stats.weapon_type(equipment)

  defp weapon_type(_caster), do: nil

  defp apply_stun(caster, target_type, target_ref, level) do
    {source_type, caster_id} = caster_ref(caster)

    _ =
      StatusInterpreter.apply_status(target_type, unit_id(target_ref), :sc_stun,
        duration: 4_500,
        success_rate: 5 + 2 * level,
        caster_id: caster_id,
        source_type: source_type
      )

    :ok
  end

  defp caster_ref(%PlayerState{character_id: caster_id}), do: {:player, caster_id}
  defp caster_ref(%MobState{instance_id: caster_id}), do: {:mob, caster_id}

  defp unit_id({_unit_type, unit_id}), do: unit_id
  defp unit_id(unit_id), do: unit_id
end
