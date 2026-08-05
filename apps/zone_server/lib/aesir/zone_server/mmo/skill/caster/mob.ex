defmodule Aesir.ZoneServer.Mmo.Skill.Caster.Mob do
  @moduledoc false

  @behaviour Aesir.ZoneServer.Mmo.Skill.Caster

  alias Aesir.ZoneServer.Unit.Mob.MobState

  @impl true
  def kind, do: :mob

  @impl true
  def provides, do: []

  @impl true
  def id(%MobState{instance_id: instance_id}), do: instance_id

  @impl true
  def unit_type(%MobState{}), do: :mob

  @impl true
  def position(%MobState{map_name: map_name, x: x, y: y}), do: {map_name, x, y}

  @impl true
  def attack_range(%MobState{mob_data: %{skill_range: skill_range}}), do: skill_range

  @impl true
  def broadcast_source(%MobState{instance_id: instance_id}), do: {:mob, instance_id}
end
