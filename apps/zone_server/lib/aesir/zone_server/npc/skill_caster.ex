defmodule Aesir.ZoneServer.Npc.SkillCaster do
  @moduledoc """
  Synthetic NPC caster used for scripted skill effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster

  alias Aesir.ZoneServer.Mmo.Combat.Combatant

  @enforce_keys [:npc_gid, :stat_point, :base_level, :position, :map_name]
  defstruct [:npc_gid, :stat_point, :base_level, :position, :map_name]

  @type t() :: %__MODULE__{
          npc_gid: pos_integer(),
          stat_point: integer(),
          base_level: pos_integer(),
          position: {integer(), integer()},
          map_name: String.t()
        }

  @doc "Creates a synthetic NPC skill caster."
  @spec new(pos_integer(), integer(), pos_integer(), {integer(), integer()}, String.t()) :: t()
  def new(npc_gid, stat_point, base_level, position, map_name) do
    %__MODULE__{
      npc_gid: npc_gid,
      stat_point: stat_point,
      base_level: base_level,
      position: position,
      map_name: map_name
    }
  end

  @impl true
  def kind, do: :npc

  @impl true
  def provides, do: []

  @impl true
  def id(%__MODULE__{npc_gid: npc_gid}), do: npc_gid

  @impl true
  def unit_type(%__MODULE__{}), do: :npc

  @impl true
  def position(%__MODULE__{map_name: map_name, position: {x, y}}), do: {map_name, x, y}

  @impl true
  def attack_range(%__MODULE__{}), do: 1

  @impl true
  def broadcast_source(%__MODULE__{npc_gid: npc_gid}), do: {:npc, npc_gid}

  @impl true
  def sp(%__MODULE__{}), do: 0

  @impl true
  def deduct_sp(%__MODULE__{} = caster, _amount), do: caster

  @doc "Builds the combatant used to calculate this caster's skill effects."
  @spec to_combatant(t()) :: Combatant.t()
  def to_combatant(%__MODULE__{} = caster) do
    stat_point = caster.stat_point

    matk =
      stat_point + div(stat_point, 2) + div(stat_point, 5) + div(stat_point, 3) +
        div(caster.base_level, 4)

    Combatant.new!(%{
      unit_id: caster.npc_gid,
      unit_type: :npc,
      social_root: {:npc, caster.npc_gid},
      reward_root: nil,
      base_stats: %{
        str: stat_point,
        agi: stat_point,
        vit: stat_point,
        int: stat_point,
        dex: stat_point,
        luk: stat_point
      },
      combat_stats: %{
        atk: 0,
        def: 0,
        flee: 0,
        hit: 0,
        matk: matk,
        matk_min: matk,
        matk_max: matk,
        heal_matk_min: matk,
        heal_matk_max: matk,
        mdef: 0,
        perfect_dodge: 0,
        soft_mdef: 0,
        ignore_size_penalty: false,
        max_weapon_damage: false
      },
      progression: %{base_level: caster.base_level, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      race2: [],
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 1,
      attack_delay_ms: 1_000,
      position: caster.position,
      map_name: caster.map_name,
      equip_modifiers: %{}
    })
  end
end
