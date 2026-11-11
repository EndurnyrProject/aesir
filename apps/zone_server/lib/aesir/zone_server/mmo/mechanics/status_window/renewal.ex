defmodule Aesir.ZoneServer.Mmo.Mechanics.StatusWindow.Renewal do
  @moduledoc """
  Renewal status window: every pair reads `status + equipment`.

  ATK is status ATK, then both hands' weapon ATK with refine plus flat equipment
  ATK. Status weapon ATK joins the right hand when it holds a weapon and the left
  hand otherwise. DEF and MDEF show the soft value first and the hard value
  second. MATK shows the status MATK formula as `matk2` and weapon plus flat
  equipment, consumable and skill MATK as `matk1`.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics.StatusWindow

  @behaviour StatusWindow

  @impl true
  def values(components) do
    %{
      atk1: components.status_atk,
      atk2: weapon_atk(components) + components.bonus_atk,
      def1: components.soft_def,
      def2: components.hard_def,
      mdef1: components.soft_mdef,
      mdef2: components.hard_mdef,
      matk1: components.weapon_matk + components.flat_matk,
      matk2: components.status_matk
    }
  end

  defp weapon_atk(components) do
    right = components.right_atk + components.right_refine_atk
    left = components.left_atk + components.left_refine_atk

    if right > 0,
      do: StatusWindow.cap_weapon_atk(right + components.status_watk) + left,
      else: StatusWindow.cap_weapon_atk(left + components.status_watk)
  end
end
