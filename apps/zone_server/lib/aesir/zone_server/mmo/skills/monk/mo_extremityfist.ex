defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoExtremityfist do
  @moduledoc """
  Asura Strike (MO_EXTREMITYFIST), the Monk's finisher.

  Every fallible check runs before any irreversible effect: the target, its
  range, the caster's Fury requirement, the spirit-point and sphere costs, and
  the three-cell relocation destination are all resolved first, so a rejected
  cast spends nothing and moves no one. The blow's power scales with the
  caster's spirit energy - damage is read from the pre-drain spirit-point pool,
  dealt once, and only afterward are the spheres and the entire pool consumed
  (by the skill interpreter's cost commitment), Fury, Root and the combo window
  ended, the recovery penalty applied, and the prevalidated relocation staged
  for the session to apply after commitment.

  Three cast contexts change only the sphere requirement and how the cast is
  reached; the caster must hold Fury in every one:

    * a normal cast spends five spheres;
    * a Root follow-up against the caught peer spends four;
    * a combo follow-up off Raging Thrust's window spends every held sphere (at
      least one) and casts instantly.

  The three-cell relocation is a rider on the strike, not a precondition: an
  unwalkable destination lands the blow and simply stages no movement.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 271,
    name: :mo_extremityfist,
    # Player-coupled at runtime (character_id + spirit spheres), but not on the pre-migration
    # mob denylist. Kept mob-selectable with [] to preserve exact pre-migration behaviour; a
    # mob caster falls through to the {:error, :invalid_target} clause as it does today.
    requires: [],
    status: :sc_extremityfist,
    display_name: "Asura Strike",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    element: :neutral,
    sp_cost: [1, 1, 1, 1, 1],
    sphere_cost: [5, 5, 5, 5, 5],
    cast_time: [2_000, 1_750, 1_500, 1_250, 1_000],
    fixed_cast_time: [2_000, 1_750, 1_500, 1_250, 1_000],
    after_cast_delay: [3_000, 2_500, 2_000, 1_500, 1_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @behaviour Active

  @skill_id 271
  @move_cells 3
  @fury :sc_explosionspirits
  @recovery :sc_extremityfist

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%{character_id: caster_id} = caster, {:unit, _target_id}, _level, definition) do
    with :ok <- Root.check_cast(:player, caster_id, definition.id) do
      cond do
        not fury_active?(caster_id) -> {:error, :requires_explosion_spirits}
        caster.stats.current_state.sp < Formulas.asura_sp_cost() -> {:error, :insufficient_sp}
        true -> :ok
      end
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec dynamic_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(
        %{spirit_spheres: spheres, stats: %{current_state: %{sp: sp}}} = caster,
        {:unit, target_id},
        _level,
        _definition
      ) do
    %Cost{
      sp: sp,
      spheres:
        Formulas.asura_sphere_cost(context(caster, target_id), SpiritSpheres.count(spheres))
    }
  end

  @impl Active
  @spec dynamic_cast_time(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          %{cast_time: non_neg_integer(), fixed_cast_time: non_neg_integer()}
  def dynamic_cast_time(caster, {:unit, target_id}, level, definition) do
    case context(caster, target_id) do
      :combo ->
        %{cast_time: 0, fixed_cast_time: 0}

      _context ->
        %{
          cast_time: Enum.at(definition.cast_time, level - 1, 0),
          fixed_cast_time: Enum.at(definition.fixed_cast_time, level - 1, 0)
        }
    end
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with {:ok, _type, {target_x, target_y, _map}} <- Combat.resolve_target_position(target_id),
         :ok <- deal_damage(caster, target_id, level, definition) do
      :ok = StatusInterpreter.remove_status(:player, caster_id, @fury)
      :ok = Root.close(:player, caster_id)
      :ok = apply_recovery(caster_id, level)

      {:ok,
       caster
       |> Map.update!(:combo, &Combo.cancel/1)
       |> stage_movement(target_x, target_y)}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  # Damage reads the pre-drain spirit-point pool: the interpreter applies the
  # all-SP cost commitment only after this behaviour returns.
  defp deal_damage(caster, target_id, level, definition) do
    %{skill_ratio: skill_ratio, bonus_atk: bonus_atk} =
      Formulas.asura_damage_components(level, caster.stats.current_state.sp)

    Combat.execute_skill_attack(caster, target_id,
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio,
      bonus_atk: bonus_atk,
      element: :neutral,
      hit_count: 1,
      skip_crit: true
    )
  end

  # Stages the relocation only when its destination cell is valid; an unwalkable
  # destination is not a cast failure, it just leaves the Monk in place.
  defp stage_movement(caster, target_x, target_y) do
    case destination(caster, target_x, target_y) do
      {:ok, directive} -> PlayerState.put_pending_forced_movement(caster, directive)
      {:error, _reason} -> caster
    end
  end

  # The Monk relocates three cells toward the target along each axis.
  defp destination(caster, target_x, target_y) do
    dx = @move_cells * axis_step(target_x - caster.x)
    dy = @move_cells * axis_step(target_y - caster.y)
    ForcedMovement.validate(caster, caster.x + dx, caster.y + dy, @move_cells)
  end

  defp axis_step(delta) when delta > 0, do: 1
  defp axis_step(delta) when delta < 0, do: -1
  defp axis_step(_delta), do: 0

  defp apply_recovery(caster_id, level) do
    StatusInterpreter.apply_status(:player, caster_id, @recovery,
      val1: level,
      caster_id: caster_id,
      duration: Formulas.asura_recovery_duration()
    )
  end

  # Root outranks the combo window, matching Renewal: a caught Monk resolves as a
  # Root follow-up before any lingering combo state is consulted.
  defp context(%{character_id: caster_id, combo: combo}, target_id) do
    case Combat.resolve_target_position(target_id) do
      {:ok, type, _position} ->
        target = {type, target_id}

        cond do
          Root.follow_up_allowed?(:player, caster_id, @skill_id, target) -> :root
          Combo.current?(combo, :extremity, target, now()) -> :combo
          true -> :normal
        end

      {:error, _reason} ->
        :normal
    end
  end

  defp fury_active?(caster_id) do
    case StatusStorage.get_status(:player, caster_id, @fury) do
      %{expires_at: nil} -> true
      %{expires_at: expires_at} when is_integer(expires_at) -> expires_at > now()
      _status -> false
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
end
