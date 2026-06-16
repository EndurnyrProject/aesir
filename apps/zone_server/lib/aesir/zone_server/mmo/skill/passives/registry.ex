defmodule Aesir.ZoneServer.Mmo.Skill.Passives.Registry do
  @moduledoc """
  Registry of passive skill implementations.

  New passives are added by creating a module under
  `Aesir.ZoneServer.Mmo.Skill.Passives` and listing it here.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Passives

  @modules [
    Passives.SmSword,
    Passives.SmTwohand,
    Passives.SmRecovery,
    Passives.SmMovingRecovery,
    Passives.SmFatalblow
  ]

  @by_name (for module <- @modules, into: %{} do
              {module.skill_name(), module}
            end)

  @spec all() :: [module()]
  def all, do: @modules

  @spec module_for(atom()) :: {:ok, module()} | :error
  def module_for(name), do: Map.fetch(@by_name, name)
end
