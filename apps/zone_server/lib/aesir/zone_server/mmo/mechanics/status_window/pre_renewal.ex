defmodule Aesir.ZoneServer.Mmo.Mechanics.StatusWindow.PreRenewal do
  @moduledoc """
  Pre-renewal status window.

  ATK shows status ATK (with Hilt Binding and flat bonus ATK) plus both hands'
  weapon ATK on the left and the hands' refine ATK on the right. Status weapon ATK
  always joins the right hand, and the left hand only when its weapon has ATK; a
  level 4 weapon also takes the level 4 part. DEF and MDEF show the hard value
  first and the soft value second, soft MDEF without its VIT half and never below
  zero. MATK shows the band as `matk2` to `matk1`, with an armed Mystical
  Amplification taken back out.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics.StatusWindow

  @behaviour StatusWindow

  @impl true
  def values(components) do
    %{
      atk1:
        components.status_atk + components.hilt_binding_atk + components.bonus_atk +
          right_atk(components) + left_atk(components),
      atk2: components.right_refine_atk + components.left_refine_atk,
      def1: components.hard_def,
      def2: components.soft_def,
      mdef1: components.hard_mdef,
      mdef2: max(components.soft_mdef - div(max(components.vit, 0), 2), 0),
      matk1: unamplified(components.matk_max, components.matk_amp_rate),
      matk2: unamplified(components.matk_min, components.matk_amp_rate)
    }
  end

  defp right_atk(components) do
    StatusWindow.cap_weapon_atk(
      components.right_atk + status_watk(components, components.right_level)
    )
  end

  defp left_atk(%{left_atk: 0}), do: 0

  defp left_atk(components) do
    StatusWindow.cap_weapon_atk(
      components.left_atk + status_watk(components, components.left_level)
    )
  end

  defp status_watk(components, 4), do: components.status_watk + components.level4_watk
  defp status_watk(components, _level), do: components.status_watk

  defp unamplified(matk, rate) when rate > 0, do: div(matk * 100 + 50, rate + 100)
  defp unamplified(matk, _rate), do: matk
end
