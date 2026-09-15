defmodule Aesir.ZoneServer.Content.Npc.Cities.Ayothaya.Aibakthing do
  @moduledoc """
  Offers visitors passage from Ayothaya back to Alberta.

  ## Behavior

  - Lets the player return to Alberta or remain in Ayothaya.
  - Uses mode-specific arrival coordinates in Alberta.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayothaya",
        x: 152,
        y: 68,
        dir: 1,
        sprite: 843,
        name: "Aibakthing",
        scope: :shared,
        unique_name: "Aibakthing#ayo2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aibakthing]")
      |> mes("Hoo! Hah! Hmm! Hah!")
      |> mes(
        "So, how did you like Ayothaya? Did you get a chance to try Tom Yum Goong? When you're ready, I shall take you back home."
      )
      |> next()
      |> select(["Go back to Alberta.", "Cancel."])

    if choice == 1 do
      return_to_alberta(ctx)
    else
      ctx
      |> mes("[Aibakthing]")
      |> mes(
        "Ah yes. I understand that it is difficult to take leave of such a beautiful place. Do not worry"
      )
      |> mes("and take your time.")
      |> close()
    end
  end

  defp return_to_alberta(ctx) do
    ctx =
      ctx
      |> mes("[Aibakthing]")
      |> mes(
        "You will be welcome to come back whenever you please. I hope that we will see each other again sometime soon. Thank you~"
      )
      |> close()

    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "alberta", 245, 87)
    else
      warp(ctx, "alberta", 235, 45)
    end
  end
end
