defmodule Aesir.ZoneServer.Mmo.Skill.Caster do
  @moduledoc """
  Identity and geometry interface shared by skill casters.
  """

  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @type kind :: :player | :homunculus | :mob
  @type state :: any()

  @callback kind() :: kind()
  @callback provides() :: [Aesir.ZoneServer.Mmo.Skill.Requirement.t()]
  @callback id(state()) :: integer()
  @callback unit_type(state()) :: Aesir.ZoneServer.Unit.unit_type()
  @callback position(state()) :: {String.t(), integer(), integer()}
  @callback attack_range(state()) :: non_neg_integer()
  @callback broadcast_source(state()) ::
              integer() | {Aesir.ZoneServer.Unit.unit_type(), integer()}

  @spec for(struct()) :: module()
  def for(%PlayerState{}), do: __MODULE__.Player
  def for(%HomunculusState{}), do: __MODULE__.Homunculus
  def for(%MobState{}), do: __MODULE__.Mob

  def for(%module{}) do
    raise ArgumentError, "unsupported skill caster struct: #{inspect(module)}"
  end

  @spec for_kind(kind()) :: module()
  def for_kind(:player), do: __MODULE__.Player
  def for_kind(:homunculus), do: __MODULE__.Homunculus
  def for_kind(:mob), do: __MODULE__.Mob

  def for_kind(other) do
    raise ArgumentError, "unsupported caster kind: #{inspect(other)}"
  end
end
