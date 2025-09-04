defmodule Aesir.ZoneServer.Packets.ZcNotifyAct do
  @moduledoc """
  ZC_NOTIFY_ACT (0x08C8) - Attack/Damage action notification packet.

  This packet notifies clients about attack actions and damage dealt,
  including critical hits and other combat effects. Used to display
  attack animations and damage numbers to players.

  Packet structure for PACKETVER >= 20131223:
  - src_id: ID of the attacking unit
  - target_id: ID of the target unit
  - server_tick: Server timestamp (usually ignored by client)
  - src_speed: Attack speed of the attacker
  - dmg_speed: Damage motion speed
  - damage: Primary damage value
  - is_sp_damage: Whether this is SP damage (0 = HP, 1 = SP)
  - div: Number of hits (for multi-hit attacks)
  - type: Attack type (0 = normal, 8 = critical, etc.)
  - damage2: Secondary damage (for dual-wield)

  Attack types:
  - 0: Normal attack
  - 4: Multi-hit attack
  - 8: Critical hit (displays different animation and effects)
  - 10: Lucky dodge (miss)
  """

  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Utils.ServerTick

  @packet_id 0x08C8

  @type t :: %__MODULE__{
          src_id: integer(),
          target_id: integer(),
          server_tick: integer() | nil,
          src_speed: integer(),
          dmg_speed: integer(),
          damage: integer(),
          is_sp_damage: integer(),
          div: integer(),
          type: integer(),
          damage2: integer()
        }

  defstruct [
    :src_id,
    :target_id,
    :server_tick,
    :src_speed,
    :dmg_speed,
    :damage,
    :is_sp_damage,
    :div,
    :type,
    :damage2
  ]

  # Attack type constants
  @attack_type_normal 0
  @attack_type_multi_hit 4
  @attack_type_critical 8
  @attack_type_lucky_dodge 10

  @doc """
  Returns the packet ID for ZC_NOTIFY_ACT.
  """
  @impl true
  def packet_id, do: @packet_id

  @doc """
  Returns the packet size (fixed length).
  """
  @impl true
  def packet_size, do: 34

  @doc """
  Builds the binary packet data for ZC_NOTIFY_ACT.

  ## Parameters
  - packet: ZcNotifyAct struct with all required fields

  ## Returns
  Binary packet data ready for transmission
  """
  @impl true
  def build(%__MODULE__{} = packet) do
    server_tick = packet.server_tick || ServerTick.now()

    data = <<
      # Source ID (4 bytes)
      packet.src_id::32-little,
      # Target ID (4 bytes)
      packet.target_id::32-little,
      # Server tick (4 bytes)
      server_tick::32-little,
      # Source speed (4 bytes)
      packet.src_speed::32-little-signed,
      # Damage speed (4 bytes)
      packet.dmg_speed::32-little-signed,
      # Primary damage (4 bytes) - MUST be signed for proper display
      packet.damage::32-little-signed,
      # Is SP damage flag (1 byte)
      packet.is_sp_damage::8,
      # Division/hit count (2 bytes)
      packet.div::16-little,
      # Attack type (1 byte)
      packet.type::8,
      # Secondary damage (4 bytes) - also signed
      packet.damage2::32-little-signed
    >>

    build_packet(@packet_id, data)
  end

  @doc """
  Creates a ZC_NOTIFY_ACT packet for a normal attack.

  ## Parameters
  - src_id: Attacker's ID
  - target_id: Target's ID
  - damage: Damage dealt
  - opts: Optional parameters (src_speed, dmg_speed, damage2)

  ## Returns
  ZcNotifyAct struct configured for normal attack

  ## Examples
      iex> packet = ZcNotifyAct.normal_attack(1001, 2001, 150)
      iex> packet.type
      0
      iex> packet.damage
      150
  """
  @spec normal_attack(integer(), integer(), integer(), keyword()) :: t()
  def normal_attack(src_id, target_id, damage, opts \\ [])
      when is_integer(src_id) and is_integer(target_id) and is_integer(damage) do
    %__MODULE__{
      src_id: src_id,
      target_id: target_id,
      server_tick: Keyword.get(opts, :server_tick),
      src_speed: Keyword.get(opts, :src_speed, 1000),
      dmg_speed: Keyword.get(opts, :dmg_speed, 500),
      damage: damage,
      is_sp_damage: Keyword.get(opts, :is_sp_damage, 0),
      div: Keyword.get(opts, :div, 1),
      type: @attack_type_normal,
      damage2: Keyword.get(opts, :damage2, 0)
    }
  end

  @doc """
  Creates a ZC_NOTIFY_ACT packet for a critical hit attack.

  ## Parameters
  - src_id: Attacker's ID
  - target_id: Target's ID
  - damage: Critical damage dealt
  - opts: Optional parameters (src_speed, dmg_speed, damage2)

  ## Returns
  ZcNotifyAct struct configured for critical hit

  ## Examples
      iex> packet = ZcNotifyAct.critical_attack(1001, 2001, 300)
      iex> packet.type
      8
      iex> packet.damage
      300
  """
  @spec critical_attack(integer(), integer(), integer(), keyword()) :: t()
  def critical_attack(src_id, target_id, damage, opts \\ [])
      when is_integer(src_id) and is_integer(target_id) and is_integer(damage) do
    %__MODULE__{
      src_id: src_id,
      target_id: target_id,
      server_tick: Keyword.get(opts, :server_tick),
      src_speed: Keyword.get(opts, :src_speed, 1000),
      dmg_speed: Keyword.get(opts, :dmg_speed, 500),
      damage: damage,
      is_sp_damage: Keyword.get(opts, :is_sp_damage, 0),
      div: Keyword.get(opts, :div, 1),
      type: @attack_type_critical,
      damage2: Keyword.get(opts, :damage2, 0)
    }
  end

  @doc """
  Creates a ZC_NOTIFY_ACT packet for a missed attack.

  ## Parameters  
  - src_id: Attacker's ID
  - target_id: Target's ID
  - opts: Optional parameters (src_speed, dmg_speed)

  ## Returns
  ZcNotifyAct struct configured for miss/dodge

  ## Examples
      iex> packet = ZcNotifyAct.miss_attack(1001, 2001)
      iex> packet.type
      10
      iex> packet.damage
      0
  """
  @spec miss_attack(integer(), integer(), keyword()) :: t()
  def miss_attack(src_id, target_id, opts \\ [])
      when is_integer(src_id) and is_integer(target_id) do
    %__MODULE__{
      src_id: src_id,
      target_id: target_id,
      server_tick: Keyword.get(opts, :server_tick),
      src_speed: Keyword.get(opts, :src_speed, 1000),
      dmg_speed: Keyword.get(opts, :dmg_speed, 500),
      damage: 0,
      is_sp_damage: 0,
      div: 1,
      type: @attack_type_lucky_dodge,
      damage2: 0
    }
  end

  @doc """
  Creates a ZC_NOTIFY_ACT packet from combat result data.

  This is the main function used by the combat system to create
  appropriate attack packets based on combat calculations.

  ## Parameters
  - src_id: Attacker's ID
  - target_id: Target's ID  
  - combat_result: Map with damage, is_critical, and other combat data
  - opts: Optional parameters for packet customization

  ## Returns
  ZcNotifyAct struct configured based on combat result

  ## Examples
      iex> result = %{damage: 200, is_critical: true}
      iex> packet = ZcNotifyAct.from_combat_result(1001, 2001, result)
      iex> packet.type
      8
  """
  @spec from_combat_result(integer(), integer(), map(), keyword()) :: t()
  def from_combat_result(src_id, target_id, combat_result, opts \\ []) do
    damage = Map.get(combat_result, :damage, 0)
    is_critical = Map.get(combat_result, :is_critical, false)

    if is_critical do
      critical_attack(src_id, target_id, damage, opts)
    else
      normal_attack(src_id, target_id, damage, opts)
    end
  end

  @doc """
  Returns attack type constants for external use.
  """
  def attack_types do
    %{
      normal: @attack_type_normal,
      multi_hit: @attack_type_multi_hit,
      critical: @attack_type_critical,
      lucky_dodge: @attack_type_lucky_dodge
    }
  end
end
