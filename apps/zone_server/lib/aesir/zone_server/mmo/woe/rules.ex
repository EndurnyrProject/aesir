defmodule Aesir.ZoneServer.Mmo.Woe.Rules do
  @moduledoc """
  Finite siege-ground rules shared by WoE consumers.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.MapFlags

  @shared_skill_bans [26, 27, 87, 150, 219]

  @doc "Returns whether a map uses siege-ground rules."
  @spec ground?(String.t()) :: boolean()
  def ground?(map_name) do
    MapFlags.get(map_name, :gvg) or MapFlags.get(map_name, :gvg_castle)
  end

  @doc "Returns whether siege is currently active on a map."
  @spec active?(String.t()) :: boolean()
  def active?(map_name), do: MapFlags.get(map_name, :gvg)

  @doc "Returns the siege-ground damage percentage for hit metadata."
  @spec damage_rate(map()) :: pos_integer()
  def damage_rate(%{skill_id: skill_id}) when is_integer(skill_id), do: 60
  def damage_rate(_hit_info), do: 80

  @doc "Returns whether a skill may be cast on the map under siege-ground rules."
  @spec skill_allowed?(pos_integer(), String.t()) :: boolean()
  def skill_allowed?(skill_id, map_name) do
    not ground?(map_name) or skill_id not in skill_bans(GameMode.mode())
  end

  @doc "Returns whether an item may be used on the map under siege-ground rules."
  @spec item_allowed?(pos_integer(), String.t()) :: boolean()
  def item_allowed?(item_id, map_name) do
    not ground?(map_name) or item_id not in item_bans(GameMode.mode())
  end

  @doc "Returns whether a status may be applied on the map under siege-ground rules."
  @spec status_allowed?(atom(), String.t()) :: boolean()
  def status_allowed?(status, map_name) do
    not ground?(map_name) or status != :sc_endure
  end

  defp skill_bans(:renewal), do: @shared_skill_bans
  defp skill_bans(:pre_renewal), do: [1013 | @shared_skill_bans]

  defp item_bans(:renewal), do: [605, 14_529]
  defp item_bans(:pre_renewal), do: [14_529]
end
