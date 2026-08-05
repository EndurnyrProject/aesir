defmodule Aesir.ZoneServer.Mmo.Skill.Castability do
  @moduledoc """
  Checks whether a caster kind provides every facility required by a skill.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Requirement

  @type result :: :ok | {:error, {:missing, [Requirement.t()]}}

  @doc "Checks a skill definition against the facilities provided by a caster kind."
  @spec check(Definition.t(), Caster.kind()) :: result()
  def check(%Definition{requires: requires}, caster_kind) do
    missing =
      requires
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(Caster.for_kind(caster_kind).provides()))
      |> Enum.sort()

    if missing == [], do: :ok, else: {:error, {:missing, missing}}
  end

  @doc "Looks up a skill by id and checks it against a caster kind."
  @spec check_by_id(integer(), Caster.kind()) :: result() | :error
  def check_by_id(skill_id, caster_kind) do
    with {:ok, definition} <- Catalog.by_id(skill_id) do
      check(definition, caster_kind)
    end
  end
end
