defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.RegenschirmGuard do
  @moduledoc """
  Controls entry to the Regenschirm underground laboratory.

  ## Behavior

  - Offers entry only when the required quest bit and Laboratory Permit are present.
  - Warps accepted visitors into the underground laboratory.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 24,
        y: 140,
        dir: 3,
        sprite: 868,
        name: "Regenschirm Guard",
        scope: :shared,
        unique_name: "Regenschirm Guard#40"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Regenschirm Guard]")

    if Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 512)) and
         count_item(ctx, 2657) > 0 do
      offer_entry(ctx)
    else
      ctx
      |> mes("May I help you?")
      |> mes("If you would like to")
      |> mes("enter, you must first")
      |> mes("have a Laboratory Permit.")
      |> mes("Thank you for your cooperation.")
      |> close()
    end
  end

  defp offer_entry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Do you wish to")
      |> mes("go underground?")
      |> next()
      |> select(["Yes", "No"])

    ctx =
      ctx
      |> mes("[Regenschirm Guard]")
      |> mes("Thank you and")
      |> mes("have a nice day.")
      |> close()

    if choice == 1 do
      warp(ctx, "lhz_dun01", 149, 285)
    else
      ctx
    end
  end
end
