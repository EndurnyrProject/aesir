defmodule Aesir.ZoneServer.Content.Npc.Functions.FItemname do
  @moduledoc """
  Returns an item name decorated with its refine, VVS level and element.

  ## Behavior

  The decorations follow the reference order: the refine rate first, then the VVS level, then the
  element, then the item name, all wrapped in the `^000090` colour. Unknown non-zero refinements
  and elements degrade to `<n>xVS` and `Strange`.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @elements %{1 => "Ice ", 2 => "Earth ", 3 => "Fire ", 4 => "Wind "}
  @vvs_levels %{1 => "VS ", 2 => "VVS ", 3 => "VVVS "}

  @doc """
  Callable rAthena global function `F_ItemName(item, element, vvs_level, refine)`; returns the
  decorated name.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args) do
    item = Enum.at(args, 0, 0)

    decoration =
      refine_prefix(Enum.at(args, 3, 0)) <>
        vvs_prefix(Enum.at(args, 2, 0)) <> element_prefix(Enum.at(args, 1, 0))

    {ctx, "^000090" <> decoration <> Rathena.getitemname(item) <> "^000000"}
  end

  defp refine_prefix(rate) do
    if Rathena.truthy?(rate), do: "+" <> to_string(rate) <> " ", else: ""
  end

  defp vvs_prefix(level) when is_map_key(@vvs_levels, level), do: Map.fetch!(@vvs_levels, level)
  defp vvs_prefix(0), do: ""
  defp vvs_prefix(level), do: to_string(level) <> "xVS "

  defp element_prefix(element) when is_map_key(@elements, element),
    do: Map.fetch!(@elements, element)

  defp element_prefix(0), do: ""
  defp element_prefix(_unknown), do: "Strange "
end
