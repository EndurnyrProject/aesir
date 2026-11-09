defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.WetFirewood do
  @moduledoc """
  Wet camp firewood left in the Morocc camp by another expedition member.

  ## Behavior

  - Past step 102 of the Morocc search reports the half-burnt logs left behind.
  - Otherwise complains that the firewood is too wet to burn.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 255,
        y: 269,
        dir: 0,
        sprite: 844,
        name: "Wet Firewood",
        scope: :shared,
        unique_name: "Wet Firewood#moc2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :mao_morocc2, 0) > 102 do
      burnt_logs(ctx)
    else
      wet_logs(ctx)
    end
  end

  defp burnt_logs(ctx) do
    ctx
    |> mes("You've found some half-burnt logs of high quality.")
    |> mes("It seems somebody already roasted sweet potatoes with these logs.")
    |> close()
  end

  defp wet_logs(ctx) do
    ctx
    |> mes("You've found camp firewood that is too wet to make a fire.")
    |> mes("It seems somebody has been futilely attempting to make a fire with them.")
    |> close()
  end
end
