defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgFlaggraffiti do
  @moduledoc """
  Piece (RG_FLAGGRAFFITI).

  Both modes spend 10 SP and show cast feedback without placing a ground unit.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 221,
    name: :rg_flaggraffiti,
    display_name: "Piece",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    sp_cost: [10, 10, 10, 10, 10],
    damage_kind: :none

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Broadcast

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:skipped, Active.caster(), :unimplemented}
  def cast(caster, {:ground, x, y}, level, definition) do
    adapter = Caster.for(caster)

    packet = %GroundSkill{
      skill_id: definition.id,
      src_id: adapter.id(caster),
      level: level,
      x: x,
      y: y,
      server_tick: ServerTick.now()
    }

    Broadcast.to_in_range(caster.map_name, x, y, Config.view_range(), packet)
    {:skipped, caster, :unimplemented}
  end
end
