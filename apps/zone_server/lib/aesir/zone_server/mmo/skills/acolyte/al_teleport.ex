defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlTeleport do
  @moduledoc """
  Teleport (AL_TELEPORT). Menu-less instant self-warp. Two levels, ten and nine
  SP, no cast time and no after-cast delay.

  - lv1: warps the caster to a random walkable cell on the current map.
  - lv2: warps the caster to their save point.

  The warp is staged on `pending_warp` in the returned `PlayerState`;
  `SkillHandler.commit_cast` drains it via `WarpHandler.warp/4` after
  committing SP and cooldowns.

  A mob caster has no `pending_warp` staging step: it relocates immediately
  via `MobSession.teleport/1`, a cast to the mob's own session pid, regardless
  of level.

  Renewal and pre-renewal behave identically: the same two levels, the same
  costs, the same instant cast, and the same random-cell and save-point
  destinations. Teleport carries no mode-specific branch.

  Aesir always resolves level 2 straight to the save point. The source offers
  the player a two-entry destination menu at that level (random cell or save
  point) unless the cast is automatic; Aesir has no warp-list wire message, so
  the menu is skipped and the save point is taken.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 26,
    name: :al_teleport,
    requires: [],
    display_name: "Teleport",
    max_level: 2,
    target_type: :self,
    damage_kind: :magic,
    sp_cost: [10, 9]

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(%MobState{process_pid: pid} = caster, _target, _level, _definition) do
    MobSession.teleport(pid)
    {:ok, caster}
  end

  def cast(caster, :self, 1, _definition) do
    case Cell.random_traversable(caster.map_name) do
      {:ok, {x, y}} -> {:ok, %{caster | pending_warp: {caster.map_name, x, y}}}
      {:error, _reason} -> {:ok, caster}
    end
  end

  def cast(caster, :self, 2, _definition) do
    {:ok, %{caster | pending_warp: {caster.save_map, caster.save_x, caster.save_y}}}
  end
end
