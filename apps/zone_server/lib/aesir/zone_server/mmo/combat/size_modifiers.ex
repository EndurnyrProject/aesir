defmodule Aesir.ZoneServer.Mmo.Combat.SizeModifiers do
  @moduledoc """
  Public weapon-size damage modifier API.

  Every weapon type has a mode-specific percent modifier against `:small`, `:medium`, and
  `:large` targets; 100 is neutral. Mounted one- and two-handed spears use their large-target
  modifier against medium targets. Unknown weapon types remain neutral.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics

  @typedoc "Weapon type used by the combat pipeline."
  @type weapon_type :: atom()
  @typedoc "Target size used by weapon-size modifiers."
  @type size :: :small | :medium | :large

  @doc """
  Gets the damage modifier percent for a weapon type and target size.

  `riding?` defaults to `false`. The return value is an integer percentage where 100 is neutral.
  """
  @spec get_modifier(weapon_type(), size(), boolean()) :: integer()
  def get_modifier(weapon_type, target_size, riding? \\ false) do
    Mechanics.sizes().get_modifier(weapon_type, target_size, riding?)
  end
end
