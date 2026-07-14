defmodule Aesir.ZoneServer.Unit.Lifecycle.Event do
  @moduledoc "A normalized player or mob lifecycle transition."

  use TypedStruct

  alias Aesir.ZoneServer.Unit

  @type reason :: :death | :disconnect | :termination | :warp

  typedstruct do
    field :unit_type, Unit.unit_type(), enforce: true
    field :unit_id, integer(), enforce: true
    field :reason, reason(), enforce: true
    field :old_map, String.t() | nil
    field :new_map, String.t() | nil
  end
end

defmodule Aesir.ZoneServer.Unit.Lifecycle do
  @moduledoc """
  Typed Phoenix PubSub facade for player and mob lifecycle transitions.
  """

  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Lifecycle.Event

  @topic "unit:lifecycle"

  @doc "Subscribes the calling process to normalized lifecycle events."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Aesir.PubSub, @topic)

  @doc "Publishes one unit-death event."
  @spec publish_death(Unit.unit_type(), integer(), String.t()) :: :ok | {:error, term()}
  def publish_death(unit_type, unit_id, map_name) do
    publish(%Event{
      unit_type: unit_type,
      unit_id: unit_id,
      reason: :death,
      old_map: map_name
    })
  end

  @doc "Publishes one disconnect or non-death termination event."
  @spec publish_departure(Unit.unit_type(), integer(), String.t(), :disconnect | :termination) ::
          :ok | {:error, term()}
  def publish_departure(unit_type, unit_id, map_name, reason)
      when reason in [:disconnect, :termination] do
    publish(%Event{
      unit_type: unit_type,
      unit_id: unit_id,
      reason: reason,
      old_map: map_name
    })
  end

  @doc "Publishes one cross-map warp event."
  @spec publish_transition(Unit.unit_type(), integer(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def publish_transition(unit_type, unit_id, old_map, new_map) do
    publish(%Event{
      unit_type: unit_type,
      unit_id: unit_id,
      reason: :warp,
      old_map: old_map,
      new_map: new_map
    })
  end

  @doc "Publishes a normalized lifecycle event."
  @spec publish(Event.t()) :: :ok | {:error, term()}
  def publish(%Event{} = event) do
    Phoenix.PubSub.broadcast(Aesir.PubSub, @topic, {:unit_lifecycle, event})
  end
end
