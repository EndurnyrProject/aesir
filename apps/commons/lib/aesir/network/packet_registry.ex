defmodule Aesir.Network.PacketRegistry do
  @moduledoc """
  Registry for packet definitions and metadata.

  Maintains mapping of packet IDs to their corresponding modules.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [packets: opts] do
      @packets (for module <- packets, into: %{} do
                  packet_id = module.packet_id()
                  {packet_id, module}
                end)

      @doc """
      Get the module for a given packet ID.
      """
      def get_module(packet_id), do: Map.get(@packets, packet_id)

      @doc """
      Get packet information including size and module.

      Returns {:ok, packet_info} or {:error, :unknown_packet}
      """
      def get_packet_info(packet_id) do
        case Map.get(@packets, packet_id) do
          nil ->
            {:error, :unknown_packet}

          module ->
            size =
              case module.packet_size() do
                :variable -> -1
                size when is_integer(size) -> size
              end

            {:ok,
             %{
               module: module,
               size: size,
               id: packet_id
             }}
        end
      end

      @doc """
      Get all registered packets.
      """
      def all_packets, do: @packets

      @doc """
      Check if a packet ID is registered.
      """
      def known_packet?(packet_id), do: Map.has_key?(@packets, packet_id)
    end
  end
end
