defmodule Aesir.ZoneServer.Mmo.Skill.Performance do
  @moduledoc """
  Capability behaviour for skills that are songs or dances.

  Using this behaviour marks a skill as a performance and supplies its dynamic
  cost through the generic skill cost resolver. A module that uses this behaviour
  must not separately declare `Aesir.ZoneServer.Mmo.Skill.Active`, because
  performance implies the active behaviour.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Cost

  @doc false
  @callback __performance__() :: true

  defmacro __using__(_opts) do
    quote do
      @behaviour Aesir.ZoneServer.Mmo.Skill.Performance
      @behaviour Aesir.ZoneServer.Mmo.Skill.Active

      @doc false
      @impl Aesir.ZoneServer.Mmo.Skill.Performance
      def __performance__, do: true

      @impl Aesir.ZoneServer.Mmo.Skill.Active
      def dynamic_cost(caster, _target, level, definition) do
        sp = unquote(Cost).resolve_sp(caster, definition, level)
        unquote(Cost).from_definition(caster, definition, level, sp: sp)
      end
    end
  end
end
