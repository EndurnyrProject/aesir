defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgIntimidate do
  @moduledoc """
  Snatch (RG_INTIMIDATE), a melee hit that relocates both combatants.

  Both modes deal 100 plus 30 per level percent for 13 plus 3 per level SP. A
  hit that deals damage to a target that is not status-immune then has a 50
  plus 5 per level percent chance, plus the caster's level minus the target's,
  to teleport them 0.8 s later: the caster to a random cell of its map, the
  target to a free cell beside it. A target that is dead, gone or out of view
  by then stays behind and the caster teleports alone; one in view range on
  another map stops the teleport. A player on a no-teleport map does not move.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 219,
    name: :rg_intimidate,
    requires: [],
    display_name: "Snatch",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 1,
    sp_cost: [13, 16, 19, 22, 25]

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @warp_delay 800
  @area_size 14

  @impl Active
  def cast(caster, {:unit, target_ref}, level, definition) do
    with {:ok, _pid, target, _target_type} <- TargetResolver.resolve(target_ref) do
      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 100 + 30 * level,
        skip_range: true,
        report_hit: true
      ]

      case Combat.execute_skill_attack(caster, target_ref, opts) do
        {:ok, %{damage: damage}} when damage > 0 ->
          maybe_warp(caster, target_ref, target, level)
          {:ok, caster}

        {:ok, _no_damage} ->
          {:ok, caster}

        {:error, _reason} = error ->
          error
      end
    end
  end

  @impl Active
  def deferred(
        %{target: target_ref, map_name: map_name, caster_id: caster_id, deferred_epoch: epoch} =
          payload,
        caster
      ) do
    if current_caster?(caster, caster_id, map_name, epoch) do
      caster_type = Map.get(payload, :caster_type, :player)

      case companion(caster, target_ref) do
        :abort -> :ok
        companion -> warp(caster_type, caster, caster_id, companion)
      end
    end

    :ok
  end

  # The target goes along only while it stands within view of the caster on
  # its map. One that is gone or out of view leaves the caster to warp alone;
  # one in view coordinates on another map stops the warp.
  defp companion(caster, target_ref) do
    with {:ok, pid, target, type} <- TargetResolver.resolve(target_ref),
         true <- in_area?(caster, target) do
      if target.map_name == caster.map_name, do: {type, pid, target}, else: :abort
    else
      _gone_or_away -> nil
    end
  end

  defp in_area?(caster, %{x: x, y: y}) when is_integer(x) and is_integer(y),
    do: Geometry.chebyshev_distance(caster.x, caster.y, x, y) <= @area_size

  defp in_area?(_caster, _target), do: false

  # The caster teleports to a random cell of its map; a living target lands on
  # a free cell beside the caster's new cell.
  defp warp(caster_type, caster, caster_id, companion) do
    map_name = caster.map_name

    with true <- teleportable?(caster_type, map_name),
         {:ok, {x, y}} <- Cell.random_traversable(map_name) do
      warp_caster(caster_type, map_name, x, y)

      warp_companion(
        companion,
        map_name,
        Cell.random_traversable_near(map_name, {x, y}, 1),
        {caster_type, caster_id}
      )
    end
  end

  defp warp_companion({type, pid, target}, map_name, {x, y}, {source_type, source_id}) do
    if Unit.living?(target) and teleportable?(type, map_name) and
         warp_target(type, pid, target, map_name, x, y) == :ok do
      _ =
        StatusInterpreter.apply_status(
          type,
          target.__struct__.get_unit_id(target),
          :sc_intimidate,
          caster_id: source_id,
          source_type: source_type
        )
    end

    :ok
  end

  defp warp_companion(nil, _map_name, _cell, _source), do: :ok

  defp teleportable?(:player, map_name), do: not MapFlags.get(map_name, :noteleport)
  defp teleportable?(_unit_type, _map_name), do: true

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

  defp warp_target(:player, pid, _target, map_name, x, y),
    do: PlayerSession.warp(pid, map_name, x, y)

  defp warp_target(:mob, pid, _target, map_name, x, y), do: MobSession.warp(pid, map_name, x, y)

  defp warp_target(:homunculus, owner_pid, target, map_name, x, y),
    do:
      PlayerSession.displace_homunculus(
        owner_pid,
        target.world_gid,
        target.x,
        target.y,
        map_name,
        x,
        y
      )

  defp warp_target(_unit_type, _pid, _target, _map_name, _x, _y), do: :error

  # The caster runs in its own session process, so warp `self()`.
  defp warp_caster(:player, map_name, x, y), do: PlayerSession.warp(self(), map_name, x, y)
  defp warp_caster(:mob, map_name, x, y), do: MobSession.warp(self(), map_name, x, y)

  defp deferred_payload(caster) do
    {caster_type, caster_id} = caster_ref(caster)

    %{
      map_name: caster.map_name,
      caster_type: caster_type,
      caster_id: caster_id,
      deferred_epoch: caster.deferred_epoch
    }
  end

  defp maybe_warp(caster, target_ref, target, level) do
    if warps?(caster, target, level),
      do:
        Skill.defer(
          __MODULE__,
          Map.put(deferred_payload(caster), :target, target_ref),
          @warp_delay
        )
  end

  # A damaging hit on a target that is not status-immune warps with a chance of
  # 50 + 5 per level plus the caster's level minus the target's.
  defp warps?(caster, target, level) do
    not status_immune?(target) and
      :rand.uniform(100) <= 50 + 5 * level + unit_level(caster) - unit_level(target)
  end

  defp status_immune?(%MobState{mob_data: %{modes: modes}}),
    do: :status_immune in modes

  defp status_immune?(_target), do: false

  defp unit_level(%PlayerState{stats: %{progression: %{base_level: level}}}), do: level
  defp unit_level(%MobState{mob_data: %{level: level}}), do: level
  defp unit_level(%HomunculusState{level: level}), do: level

  defp caster_ref(%PlayerState{character_id: caster_id}), do: {:player, caster_id}
  defp caster_ref(%MobState{instance_id: caster_id}), do: {:mob, caster_id}
end
