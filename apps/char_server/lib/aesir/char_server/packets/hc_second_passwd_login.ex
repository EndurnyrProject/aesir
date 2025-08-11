defmodule Aesir.CharServer.Packets.HcSecondPasswdLogin do
  @moduledoc """
  HC_SECOND_PASSWD_LOGIN packet (0x08b9) - Pincode state notification.

  Transmits the pincode state to client:
  - state:
    0 = disabled / pin is correct (PINCODE_PASSED)
    1 = ask for pin - client sends 0x8b8 (PINCODE_ASK)  
    2 = create new pin - client sends 0x8ba (PINCODE_NEW)
    3 = pin must be changed - client 0x8be (PINCODE_EXPIRED)
    4 = create new pin - client sends 0x8ba
    5 = client shows msgstr(1896)
    6 = client shows msgstr(1897) Unable to use your KSSN number
    7 = char select window shows a button - client sends 0x8c5
    8 = pincode was incorrect (PINCODE_WRONG)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x08B9
  @packet_size 12

  defstruct [:seed, :account_id, :state]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, seed::32-little, account_id::32-little, state::16-little>>) do
    {:ok,
     %__MODULE__{
       seed: seed,
       account_id: account_id,
       state: state
     }}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{} = packet) do
    state = packet.state || 0
    seed = packet.seed || :rand.uniform(0xFFFF)

    <<
      @packet_id::16-little,
      seed::32-little,
      packet.account_id::32-little,
      state::16-little
    >>
  end
end
