defmodule Aesir.CharServer.Packets.HcBlockCharacter do
  @moduledoc """
  HC_BLOCK_CHARACTER packet (0x020d) - Blocked character list.

  Structure:
  - packet_id: 2 bytes (0x020d)
  - packet_length: 2 bytes
  - entries: array of blocked character entries (24 bytes each)
    - char_id: 4 bytes
    - expire_date: 20 bytes (string)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x020D
  @packet_size :variable

  defstruct [:blocked_chars]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, _length::16-little, data::binary>>) do
    blocked_chars = parse_blocked_chars(data)
    {:ok, %__MODULE__{blocked_chars: blocked_chars}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{blocked_chars: blocked_chars})
      when is_list(blocked_chars) and length(blocked_chars) > 0 do
    entries =
      blocked_chars
      |> Enum.map(&serialize_blocked_char/1)
      |> IO.iodata_to_binary()

    build_variable_packet(@packet_id, entries)
  end

  def build(%__MODULE__{}) do
    # Empty blocked list - just header with length 4
    <<@packet_id::16-little, 4::16-little>>
  end

  defp parse_blocked_chars(<<>>), do: []

  defp parse_blocked_chars(<<char_id::32-little, expire_date::binary-size(20), rest::binary>>) do
    expire_str =
      expire_date |> :binary.bin_to_list() |> Enum.take_while(&(&1 != 0)) |> to_string()

    [{char_id, expire_str} | parse_blocked_chars(rest)]
  end

  defp parse_blocked_chars(_), do: []

  defp serialize_blocked_char({char_id, expire_date}) do
    date_binary = pack_string(expire_date, 20)
    <<char_id::32-little, date_binary::binary>>
  end
end
