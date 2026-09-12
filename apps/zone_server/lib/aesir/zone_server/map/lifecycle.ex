defmodule Aesir.ZoneServer.Map.Lifecycle do
  @moduledoc """
  Typed Phoenix PubSub facade for the map-coordinator boot sweep.
  """

  @topic "map:lifecycle"

  @doc "Subscribes the calling process to map lifecycle events."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Aesir.PubSub, @topic)

  @doc "Publishes that the boot-time map coordinator sweep has finished."
  @spec publish_initialized() :: :ok | {:error, term()}
  def publish_initialized do
    Phoenix.PubSub.broadcast(Aesir.PubSub, @topic, {:map_lifecycle, :initialized})
  end
end
