defmodule Aesir.CharServer.Packets.HcCharDelete2Ack do
  @moduledoc """
  HC_CHAR_DELETE2_ACK packet (0x0828) - Response to character deletion request.

  This packet confirms or rejects the character deletion request.

  Structure (14 bytes):
  - packet_id: 2 bytes (0x0828)
  - char_id: 4 bytes (character ID that was requested for deletion)
  - result: 4 bytes (deletion result code)
  - delete_date: 4 bytes (timestamp when character will be deleted)

  Result codes:
  - 0: Success (character will be deleted after timeout)
  - 1: Database error
  - 2: Character doesn't belong to account
  - 3: Character already marked for deletion
  - 4: Cannot delete character (guild member, has items, etc.)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0828
  @packet_size 14

  @success 0
  @database_error 1
  @not_found 2
  @already_deleting 3
  @cannot_delete 4

  defstruct [:char_id, :result, :delete_date]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(
        <<@packet_id::16-little, char_id::32-little, result::32-little, delete_date::32-little>>
      ) do
    {:ok,
     %__MODULE__{
       char_id: char_id,
       result: result,
       delete_date: delete_date
     }}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{char_id: char_id, result: result, delete_date: delete_date}) do
    <<@packet_id::16-little, char_id::32-little, result::32-little, delete_date::32-little>>
  end

  def success_result(char_id, delete_date) do
    %__MODULE__{
      char_id: char_id,
      result: @success,
      delete_date: delete_date
    }
  end

  def error_result(char_id, :database_error) do
    %__MODULE__{
      char_id: char_id,
      result: @database_error,
      delete_date: 0
    }
  end

  def error_result(char_id, :not_found) do
    %__MODULE__{
      char_id: char_id,
      result: @not_found,
      delete_date: 0
    }
  end

  def error_result(char_id, :already_deleting) do
    %__MODULE__{
      char_id: char_id,
      result: @already_deleting,
      delete_date: 0
    }
  end

  def error_result(char_id, :cannot_delete) do
    %__MODULE__{
      char_id: char_id,
      result: @cannot_delete,
      delete_date: 0
    }
  end
end
