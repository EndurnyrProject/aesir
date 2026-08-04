defmodule Aesir.ZoneServer.Mmo.Homunculus.LifecycleSkills do
  @moduledoc """
  Canonical owner lifecycle skill identity (Call / Rest / Resurrect Homunculus).

  IDs are read from the skill definitions so every consumer stays in sync with
  the skill catalog.
  """

  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCallhomun
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmRest
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmResurrecthomun

  @doc "Skill ID of Call Homunculus."
  @spec call_id() :: pos_integer()
  def call_id, do: AmCallhomun.definition().id

  @doc "Skill ID of Rest (Vaporize)."
  @spec rest_id() :: pos_integer()
  def rest_id, do: AmRest.definition().id

  @doc "Skill ID of Resurrect Homunculus."
  @spec resurrection_id() :: pos_integer()
  def resurrection_id, do: AmResurrecthomun.definition().id

  @doc "Every owner lifecycle skill ID."
  @spec ids() :: [pos_integer()]
  def ids, do: [call_id(), rest_id(), resurrection_id()]

  @doc "Maps a lifecycle operation to its skill ID."
  @spec id_for(:call | :rest | :resurrection) :: pos_integer()
  def id_for(:call), do: call_id()
  def id_for(:rest), do: rest_id()
  def id_for(:resurrection), do: resurrection_id()
end
