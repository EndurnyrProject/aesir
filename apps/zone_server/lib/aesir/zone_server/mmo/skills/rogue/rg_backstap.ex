defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgBackstap do
  @moduledoc """
  Back Stab (RG_BACKSTAP), a rear melee attack that breaks the caster's Hiding.

  Both modes deal 200 plus 40 per level percent, halved with a bow, for 16 SP
  with a 0.5 s delay. Renewal: no rear requirement, the caster slips to the cell
  behind the target, the hit is rolled normally, a dagger doubles the damage and
  shows two hits, a 5 plus 2 per level percent 4.5 s stun lands on hit, and a
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
    range: 1,
    hit_count: 1,
    sp_cost: List.duplicate(16, 10),
    after_cast_delay: List.duplicate(500, 10),
    cooldown: [renewal: List.duplicate(500, 10), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_ref}, level, definition) do
    with {:ok, _pid, target, target_type} <- TargetResolver.resolve(target_ref),
         :ok <- approach(caster, target) do
      break_hiding(caster)

      opts =
        mode_opts(caster) ++
          [
            skill_id: definition.id,
            skill_level: level,
            skill_ratio: strike_ratio(caster, level),
            hit_count: 1,
            skip_range: true,
            report_hit: true
          ]

      strike(caster, target, target_type, target_ref, level, opts)
    end
  end

  defp strike(caster, target, target_type, target_ref, level, opts) do
    case Combat.execute_skill_attack(caster, target_ref, opts) do
      {:ok, %{hit?: true}} ->
        if GameMode.mode() == :renewal, do: apply_stun(caster, target_type, target_ref, level)
        {:ok, slip_behind(caster, target)}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp approach(caster, target) do
    case GameMode.mode() do
      :renewal ->
        :ok

      :pre_renewal ->
        if Geometry.behind?(caster, target), do: :ok, else: {:error, :must_be_behind}
    end
  end

  defp mode_opts(caster) do
    case GameMode.mode() do
      :renewal ->
        if weapon_type(caster) == :dagger,
          do: [display_hit_count: 2],
          else: [display_hit_count: 1]

      :pre_renewal ->
        [display_hit_count: 1, ignore_flee: true]
    end
  end

  defp strike_ratio(caster, level) do
    ratio = backstab_ratio(caster, level)

    if GameMode.mode() == :renewal and weapon_type(caster) == :dagger,
      do: ratio * 2,
      else: ratio
  end

  defp break_hiding(%PlayerState{character_id: caster_id}),
    do: StatusInterpreter.remove_status(:player, caster_id, :sc_hiding)

  defp break_hiding(_caster), do: :ok

  defp slip_behind(%PlayerState{map_name: map_name} = caster, %{x: target_x, y: target_y})
       when is_binary(map_name) do
    if GameMode.mode() == :renewal do
      dx = axis_step(target_x - caster.x)
      dy = axis_step(target_y - caster.y)

      case ForcedMovement.validate(caster, target_x + dx, target_y + dy, 2) do
        {:ok, directive} -> PlayerState.put_pending_forced_movement(caster, directive)
        {:error, _reason} -> caster
      end
    else
      caster
    end
  end

  defp slip_behind(caster, _target), do: caster

  defp axis_step(delta), do: delta |> max(-1) |> min(1)

  @doc "Returns Back Stab's weapon ratio: 200 plus 40 per level, halved with a bow."
  @spec backstab_ratio(PlayerState.t() | MobState.t(), pos_integer()) :: pos_integer()
  def backstab_ratio(caster, level) do
    ratio = 200 + 40 * level
    if weapon_type(caster) == :bow, do: div(ratio, 2), else: ratio
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
