defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgHermode do
  @moduledoc """
  Wand of Hermode grants complete magic immunity and blocks support casts.
  It requires an instrument or whip and lasts ten to thirty seconds by level.

  Renewal snapshots living party members, guildmates and allied guild members
  within three cells, including the caster. It costs twenty to sixty SP.
  Allies lose the Hermode removal-set buffs; the caster keeps theirs.

  Pre-renewal requires a warp or NPC touch area within one cell, costs twenty
  to sixty SP and maintains a seven-by-seven field that grants immunity to
  every unit standing in it, players and monsters alike, lost immediately on
  exit; the caster gets none. Every placement strips the Hermode removal-set
  buffs from party and guild allies. The caster is always rooted and pays one
  SP every five seconds. No partner is required.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 488,
    name: :cg_hermode,
    display_name: "Wand of Hermode",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: [renewal: 3, pre_renewal: 1],
    duration: [10_000, 15_000, 20_000, 25_000, 30_000],
    sp_cost: [20, 30, 40, 50, 60],
    require_weapon: [:musical, :whip],
    status: :sc_hermode,
    damage_kind: :misc

  use Aesir.ZoneServer.Mmo.Skill.Performance

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Performance
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.StatusEffect.ClearBuffs
  alias Aesir.ZoneServer.Npc.Proximity
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(caster, _target, _level, _definition) do
    if GameMode.mode() == :pre_renewal and
         not Proximity.touch_area_within?(caster.map_name, caster.x, caster.y, 1),
       do: {:error, :no_npc_nearby},
       else: :ok
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, term()}
  def cast(caster, :self, level, definition) do
    Performance.perform(caster, definition, level, :sc_hermode, [val1: level],
      scope: :players,
      radius: 3,
      eligible?: &party_or_guild?(caster, &1),
      kind: :ensemble,
      ignore_land_protector: true,
      layout_radius: 3,
      linger_ms: 0,
      reach: :all,
      upkeep: 5,
      root: :always
    )
  end

  @impl Ground
  @spec field_support(Group.t()) :: map()
  def field_support(%Group{} = group) do
    group
    |> Field.field_support()
    |> Map.put(:on_place, &strip_ally_buffs(group, &1))
  end

  defp strip_ally_buffs(%Group{caster_type: type, caster_id: id} = group, mover) do
    if mover != {type, id} and Field.reaches?(:party_or_guild, group, mover),
      do: ClearBuffs.clear(mover, [:hermode])

    :ok
  end

  defp party_or_guild?(caster, target) do
    caster.character_id == target.character_id or
      (is_integer(caster.party_id) and caster.party_id > 0 and caster.party_id == target.party_id) or
      Relations.friendly?(caster.guild_id, target.guild_id)
  end
end
