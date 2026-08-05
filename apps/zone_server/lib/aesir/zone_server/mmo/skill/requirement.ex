defmodule Aesir.ZoneServer.Mmo.Skill.Requirement do
  @moduledoc """
  Closed vocabulary of facilities a skill may require from its caster.
  """

  @type t ::
          :player_state
          | :inventory
          | :party
          | :client_dialog
          | :equipment
          | :zeny
          | :spirit_spheres
          | :partner
          | :homunculus_state

  @requirements [
    :player_state,
    :inventory,
    :party,
    :client_dialog,
    :equipment,
    :zeny,
    :spirit_spheres,
    :partner,
    :homunculus_state
  ]

  @doc "Returns every valid skill requirement."
  @spec all() :: [t()]
  def all, do: @requirements

  @doc "Returns whether `requirement` belongs to the closed vocabulary."
  @spec valid?(atom()) :: boolean()
  def valid?(requirement) when is_atom(requirement), do: requirement in @requirements
end
