defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaFrostjoker do
  @moduledoc "Frost Joker (BA_FROSTJOKER)."

  import Bitwise

  use Aesir.ZoneServer.Mmo.Skill,
    id: 318,
    name: :ba_frostjoker,
    requires: [],
    display_name: "Frost Joker",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    sp_cost: [12, 14, 16, 18, 20],
    cast_time: List.duplicate(0, 5),
    fixed_cast_time: List.duplicate(0, 5),
    after_cast_delay: List.duplicate(300, 5),
    cooldown: List.duplicate(5_000, 5)

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Active

  @delay_ms 3_000
  @invisible_option Option.id(:invisible)
  @mado_option Option.id(:madogear)

  @impl Active
  def cast(caster, target, level, definition) do
    cast(caster, target, level, definition, &Skill.defer/3)
  end

  @doc false
  @spec cast(Active.caster(), Active.target(), pos_integer(), struct(), function()) ::
          {:ok, Active.caster()}
  def cast(caster, _target, level, _definition, scheduler) do
    {caster_type, caster_id} = caster_ref(caster)

    payload = %{
      map_name: caster.map_name,
      x: caster.x,
      y: caster.y,
      caster_type: caster_type,
      caster_id: caster_id,
      deferred_epoch: caster.deferred_epoch,
      skill_level: level
    }

    _timer = scheduler.(__MODULE__, payload, @delay_ms)
    {:ok, caster}
  end

  @doc "Resolves a scheduled Frost Joker event from the caster's live session state."
  @impl Active
  def deferred(payload, caster) do
    if current_event?(payload, caster) do
      resolve_candidates(payload, caster)
    end

    :ok
  end

  defp current_event?(
         %{
           map_name: map_name,
           caster_type: caster_type,
           caster_id: caster_id,
           deferred_epoch: epoch
         },
         %{map_name: map_name, deferred_epoch: epoch} = caster
       ) do
    caster_ref(caster) == {caster_type, caster_id} and Unit.living?(caster) and
      match?(
        {:ok, {_current_x, _current_y, ^map_name}},
        SpatialIndex.get_unit_position(caster_type, caster_id)
      )
  end

  defp current_event?(_payload, _caster), do: false

  defp resolve_candidates(
         %{map_name: map_name, x: x, y: y, skill_level: level} = payload,
         caster
       ) do
    area_size = Config.frost_joker_area_size()

    map_name
    |> SpatialIndex.get_all_units_in_range(x, y, area_size * 2)
    |> Enum.filter(&inside_square?(&1, map_name, x, y, area_size))
    |> Enum.each(&apply_freeze(&1, payload, caster, level))
  end

  defp inside_square?({unit_type, unit_id}, map_name, x, y, area_size)
       when unit_type in [:player, :mob] do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {unit_x, unit_y, ^map_name}} ->
        Geometry.in_tile_range?(x, y, unit_x, unit_y, area_size)

      _other ->
        false
    end
  end

  defp inside_square?(_unit, _map_name, _x, _y, _area_size), do: false

  defp apply_freeze({unit_type, unit_id}, payload, caster, level) do
    unless {unit_type, unit_id} == {payload.caster_type, payload.caster_id} do
      with {:ok, _pid, target, ^unit_type} <- TargetResolver.resolve(unit_type, unit_id),
           false <- excluded_player?(target),
           {:ok, success_rate, duration} <- eligibility(caster, target, level) do
        _ =
          StatusInterpreter.apply_status(unit_type, unit_id, :sc_freeze,
            duration: duration,
            success_rate: success_rate,
            caster_id: payload.caster_id,
            source_type: payload.caster_type
          )
      end
    end
  end

  defp excluded_player?(%PlayerState{option: option}) do
    (option &&& (@invisible_option ||| @mado_option)) != 0
  end

  defp excluded_player?(_target), do: false

  defp eligibility(
         %PlayerState{party_id: party_id},
         %PlayerState{party_id: party_id} = target,
         level
       )
       when party_id > 0 do
    if Unit.living?(target) do
      {:ok, party_chance(level), 15_000}
    else
      {:error, :target_dead}
    end
  end

  defp eligibility(caster, target, level) do
    case Targeting.validate_enemy(caster, target) do
      :ok -> {:ok, enemy_chance(level), 27_000}
      {:error, reason} -> {:error, reason}
    end
  end

  defp enemy_chance(level), do: 15 + 5 * level
  defp party_chance(level), do: div(enemy_chance(level) * 10, 4) / 10

  defp caster_ref(%PlayerState{character_id: caster_id}), do: {:player, caster_id}
  defp caster_ref(%MobState{instance_id: caster_id}), do: {:mob, caster_id}
end
