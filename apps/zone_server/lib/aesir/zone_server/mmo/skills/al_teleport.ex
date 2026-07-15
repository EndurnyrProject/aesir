defmodule Aesir.ZoneServer.Mmo.Skills.AlTeleport do
  @moduledoc """
  Teleport (AL_TELEPORT). Menu-less instant self-warp.

  rAthena (`skill_db` id 26): MaxLevel 2, SP [10, 9], no cast time, no
  after-cast delay.

  - lv1: warps the caster to a random walkable cell on the current map.
  - lv2: warps the caster to their save point.

  The warp is staged on `pending_warp` in the returned `PlayerState`;
  `SkillHandler.commit_cast` drains it via `WarpHandler.warp/4` after
  committing SP and cooldowns.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 26,
    name: :al_teleport,
    display_name: "Teleport",
    max_level: 2,
    target_type: :self,
    sp_cost: [10, 9]

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
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
