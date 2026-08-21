defmodule Aesir.Commons.Network.ProtoManifest.ParseError do
  @moduledoc """
  Raised while `Aesir.Commons.Network.ProtoManifest` compiles when the routing
  annotations in `proto/aesir.proto` are missing, malformed, or out of sync with
  the `Envelope` oneof.
  """

  defexception [:message]

  @type t :: %__MODULE__{message: String.t()}
end
