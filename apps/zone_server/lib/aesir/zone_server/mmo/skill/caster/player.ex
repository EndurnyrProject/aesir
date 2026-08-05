defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Player do
  @moduledoc false

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster

  alias Aesir.ZoneServer.Mmo.Skill.Requirement
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @impl true
  def kind, do: :player

  @impl true
  def provides, do: Requirement.all()

  @impl true
  def id(%PlayerState{character_id: character_id}), do: character_id

  @impl true
  def unit_type(%PlayerState{}), do: :player

  @impl true
  def position(%PlayerState{map_name: map_name, x: x, y: y}), do: {map_name, x, y}

  @impl true
  def attack_range(%PlayerState{stats: %{equipment: equipment}}) do
    equipment
    |> PlayerStats.weapon_type()
    |> WeaponTypes.get_attack_range()
  end

  @impl true
  def broadcast_source(%PlayerState{character_id: character_id}), do: character_id
end
