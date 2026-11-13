defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsFling do
  @moduledoc """
  Fling (GS_FLING).

  Throws coins at one enemy for misc damage equal to the caster's job level (a
  monster's base level) that cannot miss and ignores DEF and element. A landed
  hit starts Fling on the target with the coins thrown, lowering its DEF.

  The cast costs 5 coins; a player holding 1 to 4 throws what it holds, and the
  cast-begin check records that count for the status. An empty hand fails as a
  coin shortfall. A monster throws 5.

  Renewal and pre-renewal agree: 10 SP, 9 cells, Fling lasts 30 s.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 501,
    name: :gs_fling,
    requires: [],
    display_name: "Fling",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    ignore_element: true,
    ignore_flee: true,
    damage_kind: :misc,
    element: :weapon,
    range: 9,
    sp_cost: [10],
    sphere_cost: [5]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @duration_ms 30_000
  @mob_coins 5

  @doc """
  Resolves the cast's cost: a player holding fewer coins than required but at
  least one spends what it holds; an empty hand keeps the full requirement and
  fails it. The coin count is recorded for the status.
  """
  @impl Active
  @spec dynamic_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(caster, _target, level, definition) do
    cost =
      Cost.from_definition(caster, definition, level,
        sp: Cost.resolve_sp(caster, definition, level)
      )

    held = SpiritSpheres.count(caster.spirit_spheres)
    coins = if held > 0 and held < cost.spheres, do: held, else: cost.spheres
    %{cost | spheres: coins, spheres_old: coins}
  end

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      base_damage: base_damage(caster),
      report_hit: true
    ]

    case Combat.execute_misc_attack(caster, target, opts) do
      {:ok, %{hit?: true}} ->
        fling(caster, target)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp fling(caster, target) do
    {unit_type, unit_id} = target_ref(target)
    {source_type, source_id} = source_ref(caster)

    StatusInterpreter.apply_status(unit_type, unit_id, :sc_fling,
      val1: coins(caster),
      duration: @duration_ms,
      caster_id: source_id,
      source_type: source_type
    )
  end

  defp base_damage(%PlayerState{stats: %{progression: %{job_level: job_level}}}), do: job_level
  defp base_damage(%MobState{} = mob), do: MobState.get_level(mob)

  defp coins(%PlayerState{spirit_spheres_old: coins}), do: coins
  defp coins(_non_player), do: @mob_coins

  defp source_ref(%PlayerState{character_id: unit_id}), do: {:player, unit_id}
  defp source_ref(%MobState{instance_id: unit_id}), do: {:mob, unit_id}

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
