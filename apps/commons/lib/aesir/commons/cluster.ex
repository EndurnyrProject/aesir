defmodule Aesir.Commons.Cluster do
  @moduledoc """
  Names and helpers for the Horde-backed coordination layer.
  """

  @registry Aesir.Commons.Cluster.Registry
  @owner_supervisor Aesir.Commons.Cluster.OwnerSupervisor
  @item_group_pool_supervisor Aesir.Commons.Cluster.ItemGroupPoolSupervisor

  @spec registry() :: module()
  def registry, do: @registry

  @spec owner_supervisor() :: module()
  def owner_supervisor, do: @owner_supervisor

  @doc """
  Returns the Horde supervisor for item-group pools.
  """
  @spec item_group_pool_supervisor() :: module()
  def item_group_pool_supervisor, do: @item_group_pool_supervisor
end
