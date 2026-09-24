defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.HermanthornJr do
  @moduledoc """
  Assigns the underground tunnel test to Rogue candidates sent by Mr. Smith.

  ## Behavior

  - Explains the tunnel test to candidates at the Hermanthorn step and advances their quest.
  - Reminds candidates already on the test of the door combination.
  - Shoos away everyone else.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 272,
        y: 135,
        dir: 1,
        sprite: 85,
        name: "Hermanthorn Jr",
        scope: :shared,
        unique_name: "Hermanthorn Jr#rg"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ROGUE_Q, 0) do
      8 -> assign_tunnel_test(ctx)
      12 -> remind_combination(ctx)
      _ -> shoo_away(ctx)
    end
  end

  defp assign_tunnel_test(ctx) do
    ctx
    |> mes("[HermanthornJr.]")
    |> mes("I see...")
    |> mes("You must be from")
    |> mes("the Rogue guild.")
    |> mes("You must be one of the")
    |> mes("ones Mr. Smith wasn't")
    |> mes("too happy with...")
    |> next()
    |> mes("[HermanthornJr.]")
    |> mes(
      "He threw a fit and you brought him all the items he asked for, didn't you? Well, I can see that you're still pretty naive. Hahaha~"
    )
    |> next()
    |> mes("[HermanthornJr.]")
    |> mes(
      "I suppose he suckered you into gathering those items, and then passed you on to me. Sad, really."
    )
    |> next()
    |> mes("[HermanthornJr.]")
    |> mes(
      "Well, since you were tortured by him, I'll try to be especially generous to you. My test for you will be simple, so simple."
    )
    |> next()
    |> mes("[HermanthornJr.]")
    |> mes(
      "All you have to do is go through an underground tunnel, and walk all the way back to the Rogue Guild."
    )
    |> next()
    |> mes("[HermanthornJr.]")
    |> mes(
      "There is one thing I should tell you, though. You might want to be careful inside, alright?"
    )
    |> next()
    |> mes("[HermanthornJr.]")
    |> mes(
      "A bunch of pricks have been throwing Dead Branches and casting Hocus Pocus all over the place..."
    )
    |> next()
    |> mes("[HermanthornJr.]")
    |> mes("Well...")
    |> mes("Just make it back to the Rogue Guild alive. That's all you have to do!")
    |> set_char_var(:ROGUE_Q, 12)
    |> changequest(2025, 2026)
    |> close()
  end

  defp remind_combination(ctx) do
    ctx
    |> mes("[HermanthornJr.]")
    |> mes(
      "Oh right. This is really important. You need a password to enter the tunnel. To unlock the door, the four number combination is ^0000FF3019^000000."
    )
    |> close()
  end

  defp shoo_away(ctx) do
    ctx
    |> mes("[HermanthornJr.]")
    |> mes("Huh...?")
    |> mes("What the hell")
    |> mes("are you doing here.")
    |> mes("Scram, why don't you?")
    |> close()
  end
end
