defmodule Aesir.Commons.Network.Proto do
  @moduledoc """
  Compile-time host for the Aesir protobuf schema.

  `use Protox` generates the wire-message structs from `proto/aesir.proto` at
  build time. Per the `package aesir.net` directive they are created under the
  `Aesir.Net.*` namespace (e.g. `Aesir.Net.Envelope`, `Aesir.Net.LoginRequest`).
  This module itself holds no messages — it only triggers generation and tracks
  the `.proto` as an `@external_resource` so edits force a recompile.

  Encode/decode go through the generated structs or `Protox`:

      {:ok, iodata, _size} = Aesir.Net.Envelope.encode(envelope)
      {:ok, envelope} = Aesir.Net.Envelope.decode(binary)
  """
  use Protox, files: ["proto/aesir.proto"]
end
