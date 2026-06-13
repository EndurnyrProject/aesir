defmodule Aesir.Commons.Cluster do
  @moduledoc """
  Names and helpers for the Horde-backed coordination layer.
  """

  @registry Aesir.Commons.Cluster.Registry
  @owner_supervisor Aesir.Commons.Cluster.OwnerSupervisor

  @spec registry() :: module()
  def registry, do: @registry

  @spec owner_supervisor() :: module()
  def owner_supervisor, do: @owner_supervisor
end
