defmodule Aesir.ZoneServer.Mmo.Skills.Clown.Formulas do
  @moduledoc "Pure Clown and Gypsy formulas for renewal and pre-renewal."

  alias Aesir.Commons.GameMode

  @doc "Arrow Vulcan's weapon ratio: base-level-scaled in renewal, flat in pre-renewal."
  @spec arrow_vulcan_ratio(pos_integer(), pos_integer()) :: pos_integer()
  def arrow_vulcan_ratio(level, base_level) do
    case GameMode.mode() do
      :renewal -> div((500 + 100 * level) * base_level, 100)
      :pre_renewal -> 200 + 100 * level
    end
  end
end
