defmodule Aesir.ZoneServer.Constants.ObjectType do
  @moduledoc """
  Constants for entity object types used in network packets.

  These values determine how the client renders and handles different entity types.
  Based on rAthena's objecttype definitions for ZC_NOTIFY packets.
  """

  @doc """
  Player/PC object type.
  Used for player characters in notification packets.
  """
  @spec pc() :: 0x0
  def pc, do: 0x0

  @doc """
  NPC object type.
  Used for non-player characters and interactive objects.
  """
  @spec npc() :: 0x1
  def npc, do: 0x1

  @doc """
  Mob/Monster object type.
  Used for monsters and hostile creatures.
  This is the critical value needed for proper mob visibility.
  """
  @spec mob() :: 0x5
  def mob, do: 0x5

  @doc """
  Pet object type.
  Used for player pets and companions.
  """
  @spec pet() :: 0x2
  def pet, do: 0x2

  @doc """
  Homunculus object type.
  Used for homunculus creatures.
  """
  @spec homunculus() :: 0x6
  def homunculus, do: 0x6

  @doc """
  Mercenary object type.
  Used for hired mercenary units.
  """
  @spec mercenary() :: 0x7
  def mercenary, do: 0x7

  @doc """
  Elemental object type.
  Used for elemental spirits.
  """
  @spec elemental() :: 0x8
  def elemental, do: 0x8

  @doc """
  Gets the object type for a given entity type atom.
  """
  @spec get_object_type(atom()) :: integer()
  def get_object_type(:player), do: pc()
  def get_object_type(:pc), do: pc()
  def get_object_type(:npc), do: npc()
  def get_object_type(:mob), do: mob()
  def get_object_type(:monster), do: mob()
  def get_object_type(:pet), do: pet()
  def get_object_type(:homunculus), do: homunculus()
  def get_object_type(:mercenary), do: mercenary()
  def get_object_type(:elemental), do: elemental()
  # Default to player for unknown types
  def get_object_type(_), do: pc()
end
