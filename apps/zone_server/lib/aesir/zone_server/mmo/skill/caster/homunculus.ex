defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Homunculus do
  @moduledoc false

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster

  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @impl true
  def kind, do: :homunculus

  @impl true
  def provides, do: [:homunculus_state]

  @impl true
  def id(%HomunculusState{world_gid: world_gid}), do: world_gid

  @impl true
  def unit_type(%HomunculusState{}), do: :homunculus

  @impl true
  def position(%HomunculusState{map_name: map_name, x: x, y: y}), do: {map_name, x, y}

  @impl true
  def attack_range(%HomunculusState{attack_range: attack_range}), do: attack_range

  @impl true
  def broadcast_source(%HomunculusState{world_gid: world_gid}), do: {:homunculus, world_gid}
end
