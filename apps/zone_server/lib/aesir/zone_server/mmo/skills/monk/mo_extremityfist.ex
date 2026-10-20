defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoExtremityfist do
  @moduledoc """
  Asura Strike (MO_EXTREMITYFIST), the Monk's finisher.

  Every fallible check runs before any irreversible effect: the target, its
  range, the caster's Fury requirement, the spirit-point and sphere costs, and
  the three-cell relocation destination are all resolved first, so a rejected
  cast spends nothing and moves no one. The cast pays its 1 SP and spheres
  first; the blow's power then scales with the SP left, it is dealt once, and
  only afterward is the rest of the pool emptied, Fury, Root and the combo
  window ended, the recovery penalty applied, and the prevalidated relocation
  staged for the session to apply after commitment. The sphere bonus counts
  the spheres held when the cast began (a Root follow-up records none and reads
  the previous cast's count).

  Four cast contexts change only the sphere requirement and how the cast is
  reached; the caster must hold Fury in every one:

    * a normal cast spends five spheres;
    * a Root follow-up against the caught peer spends four;
    * a combo follow-up off Raging Thrust's window casts instantly and spends
      every held sphere (at least one) in renewal, four in pre-renewal;
    * a Champion follow-up off Chain Crush Combo's window casts instantly and
      spends every held sphere (at least one) in both modes.

  The three-cell relocation is a rider on the strike, not a precondition: an
  unwalkable destination lands the blow and simply stages no movement.

  The blow always connects - a high-flee or perfect-dodge target cannot evade
  it - and its DEF reduction is a flat hard+soft subtraction rather than the
  renewal DEF curve.

  The strike is neutral element. Renewal: a 2 s cast plus 2 s fixed shrinking
  0.25 s per level, a second forced neutral attribute step after defense, a flat
  hard and soft DEF subtraction, a combo follow-up spends every held sphere, and
  the caster cannot regain SP for 3 s. Pre-renewal: a 4 s cast shrinking 0.5 s
  per level, the strike ignores DEF entirely, a follow-up after Raging Thrust spends four
  spheres, and SP regeneration stops for 5 minutes. Both drain all SP and deal
  800 plus ten times the SP left after the cost percent plus 250 plus 150 per
  level ATK; renewal doubles the percent when the cast began with more than
  five spheres.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 271,
    name: :mo_extremityfist,
    # Player-coupled at runtime (character_id + spirit spheres), but not on the pre-migration
    # previous mob refusal set. Kept mob-selectable with [] to preserve exact pre-migration behaviour; a
    # mob caster falls through to the {:error, :invalid_target} clause as it does today.
    requires: [],
    status: :sc_extremityfist,
    display_name: "Asura Strike",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    ignore_flee: true,
    range: -2,
    element: :neutral,
    sp_cost: [1, 1, 1, 1, 1],
    sphere_cost: [5, 5, 5, 5, 5],
    cast_time: [
      renewal: [2_000, 1_750, 1_500, 1_250, 1_000],
      pre_renewal: [4_000, 3_500, 3_000, 2_500, 2_000]
    ],
    fixed_cast_time: [renewal: [2_000, 1_750, 1_500, 1_250, 1_000], pre_renewal: []],
    after_cast_delay: [3_000, 2_500, 2_000, 1_500, 1_000]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Fury
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
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
        not Fury.active?(caster_id) -> {:error, :requires_explosion_spirits}
        caster.stats.current_state.sp < Formulas.asura_sp_cost() -> {:error, :insufficient_sp}
        true -> :ok
      end
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec dynamic_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(%{spirit_spheres: spheres} = caster, {:unit, target_id}, level, definition) do
    held = SpiritSpheres.count(spheres)
    context = context(caster, target_id)
    sp = Cost.resolve_sp(caster, definition, level)

    %Cost{
      sp_requirement: sp,
      sp: sp,
      spheres: Formulas.asura_sphere_cost(context, held),
      spheres_old: if(context == :root, do: nil, else: held)
    }
  end

  @impl Active
  @spec dynamic_cast_time(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          %{cast_time: non_neg_integer(), fixed_cast_time: non_neg_integer()}
  def dynamic_cast_time(caster, {:unit, target_id}, level, definition) do
    case context(caster, target_id) do
      combo when combo in [:combo, :chain_crush_combo] ->
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
       |> empty_sp()
       |> Map.update!(:combo, &Combo.cancel/1)
       |> stage_movement(target_x, target_y)}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @doc """
  A cast end refused by a cast-end check still spends the requirement (up to
  what is held), empties the SP, starts the recovery penalty, ends Fury and
  Root, and moves the Monk three cells toward a target still on the map,
  showing a zero-damage blow. It arms no cooldown and leaves no act delay. A
  Monk standing in a Fog Wall fails without any of it.
  """
  @impl Active
  @spec castend_failed(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | :none
  def castend_failed(%PlayerState{character_id: caster_id} = caster, target, level, definition) do
    if StatusStorage.has_status?(:player, caster_id, :sc_fogwall) do
      :none
    else
      paid = pay_requirement(caster, target, level, definition)
      :ok = StatusInterpreter.remove_status(:player, caster_id, @fury)
      :ok = Root.close(:player, caster_id)
      :ok = apply_recovery(caster_id, level)
      {:ok, paid |> empty_sp() |> Map.put(:act_delay_until, 0) |> lunge(target, level)}
    end
  end

  def castend_failed(_caster, _target, _level, _definition), do: :none

  defp pay_requirement(caster, {:unit, _target_id} = target, level, definition) do
    cost = dynamic_cost(caster, target, level, definition)
    Cost.apply_commitment(caster, Cost.prepare_clamped(caster, cost))
  end

  defp pay_requirement(caster, _target, _level, _definition), do: caster

  defp lunge(%{map_name: map} = caster, {:unit, target_id}, level) do
    case Combat.resolve_target_position(target_id) do
      {:ok, _type, {target_x, target_y, ^map}} ->
        show_failed_blow(caster, target_id, level)
        stage_movement(caster, target_x, target_y)

      _elsewhere ->
        caster
    end
  end

  defp lunge(caster, _target, _level), do: caster

  defp show_failed_blow(%{map_name: map, x: x, y: y} = caster, target_id, level) do
    packet =
      caster.character_id
      |> PacketFactory.build_splash_damage_packet(target_id, @skill_id, level, 0)
      |> Map.put(:src_delay, AttackSpeed.amotion_from_stats(caster.stats))

    Broadcast.to_in_range(map, x, y, Config.view_range(), packet)
  end

  # Damage reads the SP left once the cost is paid, before the pool is emptied.
  defp deal_damage(caster, target_id, level, definition) do
    spheres_old = Map.get(caster, :spirit_spheres_old, 0)

    %{skill_ratio: skill_ratio, bonus_atk: bonus_atk} =
      Formulas.asura_damage_components(level, caster.stats.current_state.sp, spheres_old)

    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio,
      bonus_atk: bonus_atk,
      skip_crit: true,
      ignore_flee: true,
      spirit_spheres: spheres_old
    ]

    Combat.execute_skill_attack(caster, target_id, mode_opts() ++ opts)
  end

  defp empty_sp(%{stats: %{current_state: current} = stats} = caster),
    do: %{caster | stats: %{stats | current_state: %{current | sp: 0}}}

  defp mode_opts do
    case GameMode.mode() do
      :renewal -> [element: :neutral, simple_defense: true]
      :pre_renewal -> [element: :neutral, ignore_defense: true]
    end
  end

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
          Combo.current?(combo, :chain_crush, target, now()) -> :chain_crush_combo
          true -> :normal
        end

      {:error, _reason} ->
        :normal
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
end
