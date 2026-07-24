defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross do
  @moduledoc """
  Grand Cross (CR_GRANDCROSS). Self-centered holy hybrid ground skill.

  The caster plants a holy cross field centered on their own cell (`Layout.cross/1`,
  9 cells) that ticks every 300 ms for roughly 900 ms (3 ticks). The cast costs
  20% of the caster's max HP plus SP, and refuses when current HP would not
  survive the deduction (resolved by `Skill.Cost` from `hp_cost_rate`). On a
  player cast the caster is rooted in place (`sc_grandcross_root`) for the field's
  lifetime so it stays centered on them.

  Each tick hits every offensive target standing on a cross cell - including the
  caster, via the `hits_caster` targeting exception - with the hybrid magic
  formula in `MagicDamageCalculator` (scoped by this skill's id): the mean of the
  caster's ATK and MATK, ratio `100 + 40*lv`, minus the target's MDEF, holy
  attribute fix twice. The caster's own cell takes half that damage (players) or
  none (mob casters, which are simply excluded from their own selection). Non-caster
  undead-element or undead/demon-race mob targets are blinded for 18 s at 100%.

  Mob casters carry no HP-rate/root cost machinery: `mob_cast` skips the player
  gates, and the field never damages the mob itself.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 254,
    name: :cr_grandcross,
    display_name: "Grand Cross",
    max_level: 10,
    target_type: :self,
    damage_type: :damage,
    damage_kind: :magic,
    element: :holy,
    range: 9,
    hit_interval: 300,
    unit_duration: List.duplicate(900, 10),
    hp_cost_rate: List.duplicate(20, 10),
    sp_cost: [37, 44, 51, 58, 65, 72, 79, 86, 93, 100],
    cast_time: List.duplicate(1_000, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Active
  @behaviour Ground

  @arm_length 2
  @blind_duration 18_000
  @blind_races [:undead, :demon]
  @root_duration 950
  @self_damage_scale 0.5

  @impl Active
  def cast(%{instance_id: id} = caster, {:unit, id}, level, definition),
    do: cast(caster, :self, level, definition)

  def cast(caster, :self, level, _definition) do
    case Unit.place(caster, :cr_grandcross, level, {caster.x, caster.y}) do
      {:ok, _group} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  @impl Ground
  def on_place(%Group{caster_type: :player, caster_id: caster_id} = group) do
    StatusInterpreter.apply_status(:player, caster_id, :sc_grandcross_root,
      duration: @root_duration
    )

    placement(group)
  end

  def on_place(%Group{} = group), do: placement(group)

  @impl Ground
  def on_interval(%Group{origin: origin, map_name: map_name, level: level} = group, _now) do
    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        caster_ref = {caster.unit_type, caster.unit_id}
        hits_caster? = Group.hits_caster?(group) and caster.unit_type == :player
        footprint = MapSet.new(group.cells)
        ratio = skill_ratio(level)

        map_name
        |> Combat.splash_targets(origin, @arm_length, caster, hits_caster?)
        |> Enum.filter(&on_footprint?(&1, footprint))
        |> Enum.each(fn {unit_type, target_id} = target_ref ->
          hit(caster, unit_type, target_id, level, ratio, target_ref == caster_ref)
        end)

        {:ok, group}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  defp placement(%Group{origin: origin, level: level}) do
    {ox, oy} = origin || {0, 0}
    cells = Enum.map(Layout.cross(@arm_length), fn {dx, dy} -> {ox + dx, oy + dy} end)
    definition = definition()

    {:ok,
     %{
       cells: cells,
       state: %{hits_caster: true},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1, 900),
       lifecycle_policy: %LifecyclePolicy{max_instances_per_caster: 1}
     }}
  end

  @spec hit(struct(), atom(), integer(), pos_integer(), pos_integer(), boolean()) :: :ok
  defp hit(caster, unit_type, target_id, level, ratio, self?) do
    Combat.apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      definition().id,
      level,
      :holy,
      ratio,
      damage_scale: if(self?, do: @self_damage_scale, else: 1)
    )

    unless self?, do: maybe_blind(unit_type, target_id)
    :ok
  end

  # rAthena renewal `CR_GRANDCROSS` ratio: base_skillratio (100) + 40 * skill_lv.
  @spec skill_ratio(pos_integer()) :: pos_integer()
  defp skill_ratio(level), do: 100 + 40 * level

  @spec on_footprint?({atom(), integer()}, MapSet.t()) :: boolean()
  defp on_footprint?({unit_type, target_id}, footprint) do
    case SpatialIndex.get_unit_position(unit_type, target_id) do
      {:ok, {x, y, _map_name}} -> MapSet.member?(footprint, {x, y})
      _ -> false
    end
  end

  # Blind lands only on mob targets that are undead-element or undead/demon-race;
  # players are never blinded by the field.
  @spec maybe_blind(atom(), integer()) :: :ok
  defp maybe_blind(:mob, target_id) do
    case Combat.resolve_combatant(:mob, target_id) do
      {:ok, %{race: race, element: element}} ->
        if race in @blind_races or undead_element?(element) do
          StatusInterpreter.apply_status(:mob, target_id, :sc_blind, duration: @blind_duration)
        end

        :ok

      _ ->
        :ok
    end
  end

  defp maybe_blind(_unit_type, _target_id), do: :ok

  defp undead_element?({:undead, _level}), do: true
  defp undead_element?(:undead), do: true
  defp undead_element?(_element), do: false
end
