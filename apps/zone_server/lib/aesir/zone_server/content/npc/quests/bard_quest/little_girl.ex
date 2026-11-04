defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.LittleGirl do
  @moduledoc """
  Jorti talks about her family and Uncle Kino.

  ## Behavior

  - Her dialogue changes with the bard quest stage.

  ## Credits

  - Original from rAthena, authors Riotblade and L0ne_W0lf; contributors Lupus, SinSloth, and Euphy.

  ## Adaptation

  - Transpiled by `mix aesir.import.npcs` from rAthena script.
  - LLM-assisted Elixir refactor.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 132,
        y: 111,
        dir: 3,
        sprite: 703,
        name: "Little Girl",
        scope: :shared,
        unique_name: "Little Girl#Jorti"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :gef_bard_q, 0) > 9 and get_char_var(ctx, :gef_bard_q, 0) < 30 ->
        ctx
        |> mes("[Jorti]")
        |> mes(
          "Jorti tries not to cry anymore because it hurts Uncle Kino and then he coughs up more blood."
        )
        |> next()
        |> mes("[Jorti]")
        |> mes("I miss my mommy a lot, but I'm worried, it makes Uncle Kino worry a lot too.")
        |> next()
        |> mes("[Jorti]")
        |> mes(
          "I don't see my mommy and daddy aren't here anymore, and I don't want Uncle Jorti to go away either."
        )
        |> next()
        |> mes("[Jorti]")
        |> mes(
          "Um, I don't remember my daddy, but mommy lives far away, somewhere near the sky. That's what Uncle Kino says."
        )
        |> next()
        |> mes("[Jorti]")
        |> mes(
          "U-Uncle Kino says we can't go see her yet because there are no flying boats yet..."
        )
        |> close()

      get_char_var(ctx, :gef_bard_q, 0) == 30 ->
        ctx
        |> mes("[Jorti]")
        |> mes("La la la...")
        |> mes("La la la...")
        |> mes("Jorti doesn't cry anymore!")
        |> mes("Jorti is going to enjoy Uncle Kino's songs and stories for as long as she can!")
        |> next()
        |> mes("[Jorti]")
        |> mes(
          "The songs Uncle Kino sings are ones that my mommy used to sing. She's not here, but maybe we can visit her someday!"
        )
        |> next()
        |> mes("[Jorti]")
        |> mes(
          "Hey... The shiny black cross on your hand means you're a friend of Uncle Kino's. So that means, you're my friend too!"
        )
        |> close()

      get_char_var(ctx, :gef_bard_q, 0) > 30 ->
        ctx
        |> mes("[Jorti]")
        |> mes(
          "Jorti tries not to cry anymore because it hurts Uncle Kino and then he coughs up more blood."
        )
        |> mes(
          "I miss my mommy a lot, but when I'm worried, it makes Uncle Kino worry a lot too."
        )
        |> next()
        |> mes("[Jorti]")
        |> mes(
          "My mommy and daddy aren't here anymore, and I don't want Uncle Jorti to go away either."
        )
        |> next()
        |> mes("[Jorti]")
        |> mes(
          "Um, I don't remember my daddy, but mommy lives far away, somewhere near the sky. That's what Uncle Kino says."
        )
        |> next()
        |> mes("[Jorti]")
        |> mes(
          "U-Uncle Kino says we can't go see her yet because there are no flying boats yet..."
        )
        |> close()

      true ->
        ctx
        |> mes("[Mysterious Bard]")
        |> mes("Even in the sandy wind,")
        |> mes("Even in the pouring rain,")
        |> mes("Even in the falling snow,")
        |> mes("I know it's--")
        |> mes("........")
        |> next()
        |> mes("[Jorti]")
        |> mes("Uncle...?")
        |> mes("Are you okay?")
        |> next()
        |> mes("[Mysterious Bard]")
        |> mes("Hmmm...")
        |> mes(
          "I'm sorry, but this is a private performance. This song is only intended for my little Jorti."
        )
        |> close()
    end
  end
end
