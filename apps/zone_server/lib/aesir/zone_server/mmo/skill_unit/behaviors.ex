defmodule Aesir.ZoneServer.Mmo.SkillUnit.Behaviors do
  @moduledoc """
  Registry of ground skill-unit behaviour implementations.

  New ground skills are added by creating a module under
  `Aesir.ZoneServer.Mmo.SkillUnit.Behaviors` and listing it here.
  """

  alias Aesir.ZoneServer.Mmo.SkillUnit.Behaviors.WzStormgust

  @modules [WzStormgust]

  @by_name (for module <- @modules, into: %{} do
              {module.skill_name(), module}
            end)

  @spec all() :: [module()]
  def all, do: @modules

  @spec module_for(atom()) :: {:ok, module()} | :error
  def module_for(name), do: Map.fetch(@by_name, name)
end
