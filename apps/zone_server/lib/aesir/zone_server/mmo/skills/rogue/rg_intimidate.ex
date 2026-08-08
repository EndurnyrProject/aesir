defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgIntimidate do
  @moduledoc "Snatch (RG_INTIMIDATE), a melee hit that relocates both combatants."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 219,
    name: :rg_intimidate,
    requires: [],
    display_name: "Snatch",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 1

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_ref}, level, definition) do
    with {:ok, _pid, target, _target_type} <- TargetResolver.resolve(target_ref) do
      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 30 * level,
        skip_range: true,
        report_hit: true
      ]

      case Combat.execute_skill_attack(caster, target_ref, opts) do
        {:ok, %{hit?: true}} ->
          Skill.defer(__MODULE__, deferred_payload(caster, target_ref, target), 0)
          {:ok, caster}

        {:ok, %{hit?: false}} ->
          {:ok, caster}

        {:error, _reason} = error ->
          error
      end
    end
  end

  @impl Active
  def deferred(
        %{
          target: target_ref,
          map_name: map_name,
          caster_id: caster_id,
          deferred_epoch: caster_epoch,
          target_epoch: target_epoch
        } = payload,
        caster
      ) do
    if current_caster?(caster, caster_id, map_name, caster_epoch) do
      caster_type = Map.get(payload, :caster_type, :player)
      relocate(caster_type, target_ref, target_epoch, caster_id, map_name)
    end

    :ok
  end

  defp relocate(caster_type, target_ref, target_epoch, caster_id, map_name) do
    with {:ok, target_pid, target, target_type} <- TargetResolver.resolve(target_ref),
         true <- current_target?(target, target_type, map_name, target_epoch),
         {:ok, {x, y}} <- Cell.random_traversable(map_name) do
      warp_target(target_type, target_pid, map_name, x, y)
      warp_caster(caster_type, map_name, x, y)

      _ =
        StatusInterpreter.apply_status(target_type, unit_id(target_ref), :sc_intimidate,
          caster_id: caster_id,
          source_type: caster_type
        )
    end
  end

  defp current_caster?(%PlayerState{} = caster, caster_id, map_name, epoch) do
    caster.character_id == caster_id and caster.map_name == map_name and
      caster.deferred_epoch == epoch and
      Unit.living?(caster)
  end

  defp current_caster?(%MobState{} = caster, caster_id, map_name, epoch) do
    caster.instance_id == caster_id and caster.map_name == map_name and
      caster.deferred_epoch == epoch and
      Unit.living?(caster)
  end

  defp current_target?(target, target_type, map_name, epoch)
       when target_type in [:player, :mob] do
    target.map_name == map_name and target.deferred_epoch == epoch and Unit.living?(target)
  end

  defp current_target?(_target, _target_type, _map_name, _epoch), do: false

  defp warp_target(:player, pid, map_name, x, y), do: PlayerSession.warp(pid, map_name, x, y)
  defp warp_target(:mob, pid, map_name, x, y), do: MobSession.warp(pid, map_name, x, y)

  # The caster runs in its own session process, so warp `self()`.
  defp warp_caster(:player, map_name, x, y), do: PlayerSession.warp(self(), map_name, x, y)
  defp warp_caster(:mob, map_name, x, y), do: MobSession.warp(self(), map_name, x, y)

  defp unit_id({_unit_type, unit_id}), do: unit_id
  defp unit_id(unit_id), do: unit_id

  defp deferred_payload(caster, target_ref, target) do
    {caster_type, caster_id} = caster_ref(caster)

    %{
      target: target_ref,
      map_name: caster.map_name,
      caster_type: caster_type,
      caster_id: caster_id,
      deferred_epoch: caster.deferred_epoch,
      target_epoch: target.deferred_epoch
    }
  end

  defp caster_ref(%PlayerState{character_id: caster_id}), do: {:player, caster_id}
  defp caster_ref(%MobState{instance_id: caster_id}), do: {:mob, caster_id}
end
