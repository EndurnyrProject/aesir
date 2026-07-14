defmodule Aesir.ZoneServer.Guild.EmblemValidator do
  @moduledoc """
  Header-level validation for uploaded guild emblems. A valid emblem is a
  24x24 BMP no larger than 100 KB. Only the BMP header is inspected (magic +
  dimensions); pixel data is not decoded, as the custom client is trusted for
  pixel content.
  """

  @required_dimension 24
  # NOTE: 100 KB read as 100 * 1024; bump if the client ships larger emblems.
  @max_bytes 102_400

  @doc """
  Validates an emblem blob: `"BM"` magic, 24x24 dimensions read little-endian
  from the BMP header (width at offset 18, height at offset 22), and total
  size within the cap.
  """
  @spec validate(binary()) :: :ok | {:error, :invalid_emblem}
  def validate(
        <<"BM", _::binary-size(16), @required_dimension::little-signed-32,
          @required_dimension::little-signed-32, _::binary>> = data
      )
      when byte_size(data) <= @max_bytes do
    :ok
  end

  def validate(_data), do: {:error, :invalid_emblem}
end
