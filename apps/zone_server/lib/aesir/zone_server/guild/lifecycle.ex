defmodule Aesir.ZoneServer.Guild.Lifecycle do
  @moduledoc """
  Typed Phoenix PubSub facade for guild lifecycle transitions.

  Global topic: any process can learn a guild was disbanded without
  subscribing to that guild's own `"guild:\#{guild_id}"` topic.
  """

  @topic "guild:lifecycle"

  @doc "Subscribes the calling process to guild lifecycle events."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Aesir.PubSub, @topic)

  @doc "Publishes that `guild_id` was disbanded."
  @spec publish_disbanded(pos_integer()) :: :ok | {:error, term()}
  def publish_disbanded(guild_id) do
    Phoenix.PubSub.broadcast(Aesir.PubSub, @topic, {:guild_lifecycle, {:disbanded, guild_id}})
  end
end
