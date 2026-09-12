defmodule Aesir.ZoneServer.Map.Lifecycle do
  @moduledoc """
  Typed Phoenix PubSub facade for the map-coordinator boot sweep.

  The event is node-local: coordinator initialization is a per-node fact, so
  a peer node finishing its own sweep must not re-seed this node's castles.
  """

  @topic "map:lifecycle"

  @doc "Subscribes the calling process to map lifecycle events."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Aesir.PubSub, @topic)

  @doc """
  Publishes that the boot-time map coordinator sweep has finished, to
  subscribers on this node only.
  """
  @spec publish_initialized() :: :ok | {:error, term()}
  def publish_initialized do
    Phoenix.PubSub.local_broadcast(Aesir.PubSub, @topic, {:map_lifecycle, :initialized})
  end
end
