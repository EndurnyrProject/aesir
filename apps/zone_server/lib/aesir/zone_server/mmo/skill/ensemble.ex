defmodule Aesir.ZoneServer.Mmo.Skill.Ensemble do
  @moduledoc """
  Capability behaviour for ensemble skills.

  Ensembles use Renewal snapshots or maintained pre-renewal ground fields.
  The capability supplies field callbacks and partner validation without
  changing the ordinary skill cost resolver.
  """

  @doc false
  @callback __ensemble__() :: true

  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field

  defmacro __using__(_opts) do
    quote do
      @behaviour Aesir.ZoneServer.Mmo.Skill.Ensemble
      @behaviour Aesir.ZoneServer.Mmo.Skill.Active
      @behaviour Aesir.ZoneServer.Mmo.Skill.Ground

      @impl Aesir.ZoneServer.Mmo.Skill.Active
      def validate(caster, _target, level, definition),
        do: unquote(Perform).validate(caster, definition, level)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_place(group), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_interval(group, now), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate field_support(group), to: unquote(Field)

      @impl Aesir.ZoneServer.Mmo.Skill.Ground
      defdelegate on_expire(group), to: unquote(Field)

      @doc false
      @impl Aesir.ZoneServer.Mmo.Skill.Ensemble
      def __ensemble__, do: true
    end
  end
end
