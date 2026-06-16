defmodule Aesir.ZoneServer.Mmo.Skill.Behaviors do
  @moduledoc """
  Registry of skill behavior implementations.

  New skills are added by creating a module under
  `Aesir.ZoneServer.Mmo.Skill.Behaviors` and listing it here.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Behaviors

  @modules [
    Behaviors.AlIncagi,
    Behaviors.SmBash
  ]

  @by_name (for module <- @modules, into: %{} do
              {module.skill_name(), module}
            end)

  @spec all() :: [module()]
  def all, do: @modules

  @spec module_for(atom()) :: {:ok, module()} | :error
  def module_for(name), do: Map.fetch(@by_name, name)
end
