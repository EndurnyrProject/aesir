defmodule Aesir.ZoneServer.Mmo.Skill.Behaviour do
  @moduledoc """
  Behaviour for skill implementations.

  Each skill module declares its name with `use Skill.Behaviour, skill: :name`
  and implements `cast/4`. `validate/4` defaults to `:ok`.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @type target :: :self | {:unit, non_neg_integer()} | {:ground, integer(), integer()}

  @callback skill_name() :: atom()
  @callback validate(PlayerState.t(), target(), pos_integer(), Definition.t()) ::
              :ok | {:error, atom()}
  @callback cast(PlayerState.t(), target(), pos_integer(), Definition.t()) ::
              {:ok, PlayerState.t()} | {:error, atom()}

  defmacro __using__(opts) do
    skill = Keyword.fetch!(opts, :skill)

    quote do
      @behaviour Aesir.ZoneServer.Mmo.Skill.Behaviour

      @impl true
      def skill_name, do: unquote(skill)

      @impl true
      def validate(_caster, _target, _level, _definition), do: :ok

      defoverridable validate: 4
    end
  end
end
