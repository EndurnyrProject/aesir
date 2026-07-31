defmodule Aesir.ZoneServer.Mmo.Skill.Ensemble do
  @moduledoc """
  Capability behaviour for ensemble skills.

  Using this behaviour marks a skill as an ensemble and implies the active
  behaviour without injecting a dynamic cost callback.
  """

  @doc false
  @callback __ensemble__() :: true

  defmacro __using__(_opts) do
    quote do
      @behaviour Aesir.ZoneServer.Mmo.Skill.Ensemble
      @behaviour Aesir.ZoneServer.Mmo.Skill.Active

      @doc false
      @impl Aesir.ZoneServer.Mmo.Skill.Ensemble
      def __ensemble__, do: true
    end
  end
end
